"""Anti-pattern rules for Recastory audit.

Rule groups:
- TR-001~005: Transcription rules
- CD-001~003, CD-005~006: Content distillation rules
- VO-001~004: Voice rules
- SL-001~006: AI Slop rules
- VV-001~005: Visual Verification rules (via mmx vision, in vision_rules.py)
- DS-001~006: Distill-Style oral rules
- CH-001~006: Chapter Visual rules
- SB-001~005: Storyboard Design rules
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Callable


# ---------------------------------------------------------------------------
# Rule registry with @rule decorator
# ---------------------------------------------------------------------------

_RULE_REGISTRY: dict[str, dict] = {}


def rule(rule_id: str, *, severity: str = "warning", file_types: list[str] | None = None):
    """Decorator to auto-register a rule class.

    Usage:
        @rule("DS-001", severity="warning", file_types=["script.md", "article.md"])
        class DS001Rule:
            ...
    """
    def decorator(cls):
        _RULE_REGISTRY[rule_id] = {
            "class": cls,
            "severity": severity,
            "file_types": file_types or [],
        }
        return cls
    return decorator


@dataclass
class RuleResult:
    rule_id: str
    name: str
    severity: str  # "critical" or "warning"
    file_path: str
    message: str
    line_number: int | None = None


@dataclass
class Rule:
    id: str
    name: str
    severity: str
    detect: Callable[[str, str], list[RuleResult]]
    description: str


# ---------------------------------------------------------------------------
# TR series — Transcription rules
# ---------------------------------------------------------------------------


def detect_tr001(content: str, file_path: str) -> list[RuleResult]:
    """TR-001: 3+ consecutive long sentences (>50 chars) without punctuation."""
    lines = [l.strip() for l in content.splitlines() if l.strip()]
    sent_end = re.compile(r'[。！？.!?；;]')
    results: list[RuleResult] = []
    streak = 0
    streak_start = 0
    for i, line in enumerate(lines, 1):
        if line.startswith('#') or line == '---':
            if streak >= 3:
                results.append(RuleResult(
                    rule_id='TR-001', name='连续无标点长句', severity='warning',
                    file_path=file_path,
                    message=f'连续 {streak} 个无标点长句（>{50}字），第 {streak_start}~{streak_start + streak - 1} 行',
                    line_number=streak_start,
                ))
            streak = 0
            continue
        clean = sent_end.sub('', line)
        if len(clean) > 50 and not sent_end.search(line):
            if streak == 0:
                streak_start = i
            streak += 1
        else:
            if streak >= 3:
                results.append(RuleResult(
                    rule_id='TR-001', name='连续无标点长句', severity='warning',
                    file_path=file_path,
                    message=f'连续 {streak} 个无标点长句（>{50}字），第 {streak_start}~{streak_start + streak - 1} 行',
                    line_number=streak_start,
                ))
            streak = 0
    if streak >= 3:
        results.append(RuleResult(
            rule_id='TR-001', name='连续无标点长句', severity='warning',
            file_path=file_path,
            message=f'连续 {streak} 个无标点长句（>{50}字），第 {streak_start}~{streak_start + streak - 1} 行',
            line_number=streak_start,
        ))
    return results


def detect_tr002(content: str, file_path: str) -> list[RuleResult]:
    """TR-002: Speaker label format inconsistency."""
    results: list[RuleResult] = []
    bracket_pattern = re.compile(r'^\[([^\]]+)\]')
    non_standard = re.compile(r'^[一-鿿\w]+[：:]')
    has_bracket = False
    has_non_standard = False
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue
        if bracket_pattern.match(stripped):
            has_bracket = True
        elif non_standard.match(stripped):
            has_non_standard = True
            results.append(RuleResult(
                rule_id='TR-002', name='说话人标签格式不统一', severity='warning',
                file_path=file_path,
                message='说话人标签应使用 [说话人] 格式，当前行使用了非标准格式',
                line_number=i,
            ))
    if has_bracket and has_non_standard:
        pass
    elif has_non_standard and not has_bracket:
        pass
    return results


def detect_tr003(content: str, file_path: str) -> list[RuleResult]:
    """TR-003: SRT timestamp discontinuity or overlap."""
    results: list[RuleResult] = []
    ts_pattern = re.compile(
        r'(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})'
    )
    timestamps: list[tuple[float, float, int]] = []
    for i, line in enumerate(content.splitlines(), 1):
        m = ts_pattern.search(line)
        if m:
            g = m.groups()
            start = int(g[0]) * 3600 + int(g[1]) * 60 + int(g[2]) + int(g[3]) / 1000
            end = int(g[4]) * 3600 + int(g[5]) * 60 + int(g[6]) + int(g[7]) / 1000
            timestamps.append((start, end, i))
    for idx in range(1, len(timestamps)):
        prev_end = timestamps[idx - 1][1]
        curr_start = timestamps[idx][0]
        curr_line = timestamps[idx][2]
        if curr_start < prev_end - 0.001:
            results.append(RuleResult(
                rule_id='TR-003', name='时间戳重叠', severity='critical',
                file_path=file_path,
                message=f'时间戳重叠：前段结束 {prev_end:.3f}s > 当前段开始 {curr_start:.3f}s',
                line_number=curr_line,
            ))
        elif curr_start > prev_end + 1.0:
            results.append(RuleResult(
                rule_id='TR-003', name='时间戳不连续', severity='warning',
                file_path=file_path,
                message=f'时间戳不连续：间隔 {curr_start - prev_end:.1f}s（>1s）',
                line_number=curr_line,
            ))
    return results


def detect_tr004(content: str, file_path: str) -> list[RuleResult]:
    """TR-004: Filler word density > 5%."""
    results: list[RuleResult] = []
    fillers = ['嗯', '啊', '呃', '那个', '这个', '就是说', '然后']
    chinese_chars = re.findall(r'[一-鿿]', content)
    total = len(chinese_chars)
    if total == 0:
        return results
    filler_count = sum(content.count(f) for f in fillers)
    density = filler_count / total
    if density > 0.05:
        results.append(RuleResult(
            rule_id='TR-004', name='填充词密度过高', severity='warning',
            file_path=file_path,
            message=f'填充词密度 {density:.1%}（>{5}%），共 {filler_count} 个填充词 / {total} 字',
        ))
    return results


def detect_tr005(content: str, file_path: str) -> list[RuleResult]:
    """TR-005: Mixed Chinese/English punctuation."""
    results: list[RuleResult] = []
    cn_punct = set('，。！？；：（）【】《》、""''')
    en_punct = set(',.!?;:()[]<>"\'')
    has_cn = False
    has_en = False
    for line in content.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue
        for ch in stripped:
            if ch in cn_punct:
                has_cn = True
            elif ch in en_punct:
                has_en = True
    if has_cn and has_en:
        results.append(RuleResult(
            rule_id='TR-005', name='中英文标点混用', severity='warning',
            file_path=file_path,
            message='文件中同时存在中文标点和英文标点，建议统一',
        ))
    return results


# ---------------------------------------------------------------------------
# CD series — Content Distillation rules
# ---------------------------------------------------------------------------


def detect_cd001(content: str, file_path: str) -> list[RuleResult]:
    """CD-001: Outline heading level deeper than 4 (####)."""
    results: list[RuleResult] = []
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        m = re.match(r'^(#{5,})\s', stripped)
        if m:
            level = len(m.group(1))
            results.append(RuleResult(
                rule_id='CD-001', name='大纲层级过深', severity='warning',
                file_path=file_path,
                message=f'大纲层级 {level} 层（>4），建议扁平化或拆分',
                line_number=i,
            ))
    return results


def detect_cd002(content: str, file_path: str) -> list[RuleResult]:
    """CD-002: Single section > 500 chars (split by ## headings)."""
    results: list[RuleResult] = []
    sections: list[tuple[str, int, str]] = []
    current_heading = ''
    current_start = 1
    current_body_lines: list[str] = []
    for i, line in enumerate(content.splitlines(), 1):
        if line.strip().startswith('## ') and not line.strip().startswith('### '):
            if current_body_lines:
                sections.append((current_heading, current_start, '\n'.join(current_body_lines)))
            current_heading = line.strip()
            current_start = i
            current_body_lines = []
        elif not line.strip().startswith('#'):
            current_body_lines.append(line)
    if current_body_lines:
        sections.append((current_heading, current_start, '\n'.join(current_body_lines)))
    for heading, line_no, body in sections:
        char_count = len(re.findall(r'[一-鿿\w]', body))
        if char_count > 500:
            results.append(RuleResult(
                rule_id='CD-002', name='单章节字数过多', severity='warning',
                file_path=file_path,
                message=f'章节 "{heading}" 共 {char_count} 字（>500），建议拆分',
                line_number=line_no,
            ))
    return results


def detect_cd003(content: str, file_path: str) -> list[RuleResult]:
    """CD-003: Script contains formal/written language patterns."""
    results: list[RuleResult] = []
    formal_patterns = [
        '综上所述', '由此可见', '总而言之', '不难发现',
        '值得注意的是', '毋庸置疑', '显而易见', '不言而喻',
        '从本质上来说', '归根结底', '简而言之', '概而论之',
    ]
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue
        for pat in formal_patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='CD-003', name='口播脚本包含书面语', severity='warning',
                    file_path=file_path,
                    message=f'检测到书面语 "{pat}"，建议替换为口语化表达',
                    line_number=i,
                ))
    return results


