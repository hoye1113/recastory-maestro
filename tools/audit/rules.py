"""Anti-pattern rules for Recastory audit.

Implemented rule groups:
- TR-001~005: Transcription rules
- CD-001~003, CD-005~006: Content distillation rules (CD-004 not yet implemented)
- VO-001~004: Voice rules
- SL-001~006: AI Slop rules

Defined in docs but not yet implemented:
- DS-001~006: Distill-Style oral rules (content-distillation/REFERENCE.md)
- CH-001~006: Visual chapter rules (storyboard/REFERENCE.md)
- SB-001~005: Storyboard design rules (ARCHITECTURE.md)
- RD-001~004: Render rules (ARCHITECTURE.md)
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Callable


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
# TR series — Transcription rules (detect in .md / .srt files)
# ---------------------------------------------------------------------------


def detect_tr001(content: str, file_path: str) -> list[RuleResult]:
    """TR-001: 3+ consecutive long sentences (>50 chars) without punctuation."""
    # Split into lines, strip empty
    lines = [l.strip() for l in content.splitlines() if l.strip()]
    # Sentence-ending punctuation (Chinese + English)
    sent_end = re.compile(r'[。！？.!?；;]')
    results: list[RuleResult] = []
    streak = 0
    streak_start = 0
    for i, line in enumerate(lines, 1):
        # Skip markdown headings and separators
        if line.startswith('#') or line == '---':
            if streak >= 3:
                results.append(RuleResult(
                    rule_id='TR-001',
                    name='连续无标点长句',
                    severity='warning',
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
                    rule_id='TR-001',
                    name='连续无标点长句',
                    severity='warning',
                    file_path=file_path,
                    message=f'连续 {streak} 个无标点长句（>{50}字），第 {streak_start}~{streak_start + streak - 1} 行',
                    line_number=streak_start,
                ))
            streak = 0
    # Check final streak
    if streak >= 3:
        results.append(RuleResult(
            rule_id='TR-001',
            name='连续无标点长句',
            severity='warning',
            file_path=file_path,
            message=f'连续 {streak} 个无标点长句（>{50}字），第 {streak_start}~{streak_start + streak - 1} 行',
            line_number=streak_start,
        ))
    return results


def detect_tr002(content: str, file_path: str) -> list[RuleResult]:
    """TR-002: Speaker label format inconsistency.

    Checks that all speaker labels follow `[speaker] content` format.
    """
    results: list[RuleResult] = []
    # Pattern: lines starting with a bracketed label like [说话人] or [Speaker]
    bracket_pattern = re.compile(r'^\[([^\]]+)\]')
    # Common non-standard patterns: "说话人：" or "Speaker:" at line start
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
                rule_id='TR-002',
                name='说话人标签格式不统一',
                severity='warning',
                file_path=file_path,
                message=f'说话人标签应使用 [说话人] 格式，当前行使用了非标准格式',
                line_number=i,
            ))

    # If both formats exist, it's inconsistent
    if has_bracket and has_non_standard:
        # Already reported individual lines above
        pass
    elif has_non_standard and not has_bracket:
        # All non-standard — still report
        pass

    return results


def detect_tr003(content: str, file_path: str) -> list[RuleResult]:
    """TR-003: SRT timestamp discontinuity or overlap.

    Parses SRT timestamps and checks for gaps/overlaps.
    """
    results: list[RuleResult] = []
    # SRT timestamp pattern: 00:00:00,000 --> 00:00:01,000
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
        if curr_start < prev_end - 0.001:  # overlap
            results.append(RuleResult(
                rule_id='TR-003',
                name='时间戳重叠',
                severity='critical',
                file_path=file_path,
                message=f'时间戳重叠：前段结束 {prev_end:.3f}s > 当前段开始 {curr_start:.3f}s',
                line_number=curr_line,
            ))
        elif curr_start > prev_end + 1.0:  # gap > 1s
            results.append(RuleResult(
                rule_id='TR-003',
                name='时间戳不连续',
                severity='warning',
                file_path=file_path,
                message=f'时间戳不连续：间隔 {curr_start - prev_end:.1f}s（>1s）',
                line_number=curr_line,
            ))

    return results


def detect_tr004(content: str, file_path: str) -> list[RuleResult]:
    """TR-004: Filler word density > 5%."""
    results: list[RuleResult] = []
    fillers = ['嗯', '啊', '呃', '那个', '这个', '就是说', '然后']
    # Count Chinese chars only for density
    chinese_chars = re.findall(r'[一-鿿]', content)
    total = len(chinese_chars)
    if total == 0:
        return results

    filler_count = 0
    for filler in fillers:
        filler_count += content.count(filler)

    density = filler_count / total
    if density > 0.05:
        results.append(RuleResult(
            rule_id='TR-004',
            name='填充词密度过高',
            severity='warning',
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
            rule_id='TR-005',
            name='中英文标点混用',
            severity='warning',
            file_path=file_path,
            message='文件中同时存在中文标点和英文标点，建议统一',
        ))
    return results


# ---------------------------------------------------------------------------
# CD series — Content Distillation rules (detect in script.md / outline.md)
# ---------------------------------------------------------------------------


def detect_cd001(content: str, file_path: str) -> list[RuleResult]:
    """CD-001: Outline heading level deeper than 4 (####)."""
    results: list[RuleResult] = []
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        # Match markdown headings: #### or deeper
        m = re.match(r'^(#{5,})\s', stripped)
        if m:
            level = len(m.group(1))
            results.append(RuleResult(
                rule_id='CD-001',
                name='大纲层级过深',
                severity='warning',
                file_path=file_path,
                message=f'大纲层级 {level} 层（>4），建议扁平化或拆分',
                line_number=i,
            ))
    return results


def detect_cd002(content: str, file_path: str) -> list[RuleResult]:
    """CD-002: Single section > 500 chars (split by ## headings)."""
    results: list[RuleResult] = []
    sections: list[tuple[str, int, str]] = []  # (heading, line_no, body)
    current_heading = ''
    current_start = 1
    current_body_lines: list[str] = []

    for i, line in enumerate(content.splitlines(), 1):
        if line.strip().startswith('## ') and not line.strip().startswith('### '):
            # Save previous section
            if current_body_lines:
                sections.append((current_heading, current_start, '\n'.join(current_body_lines)))
            current_heading = line.strip()
            current_start = i
            current_body_lines = []
        elif not line.strip().startswith('#'):
            current_body_lines.append(line)

    # Last section
    if current_body_lines:
        sections.append((current_heading, current_start, '\n'.join(current_body_lines)))

    for heading, line_no, body in sections:
        # Count Chinese + alphanumeric chars
        char_count = len(re.findall(r'[一-鿿\w]', body))
        if char_count > 500:
            results.append(RuleResult(
                rule_id='CD-002',
                name='单章节字数过多',
                severity='warning',
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
                    rule_id='CD-003',
                    name='口播脚本包含书面语',
                    severity='warning',
                    file_path=file_path,
                    message=f'检测到书面语 "{pat}"，建议替换为口语化表达',
                    line_number=i,
                ))
    return results


def detect_cd005(content: str, file_path: str) -> list[RuleResult]:
    """CD-005: Lack of Hook — first 50 chars have no engaging statement.

    Checks if the opening (first ~50 meaningful characters after headings)
    contains a question, exclamation, or engaging pattern.
    """
    results: list[RuleResult] = []
    # Collect first ~10 seconds of content (first 50 chars of non-heading text)
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

    # Check for engaging patterns
    hook_patterns = [
        r'[？?]',  # Question mark
        r'[！!]',  # Exclamation
        r'你',     # Direct address
        r'吗',     # Question particle
        r'为什么',  # Why question
        r'怎么',    # How question
    ]
    has_hook = any(re.search(p, collected) for p in hook_patterns)
    if not has_hook:
        results.append(RuleResult(
            rule_id='CD-005',
            name='缺乏 Hook',
            severity='warning',
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
            rule_id='CD-006',
            name='表达 DNA 未注入',
            severity='warning',
            file_path=file_path,
            message='未检测到视角标记，建议加载对应视角的 Expression DNA',
        ))
    return results


# ---------------------------------------------------------------------------
# VO series — Voice rules (detect in audio-segments.json / text)
# ---------------------------------------------------------------------------


def detect_vo001(content: str, file_path: str) -> list[RuleResult]:
    """VO-001: Speech rate abnormal — based on char count and estimated duration.

    Checks JSON content for speech_rate field, or estimates from text.
    Normal range: 120~180 chars/minute.
    """
    results: list[RuleResult] = []

    # Try to parse as JSON (audio-segments.json)
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
                rate = char_count / duration * 60  # chars per minute
                if rate > 180 or rate < 120:
                    results.append(RuleResult(
                        rule_id='VO-001',
                        name='语速异常',
                        severity='warning',
                        file_path=file_path,
                        message=f'语速 {rate:.0f} 字/分钟（正常 120~180），文本: {text[:20]}...',
                    ))
            return results
    except (json.JSONDecodeError, KeyError, TypeError):
        pass

    # Fallback: estimate from plain text
    chinese_chars = re.findall(r'[一-鿿]', content)
    total = len(chinese_chars)
    # Assume ~150 chars/min for normal speech
    if total > 0:
        # No duration info, skip rate check for plain text
        pass

    return results


def detect_vo002(content: str, file_path: str) -> list[RuleResult]:
    """VO-002: Single sentence > 50 chars (TTS may break)."""
    results: list[RuleResult] = []
    # Split by sentence-ending punctuation
    sentences = re.split(r'[。！？.!?；;\n]', content)
    for i, sent in enumerate(sentences):
        clean = sent.strip()
        char_count = len(re.findall(r'[一-鿿\w]', clean))
        if char_count > 50:
            # Try to find line number
            line_no = None
            for ln, line in enumerate(content.splitlines(), 1):
                if clean[:20] in line:
                    line_no = ln
                    break
            results.append(RuleResult(
                rule_id='VO-002',
                name='单句长度过长',
                severity='warning',
                file_path=file_path,
                message=f'单句 {char_count} 字（>50），TTS 可能破音，建议拆分: "{clean[:30]}..."',
                line_number=line_no,
            ))
    return results


def detect_vo003(content: str, file_path: str) -> list[RuleResult]:
    """VO-003: Polyphone without pinyin annotation.

    Checks common Chinese polyphones that need annotation for TTS.
    """
    results: list[RuleResult] = []
    polyphones = {
        '行': ['行业', '银行', '行列', '行情'],  # háng vs xíng
        '长': ['成长', '生长'],  # zhǎng vs cháng
        '重': ['重要', '重量', '重复', '重叠'],  # zhòng vs chóng
        '了': ['了解', '了结'],  # liǎo vs le
        '还': ['还是', '还有', '还要'],  # hái vs huán
        '得': ['得到', '得失', '觉得', '记得'],  # dé vs de vs děi
        '地': ['地方', '地球', '地区'],  # dì vs de
        '和': ['和平', '和谐'],  # hé vs hè/huó
    }

    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue
        # Skip if pinyin annotation exists (e.g., 行(xíng))
        if re.search(r'[一-鿿]\([a-z]+\)', stripped):
            continue
        for char, contexts in polyphones.items():
            for ctx in contexts:
                if ctx in stripped and f'{char}(' not in stripped:
                    results.append(RuleResult(
                        rule_id='VO-003',
                        name='多音字未标注',
                        severity='warning',
                        file_path=file_path,
                        message=f'多音字 "{char}"（在"{ctx}"中）缺少拼音标注',
                        line_number=i,
                    ))
                    break  # One report per line per char is enough
    return results


def detect_vo004(content: str, file_path: str) -> list[RuleResult]:
    """VO-004: Lack of pause markers — 5+ consecutive sentences without comma/period."""
    results: list[RuleResult] = []
    pause_marks = re.compile(r'[，。！？,\.!?；;、]')
    lines = [l.strip() for l in content.splitlines() if l.strip() and not l.startswith('#') and l.strip() != '---']

    streak = 0
    streak_start_line = 0
    streak_start_idx = 0

    for idx, line in enumerate(lines):
        if not pause_marks.search(line):
            if streak == 0:
                streak_start_idx = idx
                # Find actual line number in original content
                for ln, orig_line in enumerate(content.splitlines(), 1):
                    if line in orig_line:
                        streak_start_line = ln
                        break
            streak += 1
        else:
            if streak >= 5:
                results.append(RuleResult(
                    rule_id='VO-004',
                    name='缺乏停顿标记',
                    severity='warning',
                    file_path=file_path,
                    message=f'连续 {streak} 句无停顿标记（逗号/句号），建议插入呼吸停顿',
                    line_number=streak_start_line,
                ))
            streak = 0

    if streak >= 5:
        results.append(RuleResult(
            rule_id='VO-004',
            name='缺乏停顿标记',
            severity='warning',
            file_path=file_path,
            message=f'连续 {streak} 句无停顿标记（逗号/句号），建议插入呼吸停顿',
            line_number=streak_start_line,
        ))
    return results


# ---------------------------------------------------------------------------
# SL series — AI Slop rules (detect in script.md)
# ---------------------------------------------------------------------------


def detect_sl001(content: str, file_path: str) -> list[RuleResult]:
    """SL-001: Fake empathy — "我知道你""你是不是也""我能理解"."""
    results: list[RuleResult] = []
    patterns = ['我知道你', '你是不是也', '我能理解', '我理解你的', '你一定觉得']
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        for pat in patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-001',
                    name='假共情',
                    severity='critical',
                    file_path=file_path,
                    message=f'检测到假共情 "{pat}"，建议直接抛事实/钩子',
                    line_number=i,
                ))
    return results