def detect_cd005(content: str, file_path: str) -> list[RuleResult]:
    """CD-005: Lack of Hook — first 50 chars have no engaging statement."""
    results: list[RuleResult] = []
    collected = ''
    for line in content.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue
        collected += stripped
        if len(collected) >= 50:
            break
    if not collected:
        return results
    hook_patterns = [r'[？?]', r'[！!]', r'你', r'吗', r'为什么', r'怎么']
    has_hook = any(re.search(p, collected) for p in hook_patterns)
    if not has_hook:
        results.append(RuleResult(
            rule_id='CD-005', name='缺乏 Hook', severity='warning',
            file_path=file_path,
            message='前 50 字无吸引力语句（无提问/感叹/直接称呼），建议添加开场钩子',
        ))
    return results


def detect_cd006(content: str, file_path: str) -> list[RuleResult]:
    """CD-006: Expression DNA not injected — no perspective markers."""
    results: list[RuleResult] = []
    perspective_markers = [
        '视角', 'perspective', 'Expression DNA',
        '费曼', 'feynman', 'MrBeast', '马斯克', 'musk',
        '芒格', 'munger', 'Naval', '乔布斯', 'jobs',
    ]
    content_lower = content.lower()
    has_marker = any(m.lower() in content_lower for m in perspective_markers)
    if not has_marker:
        results.append(RuleResult(
            rule_id='CD-006', name='表达 DNA 未注入', severity='warning',
            file_path=file_path,
            message='未检测到视角标记，建议加载对应视角的 Expression DNA',
        ))
    return results


# ---------------------------------------------------------------------------
# VO series — Voice rules
# ---------------------------------------------------------------------------


def detect_vo001(content: str, file_path: str) -> list[RuleResult]:
    """VO-001: Speech rate abnormal — based on char count and estimated duration."""
    results: list[RuleResult] = []
    try:
        import json
        data = json.loads(content)
        if isinstance(data, dict) and 'segments' in data:
            for seg in data['segments']:
                text = seg.get('text', '')
                start = seg.get('start', 0)
                end = seg.get('end', 0)
                duration = end - start
                if duration <= 0:
                    continue
                char_count = len(re.findall(r'[一-鿿\w]', text))
                rate = char_count / duration * 60
                if rate > 180 or rate < 120:
                    results.append(RuleResult(
                        rule_id='VO-001', name='语速异常', severity='warning',
                        file_path=file_path,
                        message=f'语速 {rate:.0f} 字/分钟（正常 120~180），文本: {text[:20]}...',
                    ))
            return results
    except (json.JSONDecodeError, KeyError, TypeError):
        pass
    return results


def detect_vo002(content: str, file_path: str) -> list[RuleResult]:
    """VO-002: Single sentence > 50 chars (TTS may break)."""
    results: list[RuleResult] = []
    sentences = re.split(r'[。！？.!?；;\n]', content)
    for i, sent in enumerate(sentences):
        clean = sent.strip()
        char_count = len(re.findall(r'[一-鿿\w]', clean))
        if char_count > 50:
            line_no = None
            for ln, line in enumerate(content.splitlines(), 1):
                if clean[:20] in line:
                    line_no = ln
                    break
            results.append(RuleResult(
                rule_id='VO-002', name='单句长度过长', severity='warning',
                file_path=file_path,
                message=f'单句 {char_count} 字（>50），TTS 可能破音，建议拆分: "{clean[:30]}..."',
                line_number=line_no,
            ))
    return results


def detect_vo003(content: str, file_path: str) -> list[RuleResult]:
    """VO-003: Polyphone without pinyin annotation."""
    results: list[RuleResult] = []
    polyphones = {
        '行': ['行业', '银行', '行列', '行情'],
        '长': ['成长', '生长'],
        '重': ['重要', '重量', '重复', '重叠'],
        '了': ['了解', '了结'],
        '还': ['还是', '还有', '还要'],
        '得': ['得到', '得失', '觉得', '记得'],
        '地': ['地方', '地球', '地区'],
        '和': ['和平', '和谐'],
    }
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue
        if re.search(r'[一-鿿]\([a-z]+\)', stripped):
            continue
        for char, contexts in polyphones.items():
            for ctx in contexts:
                if ctx in stripped and f'{char}(' not in stripped:
                    results.append(RuleResult(
                        rule_id='VO-003', name='多音字未标注', severity='warning',
                        file_path=file_path,
                        message=f'多音字 "{char}"（在"{ctx}"中）缺少拼音标注',
                        line_number=i,
                    ))
                    break
    return results