def detect_sl002(content: str, file_path: str) -> list[RuleResult]:
    """SL-002: Fake depth — "恰恰/反而/正是" wrapping.

    For "反而" and "正是", only flag lines >15 chars to avoid false positives
    on short meaningful sentences like "凉了反而更苦".
    """
    results: list[RuleResult] = []
    # Patterns that are almost always fake depth regardless of length
    strong_patterns = ['恰恰是', '恰恰相反', '恰恰说明']
    # Patterns that can be meaningful in short sentences
    weak_patterns = ['反而', '正是']

    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue
        for pat in strong_patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-002',
                    name='假深刻',
                    severity='critical',
                    file_path=file_path,
                    message=f'检测到假深刻 "{pat}"，建议去掉转折直接说结论',
                    line_number=i,
                ))
        # Only flag weak patterns in longer lines (likely empty decoration)
        if len(stripped) > 15:
            for pat in weak_patterns:
                if pat in stripped:
                    results.append(RuleResult(
                        rule_id='SL-002',
                        name='假深刻',
                        severity='critical',
                        file_path=file_path,
                        message=f'检测到假深刻 "{pat}"，建议去掉转折直接说结论',
                        line_number=i,
                    ))
    return results


def detect_sl003(content: str, file_path: str) -> list[RuleResult]:
    """SL-003: Self-promotion — "我必须认真说""颠覆认知""你一定要听完"."""
    results: list[RuleResult] = []
    patterns = ['我必须认真说', '颠覆认知', '你一定要听完', '认真听我说', '一定要看到最后', '这个视频会改变你']
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        for pat in patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-003',
                    name='自我标榜',
                    severity='critical',
                    file_path=file_path,
                    message=f'检测到自我标榜 "{pat}"，建议直接说内容',
                    line_number=i,
                ))
    return results