def detect_vo004(content: str, file_path: str) -> list[RuleResult]:
    """VO-004: Lack of pause markers — 5+ consecutive sentences without comma/period."""
    results: list[RuleResult] = []
    pause_marks = re.compile(r'[，。！？,\.!?；;、]')
    lines = [l.strip() for l in content.splitlines()
             if l.strip() and not l.startswith('#') and l.strip() != '---']
    streak = 0
    streak_start_line = 0
    for idx, line in enumerate(lines):
        if not pause_marks.search(line):
            if streak == 0:
                for ln, orig_line in enumerate(content.splitlines(), 1):
                    if line in orig_line:
                        streak_start_line = ln
                        break
            streak += 1
        else:
            if streak >= 5:
                results.append(RuleResult(
                    rule_id='VO-004', name='缺乏停顿标记', severity='warning',
                    file_path=file_path,
                    message=f'连续 {streak} 句无停顿标记（逗号/句号），建议插入呼吸停顿',
                    line_number=streak_start_line,
                ))
            streak = 0
    if streak >= 5:
        results.append(RuleResult(
            rule_id='VO-004', name='缺乏停顿标记', severity='warning',
            file_path=file_path,
            message=f'连续 {streak} 句无停顿标记（逗号/句号），建议插入呼吸停顿',
            line_number=streak_start_line,
        ))
    return results


# ---------------------------------------------------------------------------
# SL series — AI Slop rules
# ---------------------------------------------------------------------------


def detect_sl001(content: str, file_path: str) -> list[RuleResult]:
    """SL-001: Fake empathy."""
    results: list[RuleResult] = []
    patterns = ['我知道你', '你是不是也', '我能理解', '我理解你的', '你一定觉得']
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        for pat in patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-001', name='假共情', severity='critical',
                    file_path=file_path,
                    message=f'检测到假共情 "{pat}"，建议直接抛事实/钩子',
                    line_number=i,
                ))
    return results


def detect_sl002(content: str, file_path: str) -> list[RuleResult]:
    """SL-002: Fake depth — "恰恰/反而/正是" wrapping."""
    results: list[RuleResult] = []
    strong_patterns = ['恰恰是', '恰恰相反', '恰恰说明']
    weak_patterns = ['反而', '正是']
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue
        for pat in strong_patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-002', name='假深刻', severity='critical',
                    file_path=file_path,
                    message=f'检测到假深刻 "{pat}"，建议去掉转折直接说结论',
                    line_number=i,
                ))
        if len(stripped) > 15:
            for pat in weak_patterns:
                if pat in stripped:
                    results.append(RuleResult(
                        rule_id='SL-002', name='假深刻', severity='critical',
                        file_path=file_path,
                        message=f'检测到假深刻 "{pat}"，建议去掉转折直接说结论',
                        line_number=i,
                    ))
    return results


def detect_sl003(content: str, file_path: str) -> list[RuleResult]:
    """SL-003: Self-promotion."""
    results: list[RuleResult] = []
    patterns = ['我必须认真说', '颠覆认知', '你一定要听完', '认真听我说', '一定要看到最后', '这个视频会改变你']
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        for pat in patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-003', name='自我标榜', severity='critical',
                    file_path=file_path,
                    message=f'检测到自我标榜 "{pat}"，建议直接说内容',
                    line_number=i,
                ))
    return results


def detect_sl004(content: str, file_path: str) -> list[RuleResult]:
    """SL-004: Universal template."""
    results: list[RuleResult] = []
    patterns = ['说白了', '本质上', '底层逻辑', '一句话总结', '归根结底', '说到底']
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        for pat in patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-004', name='万能模板', severity='critical',
                    file_path=file_path,
                    message=f'检测到万能模板 "{pat}"，建议删掉或直接说内容',
                    line_number=i,
                ))
    return results


def detect_sl005(content: str, file_path: str) -> list[RuleResult]:
    """SL-005: Parallel structure piling — 3+ consecutive sentences with same structure."""
    results: list[RuleResult] = []
    lines = [l.strip() for l in content.splitlines()
             if l.strip() and not l.startswith('#') and l.strip() != '---']
    if len(lines) < 3:
        return results
    streak = 1
    streak_start = 0
    for i in range(1, len(lines)):
        prev_prefix = lines[i - 1][:2] if len(lines[i - 1]) >= 2 else lines[i - 1]
        curr_prefix = lines[i][:2] if len(lines[i]) >= 2 else lines[i]
        if prev_prefix == curr_prefix and len(prev_prefix) >= 2:
            if streak == 1:
                streak_start = i - 1
            streak += 1
        else:
            if streak >= 3:
                line_no = None
                for ln, orig in enumerate(content.splitlines(), 1):
                    if lines[streak_start] in orig:
                        line_no = ln
                        break
                results.append(RuleResult(
                    rule_id='SL-005', name='排比堆砌', severity='critical',
                    file_path=file_path,
                    message=f'连续 {streak} 句结构相同，建议保留 1~2 个，其余砍掉',
                    line_number=line_no,
                ))
            streak = 1
    if streak >= 3:
        line_no = None
        for ln, orig in enumerate(content.splitlines(), 1):
            if lines[streak_start] in orig:
                line_no = ln
                break
        results.append(RuleResult(
            rule_id='SL-005', name='排比堆砌', severity='critical',
            file_path=file_path,
            message=f'连续 {streak} 句结构相同，建议保留 1~2 个，其余砍掉',
            line_number=line_no,
        ))
    return results


def detect_sl006(content: str, file_path: str) -> list[RuleResult]:
    """SL-006: Template ending."""
    results: list[RuleResult] = []
    patterns = ['以上就是本期内容', '希望对你有帮助', '感谢观看', '感谢收看', '我们下期再见', '下期见']
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        for pat in patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-006', name='套话结尾', severity='critical',
                    file_path=file_path,
                    message=f'检测到套话结尾 "{pat}"，建议用视角的 Decision Heuristics 设计结尾',
                    line_number=i,
                ))
    return results


# ---------------------------------------------------------------------------
# DS series — Distill-Style oral rules (auto-registered via @rule)
# ---------------------------------------------------------------------------


@rule("DS-001", severity="warning", file_types=["script.md", "article.md"])
class DS001:
    """信息保留度 <60%：script.md 字数 / article.md 字数。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        script_chars = len(re.findall(r'[一-鿿\w]', content))
        # 尝试在同一目录下找 article.md
        import os
        article_path = os.path.join(os.path.dirname(file_path), 'article.md')
        if not os.path.exists(article_path):
            return results
        with open(article_path, 'r', encoding='utf-8') as f:
            article_chars = len(re.findall(r'[一-鿿\w]', f.read()))
        if article_chars == 0:
            return results
        ratio = script_chars / article_chars
        if ratio < 0.6:
            results.append(RuleResult(
                rule_id='DS-001', name='信息保留度过低', severity='warning',
                file_path=file_path,
                message=f'信息保留度 {ratio:.0%}（<60%），script {script_chars} 字 vs article {article_chars} 字',
            ))
        return results


@rule("DS-002", severity="warning", file_types=["script.md"])
class DS002:
    """单句 >20 字：按句号/问号/叹号分割，检查字数。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        sentences = re.split(r'[。！？.!?]', content)
        for sent in sentences:
            chars = re.findall(r'[一-鿿]', sent)
            if len(chars) > 20:
                # Find line number
                line_no = None
                for ln, line in enumerate(content.splitlines(), 1):
                    if sent.strip()[:15] and sent.strip()[:15] in line:
                        line_no = ln
                        break
                results.append(RuleResult(
                    rule_id='DS-002', name='单句过长', severity='warning',
                    file_path=file_path,
                    message=f'单句 {len(chars)} 字（>20），建议拆分: "{sent.strip()[:30]}..."',
                    line_number=line_no,
                ))
        return results


@rule("DS-003", severity="warning", file_types=["script.md"])
class DS003:
    """第三人称疏离：检测"用户""读者""大家"等第三人称表述。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        patterns = ['用户', '读者', '大家', '观众', '各位', '人们']
        for i, line in enumerate(content.splitlines(), 1):
            stripped = line.strip()
            for pat in patterns:
                if pat in stripped:
                    results.append(RuleResult(
                        rule_id='DS-003', name='第三人称疏离', severity='warning',
                        file_path=file_path,
                        message=f'检测到第三人称 "{pat}"，建议改为第二人称"你"',
                        line_number=i,
                    ))
        return results


@rule("DS-004", severity="warning", file_types=["script.md"])
class DS004:
    """无钩子开头：前 100 字是否含问号/反差词。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        collected = ''
        for line in content.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue
            collected += stripped
            if len(collected) >= 100:
                break
        if not collected:
            return results
        hook_patterns = [
            r'[？?]', r'[！!]', r'你',
            r'但是', r'然而', r'其实', r'竟然',
        ]
        has_hook = any(re.search(p, collected) for p in hook_patterns)
        if not has_hook:
            results.append(RuleResult(
                rule_id='DS-004', name='无钩子开头', severity='warning',
                file_path=file_path,
                message='前 100 字无问号或反差词，建议添加开场钩子',
            ))
        return results


@rule("DS-005", severity="warning", file_types=["script.md"])
class DS005:
    """结构词堆砌：检测"首先.*其次.*最后"模式。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        structure_words = ['首先', '其次', '最后', '第一', '第二', '第三']
        found = []
        for word in structure_words:
            for i, line in enumerate(content.splitlines(), 1):
                if word in line:
                    found.append((word, i))
                    break
        if len(found) >= 3:
            results.append(RuleResult(
                rule_id='DS-005', name='结构词堆砌', severity='warning',
                file_path=file_path,
                message=f'检测到 {len(found)} 个结构词（{"、".join(w for w, _ in found)}），建议自然过渡',
            ))
        return results


@rule("DS-006", severity="warning", file_types=["script.md"])
class DS006:
    """数字未翻译：纯百分比/大数字无中文上下文。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        context_words = ['用户', '增长', '下降', '提升', '节省', '超过', '达到', '占比', '市场']
        patterns = [
            (r'\d+%', '百分比'),
            (r'\d{4,}', '大数字'),
            (r'[\$¥€£]\d+', '货币'),
        ]
        for i, line in enumerate(content.splitlines(), 1):
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue
            for pat, name in patterns:
                matches = re.findall(pat, stripped)
                for m in matches:
                    has_context = any(w in stripped for w in context_words)
                    if not has_context:
                        results.append(RuleResult(
                            rule_id='DS-006', name='数字未翻译', severity='warning',
                            file_path=file_path,
                            message=f'数字 "{m}" 缺少中文上下文说明',
                            line_number=i,
                        ))
        return results