def detect_sl004(content: str, file_path: str) -> list[RuleResult]:
    """SL-004: Universal template — "说白了/本质上/底层逻辑/一句话总结/归根结底"."""
    results: list[RuleResult] = []
    patterns = ['说白了', '本质上', '底层逻辑', '一句话总结', '归根结底', '说到底']
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        for pat in patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-004',
                    name='万能模板',
                    severity='critical',
                    file_path=file_path,
                    message=f'检测到万能模板 "{pat}"，建议删掉或直接说内容',
                    line_number=i,
                ))
    return results


def detect_sl005(content: str, file_path: str) -> list[RuleResult]:
    """SL-005: Parallel structure piling — 3+ consecutive sentences with same structure.

    Heuristic: Check if 3+ consecutive sentences start with the same pattern.
    """
    results: list[RuleResult] = []
    lines = [l.strip() for l in content.splitlines()
             if l.strip() and not l.startswith('#') and l.strip() != '---']

    # Extract first 2 chars of each sentence as structure fingerprint
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
                # Find line number
                line_no = None
                for ln, orig in enumerate(content.splitlines(), 1):
                    if lines[streak_start] in orig:
                        line_no = ln
                        break
                results.append(RuleResult(
                    rule_id='SL-005',
                    name='排比堆砌',
                    severity='critical',
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
            rule_id='SL-005',
            name='排比堆砌',
            severity='critical',
            file_path=file_path,
            message=f'连续 {streak} 句结构相同，建议保留 1~2 个，其余砍掉',
            line_number=line_no,
        ))
    return results


def detect_sl006(content: str, file_path: str) -> list[RuleResult]:
    """SL-006: Template ending — "以上就是本期内容/希望对你有帮助/感谢观看"."""
    results: list[RuleResult] = []
    patterns = ['以上就是本期内容', '希望对你有帮助', '感谢观看', '感谢收看', '我们下期再见', '下期见']
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        for pat in patterns:
            if pat in stripped:
                results.append(RuleResult(
                    rule_id='SL-006',
                    name='套话结尾',
                    severity='critical',
                    file_path=file_path,
                    message=f'检测到套话结尾 "{pat}"，建议用视角的 Decision Heuristics 设计结尾',
                    line_number=i,
                ))
    return results


# ---------------------------------------------------------------------------
# Rule registry
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


def get_rules_by_ids(rule_ids: list[str]) -> list[Rule]:
    """Get rules by their IDs. Raises ValueError for unknown IDs."""
    id_set = set(rule_ids)
    found = [r for r in ALL_RULES if r.id in id_set]
    missing = id_set - {r.id for r in found}
    if missing:
        raise ValueError(f'Unknown rule IDs: {", ".join(sorted(missing))}')
    return found