# ---------------------------------------------------------------------------
# CH series — Chapter Visual rules (auto-registered via @rule)
# ---------------------------------------------------------------------------


@rule("CH-001", severity="warning", file_types=["*.tsx", "*.jsx"])
class CH001:
    """纯文字无视觉：Chapter.tsx 无 img/SVG/animation。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        visual_markers = ['<img', '<svg', '<SVG', 'animation', 'animate', 'motion.', 'kenBurns', 'ken-burns']
        has_visual = any(m in content for m in visual_markers)
        if not has_visual:
            results.append(RuleResult(
                rule_id='CH-001', name='纯文字无视觉', severity='warning',
                file_path=file_path,
                message='Chapter.tsx 无 img/SVG/animation 元素',
            ))
        return results


@rule("CH-002", severity="warning", file_types=["*.tsx", "*.jsx"])
class CH002:
    """列表一次揭示：多项同 step。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        step_pattern = re.compile(r'step[=:]\s*(\d+)', re.IGNORECASE)
        steps: dict[int, int] = {}
        for m in step_pattern.finditer(content):
            step_num = int(m.group(1))
            steps[step_num] = steps.get(step_num, 0) + 1
        for step_num, count in steps.items():
            if count > 3:
                results.append(RuleResult(
                    rule_id='CH-002', name='列表一次揭示', severity='warning',
                    file_path=file_path,
                    message=f'step {step_num} 有 {count} 个元素同屏揭示，建议分步展示',
                ))
        return results


@rule("CH-003", severity="critical", file_types=["*.tsx", "*.jsx", "*.css"])
class CH003:
    """AI 视觉指纹：紫粉渐变/圆角彩色边框/emoji 图标。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        ai_fingerprints = [
            (r'linear-gradient.*purple.*pink|linear-gradient.*#.*[pP]urple.*#.*[pP]ink', '紫粉渐变'),
            (r'border-left.*(?:#(?:6B5CE7|A855F7|EC4899|FF6B9D))', '彩色左边框'),
            (r'border-radius.*(?:24px|16px).*border.*(?:#(?:6B5CE7|A855F7))', '圆角彩色卡片'),
            (r'[\U0001F300-\U0001F9FF].*(?:icon|Icon)', 'emoji 作图标'),
        ]
        for pat, name in ai_fingerprints:
            if re.search(pat, content, re.IGNORECASE):
                results.append(RuleResult(
                    rule_id='CH-003', name='AI 视觉指纹', severity='critical',
                    file_path=file_path,
                    message=f'检测到 AI 视觉指纹: {name}',
                ))
        return results


@rule("CH-004", severity="critical", file_types=["*.tsx", "*.jsx", "*.ts"])
class CH004:
    """假数据：X0K users/假 logo/占位符。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        fake_patterns = [
            (r'\d+K\s+users', '虚假用户数'),
            (r'lorem\s+ipsum', '占位文本'),
            (r'example\.com', '示例域名'),
            (r'Acme\s+(?:Corp|Inc|Ltd)', '占位公司名'),
            (r'placeholder', '占位符'),
        ]
        for pat, name in fake_patterns:
            if re.search(pat, content, re.IGNORECASE):
                line_no = None
                for ln, line in enumerate(content.splitlines(), 1):
                    if re.search(pat, line, re.IGNORECASE):
                        line_no = ln
                        break
                results.append(RuleResult(
                    rule_id='CH-004', name='假数据', severity='critical',
                    file_path=file_path,
                    message=f'检测到 {name}，建议替换为真实数据',
                    line_number=line_no,
                ))
        return results


@rule("CH-005", severity="warning", file_types=["*.tsx", "*.jsx", "*.css"])
class CH005:
    """全场同动画：单一 animation 名称重复。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        anim_pattern = re.compile(r'animation(?:-name)?:\s*(\w[\w-]*)', re.IGNORECASE)
        animations = anim_pattern.findall(content)
        if len(animations) >= 3:
            unique = set(animations)
            if len(unique) == 1:
                results.append(RuleResult(
                    rule_id='CH-005', name='全场同动画', severity='warning',
                    file_path=file_path,
                    message=f'所有元素使用同一动画 "{animations[0]}"，建议多样化',
                ))
        return results


@rule("CH-006", severity="warning", file_types=["*.tsx", "*.jsx", "*.css"])
class CH006:
    """动画过多：每步都有 ken burns/光晕。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        heavy_anims = ['kenBurns', 'ken-burns', 'glow', 'pulse', 'shimmer']
        count = sum(1 for a in heavy_anims if a.lower() in content.lower())
        if count >= 3:
            results.append(RuleResult(
                rule_id='CH-006', name='动画过多', severity='warning',
                file_path=file_path,
                message=f'检测到 {count} 种重动画效果，建议精简',
            ))
        return results


# ---------------------------------------------------------------------------
# SB series — Storyboard Design rules (auto-registered via @rule)
# ---------------------------------------------------------------------------


@rule("SB-001", severity="warning", file_types=["narrations.ts", "narrations.json"])
class SB001:
    """单页 >80 字：检查 narrations.ts 每项字数。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        # Match narration text in TS/JSON: "text": "..." or 'text': '...'
        text_pattern = re.compile(r'["\']text["\']\s*:\s*["\'](.+?)["\']', re.DOTALL)
        for i, m in enumerate(text_pattern.finditer(content), 1):
            text = m.group(1)
            chars = len(re.findall(r'[一-鿿\w]', text))
            if chars > 80:
                line_no = content[:m.start()].count('\n') + 1
                results.append(RuleResult(
                    rule_id='SB-001', name='单页字数过多', severity='warning',
                    file_path=file_path,
                    message=f'第 {i} 页 narration {chars} 字（>80），建议精简',
                    line_number=line_no,
                ))
        return results


@rule("SB-002", severity="warning", file_types=["theme.css", "*.css"])
class SB002:
    """默认主题：检查 theme.css 是否为默认样式。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        default_indicators = [
            ':root {',
            '--bg: #fff',
            '--bg: #ffffff',
            '--fg: #000',
            '--fg: #000000',
        ]
        has_default = sum(1 for d in default_indicators if d in content)
        if has_default >= 3:
            results.append(RuleResult(
                rule_id='SB-002', name='默认主题', severity='warning',
                file_path=file_path,
                message='theme.css 似乎是默认样式，建议自定义主题',
            ))
        return results


@rule("SB-003", severity="warning", file_types=["theme.css", "*.css"])
class SB003:
    """对比度不足：检查 CSS 变量中的颜色对比度。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        hex_pattern = re.compile(r'--\w*(?:bg|background|fg|color|text)\w*:\s*(#[0-9a-fA-F]{3,8})', re.IGNORECASE)
        colors = hex_pattern.findall(content)
        # Check for very light colors on white bg (low contrast)
        light_colors = [c for c in colors if len(c) in (4, 7)]
        for c in light_colors:
            # Simple check: hex color with all components > CC is very light
            hex_val = c.lstrip('#')
            if len(hex_val) == 3:
                hex_val = ''.join(ch * 2 for ch in hex_val)
            if len(hex_val) == 6:
                r, g, b = int(hex_val[:2], 16), int(hex_val[2:4], 16), int(hex_val[4:6], 16)
                # Very light text on white bg
                if r > 200 and g > 200 and b > 200:
                    results.append(RuleResult(
                        rule_id='SB-003', name='对比度不足', severity='warning',
                        file_path=file_path,
                        message=f'颜色 {c} 过浅，可能在白色背景上对比度不足',
                    ))
        return results


@rule("SB-004", severity="warning", file_types=["*.css"])
class SB004:
    """动画 >3 种：检查 CSS animation 属性数量。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        anim_pattern = re.compile(r'@keyframes\s+([\w-]+)', re.IGNORECASE)
        keyframes = anim_pattern.findall(content)
        if len(keyframes) > 3:
            results.append(RuleResult(
                rule_id='SB-004', name='动画种类过多', severity='warning',
                file_path=file_path,
                message=f'定义了 {len(keyframes)} 种动画（>3），建议精简: {", ".join(keyframes[:5])}',
            ))
        return results


@rule("SB-005", severity="critical", file_types=["*.tsx", "*.jsx", "*.json"])
class SB005:
    """占位图：检测 placeholder 图片引用。"""

    @staticmethod
    def detect(content: str, file_path: str) -> list[RuleResult]:
        results: list[RuleResult] = []
        placeholders = [
            'image · 16:9',
            'image · 16:9 description',
            'placeholder',
            'placehold.co',
            'placehold.it',
            'via.placeholder.com',
            'dummyimage.com',
        ]
        for i, line in enumerate(content.splitlines(), 1):
            for pat in placeholders:
                if pat.lower() in line.lower():
                    results.append(RuleResult(
                        rule_id='SB-005', name='占位图', severity='critical',
                        file_path=file_path,
                        message=f'检测到占位图引用 "{pat}"，建议替换为真实图片',
                        line_number=i,
                    ))
        return results


# ---------------------------------------------------------------------------
# Rule registry — function-based rules (legacy)
# ---------------------------------------------------------------------------

ALL_RULES: list[Rule] = [
    # TR series
    Rule(id='TR-001', name='连续无标点长句', severity='warning',
         detect=detect_tr001, description='连续 3 个以上无标点长句（>50 字）'),
    Rule(id='TR-002', name='说话人标签格式不统一', severity='warning',
         detect=detect_tr002, description='说话人标签格式不统一'),
    Rule(id='TR-003', name='时间戳不连续或重叠', severity='critical',
         detect=detect_tr003, description='时间戳不连续或重叠'),
    Rule(id='TR-004', name='填充词密度过高', severity='warning',
         detect=detect_tr004, description='填充词密度 >5%'),
    Rule(id='TR-005', name='中英文标点混用', severity='warning',
         detect=detect_tr005, description='中英文标点混用'),
    # CD series
    Rule(id='CD-001', name='大纲层级过深', severity='warning',
         detect=detect_cd001, description='大纲层级超过 4 层'),
    Rule(id='CD-002', name='单章节字数过多', severity='warning',
         detect=detect_cd002, description='单章节字数 >500 字'),
    Rule(id='CD-003', name='口播脚本包含书面语', severity='warning',
         detect=detect_cd003, description='口播脚本包含书面语'),
    Rule(id='CD-005', name='缺乏 Hook', severity='warning',
         detect=detect_cd005, description='前 10 秒无吸引力语句'),
    Rule(id='CD-006', name='表达 DNA 未注入', severity='warning',
         detect=detect_cd006, description='未按选定视角风格执行'),
    # VO series
    Rule(id='VO-001', name='语速异常', severity='warning',
         detect=detect_vo001, description='语速 >180 或 <120 字/分钟'),
    Rule(id='VO-002', name='单句长度过长', severity='warning',
         detect=detect_vo002, description='单句长度 >50 字'),
    Rule(id='VO-003', name='多音字未标注', severity='warning',
         detect=detect_vo003, description='多音字缺少拼音标注'),
    Rule(id='VO-004', name='缺乏停顿标记', severity='warning',
         detect=detect_vo004, description='连续 5 句无逗号/句号'),
    # SL series
    Rule(id='SL-001', name='假共情', severity='critical',
         detect=detect_sl001, description='假共情模式'),
    Rule(id='SL-002', name='假深刻', severity='critical',
         detect=detect_sl002, description='假深刻包装'),
    Rule(id='SL-003', name='自我标榜', severity='critical',
         detect=detect_sl003, description='自我标榜语句'),
    Rule(id='SL-004', name='万能模板', severity='critical',
         detect=detect_sl004, description='万能模板短语'),
    Rule(id='SL-005', name='排比堆砌', severity='critical',
         detect=detect_sl005, description='连续 3+ 句结构相同'),
    Rule(id='SL-006', name='套话结尾', severity='critical',
         detect=detect_sl006, description='套话结尾模式'),
]

# VV rule IDs are handled separately by vision_rules.py
VV_RULE_IDS = {'VV-001', 'VV-002', 'VV-003', 'VV-004', 'VV-005'}

# Auto-collected from @rule decorator
DECORATOR_RULE_IDS = [k for k in _RULE_REGISTRY if k.startswith("VV-")]
ALL_RULE_IDS = [r.id for r in ALL_RULES] + list(_RULE_REGISTRY.keys())
VV_RULE_IDS = VV_RULE_IDS | {k for k in _RULE_REGISTRY if k.startswith("VV-")}


def get_decorator_rules() -> dict[str, dict]:
    """Return all rules registered via @rule decorator."""
    return dict(_RULE_REGISTRY)


def list_all_rules() -> list[dict]:
    """Return a summary of all registered rules (function + decorator)."""
    rules = []
    for r in ALL_RULES:
        rules.append({"id": r.id, "name": r.name, "severity": r.severity, "source": "function"})
    for rule_id, info in _RULE_REGISTRY.items():
        rules.append({
            "id": rule_id,
            "name": info["class"].__doc__.split("：")[0].strip() if info["class"].__doc__ else rule_id,
            "severity": info["severity"],
            "source": "decorator",
        })
    return rules


def get_rules_by_ids(rule_ids: list[str]) -> list[Rule]:
    """Get rules by their IDs. Raises ValueError for unknown IDs.

    VV-xxx IDs are recognized but not returned (they're handled by vision_rules.py).
    """
    id_set = set(rule_ids)
    found = [r for r in ALL_RULES if r.id in id_set]
    known = {r.id for r in found} | VV_RULE_IDS | set(_RULE_REGISTRY.keys())
    missing = id_set - known
    if missing:
        raise ValueError(f'Unknown rule IDs: {", ".join(sorted(missing))}')
    return found
