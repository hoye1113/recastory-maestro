"""Tests for audit rules."""
import json
import pytest
from tools.audit.rules import (
    RuleResult, Rule, ALL_RULES, get_rules_by_ids,
    detect_tr001, detect_tr002, detect_tr003, detect_tr004, detect_tr005,
    detect_cd001, detect_cd002, detect_cd003, detect_cd005, detect_cd006,
    detect_vo001, detect_vo002, detect_vo003, detect_vo004,
    detect_sl001, detect_sl002, detect_sl003, detect_sl004, detect_sl005, detect_sl006,
)


# ============================================================================
# TR-001: 连续 3 个以上无标点长句（>50 字）
# ============================================================================

class TestTR001:
    def test_detects_three_consecutive_long_sentences(self):
        # 3 lines, each >50 chars, no sentence-ending punctuation
        lines = [
            '这是一段超过五十个字的很长很长很长的长句子用来测试规则是否能够正确检测到连续出现的长句子问题并且不应该被漏检',
            '这又是一段超过五十个字的很长很长很长的长句子用来测试规则是否能够正确检测到连续出现的长句子问题并且不应该被漏检',
            '这还是一段超过五十个字的很长很长很长的长句子用来测试规则是否能够正确检测到连续出现的长句子问题并且不应该被漏检',
        ]
        content = '\n'.join(lines)
        results = detect_tr001(content, 'test.md')
        assert len(results) > 0
        assert results[0].rule_id == 'TR-001'

    def test_no_false_positive_short_sentences(self):
        content = '短句。另一个短句。第三句。第四句。'
        results = detect_tr001(content, 'test.md')
        assert len(results) == 0

    def test_no_false_positive_with_punctuation(self):
        # Long sentences but with punctuation
        lines = [
            '这是一段超过五十个字的很长很长很长的长句子用来测试规则，但是有标点符号所以不应该被检测到。',
            '这又是一段超过五十个字的很长很长很长的长句子用来测试规则，但是有标点符号所以不应该被检测到。',
            '这还是一段超过五十个字的很长很长很长的长句子用来测试规则，但是有标点符号所以不应该被检测到。',
        ]
        content = '\n'.join(lines)
        results = detect_tr001(content, 'test.md')
        assert len(results) == 0

    def test_two_long_sentences_not_detected(self):
        # Only 2 consecutive — should not trigger
        lines = [
            '这是一段超过五十个字的很长很长很长的长句子用来测试规则是否能够正确检测到连续出现的长句子问题并且不应该被漏检',
            '这又是一段超过五十个字的很长很长很长的长句子用来测试规则是否能够正确检测到连续出现的长句子问题并且不应该被漏检',
        ]
        content = '\n'.join(lines)
        results = detect_tr001(content, 'test.md')
        assert len(results) == 0


# ============================================================================
# TR-002: 说话人标签格式不统一
# ============================================================================

class TestTR002:
    def test_detects_non_standard_speaker_label(self):
        content = '张三：你好\n李四：世界'
        results = detect_tr002(content, 'test.md')
        assert len(results) > 0
        assert results[0].rule_id == 'TR-002'

    def test_no_false_positive_standard_format(self):
        content = '[张三] 你好\n[李四] 世界'
        results = detect_tr002(content, 'test.md')
        assert len(results) == 0

    def test_no_false_positive_no_speakers(self):
        content = '这是一段没有说话人的普通文本。'
        results = detect_tr002(content, 'test.md')
        assert len(results) == 0


# ============================================================================
# TR-003: 时间戳不连续或重叠
# ============================================================================

class TestTR003:
    def test_detects_overlap(self):
        content = (
            '1\n00:00:00,000 --> 00:00:05,000\nHello\n\n'
            '2\n00:00:04,000 --> 00:00:08,000\nWorld\n'
        )
        results = detect_tr003(content, 'test.srt')
        assert len(results) > 0
        assert any(r.rule_id == 'TR-003' and '重叠' in r.message for r in results)

    def test_detects_gap(self):
        content = (
            '1\n00:00:00,000 --> 00:00:02,000\nHello\n\n'
            '2\n00:00:05,000 --> 00:00:08,000\nWorld\n'
        )
        results = detect_tr003(content, 'test.srt')
        assert len(results) > 0
        assert any(r.rule_id == 'TR-003' and '不连续' in r.message for r in results)

    def test_no_false_positive_continuous(self):
        content = (
            '1\n00:00:00,000 --> 00:00:02,000\nHello\n\n'
            '2\n00:00:02,000 --> 00:00:04,000\nWorld\n'
        )
        results = detect_tr003(content, 'test.srt')
        assert len(results) == 0


# ============================================================================
# TR-004: 填充词密度过高（>5%）
# ============================================================================

class TestTR004:
    def test_detects_high_filler_density(self):
        # Lots of filler words
        content = '嗯啊这个那个嗯啊这个那个嗯啊这个那个嗯啊这个那个嗯啊这个那个你好世界测试文本内容填充词密度检测'
        results = detect_tr004(content, 'test.md')
        assert len(results) > 0
        assert results[0].rule_id == 'TR-004'

    def test_no_false_positive_normal_text(self):
        content = '这是一段正常的文本，没有任何填充词。今天天气很好，我们出去走走吧。'
        results = detect_tr004(content, 'test.md')
        assert len(results) == 0


# ============================================================================
# TR-005: 中英文标点混用
# ============================================================================

class TestTR005:
    def test_detects_mixed_punctuation(self):
        content = '这是中文，with English. 混合标点!'
        results = detect_tr005(content, 'test.md')
        assert len(results) > 0
        assert results[0].rule_id == 'TR-005'

    def test_no_false_positive_chinese_only(self):
        content = '这是纯中文标点，没有英文标点。很好！'
        results = detect_tr005(content, 'test.md')
        assert len(results) == 0

    def test_no_false_positive_english_only(self):
        content = 'This is English only. No Chinese punctuation!'
        results = detect_tr005(content, 'test.md')
        assert len(results) == 0


# ============================================================================
# CD-001: 大纲层级超过 4 层
# ============================================================================

class TestCD001:
    def test_detects_deep_heading(self):
        content = '# Title\n## L2\n### L3\n#### L4\n##### L5'
        results = detect_cd001(content, 'outline.md')
        assert len(results) > 0
        assert results[0].rule_id == 'CD-001'

    def test_no_false_positive_four_levels(self):
        content = '# Title\n## L2\n### L3\n#### L4'
        results = detect_cd001(content, 'outline.md')
        assert len(results) == 0


# ============================================================================
# CD-002: 单章节字数 >500 字
# ============================================================================

class TestCD002:
    def test_detects_long_section(self):
        body = '这是一段很长的文本。' * 60  # >500 chars
        content = f'## 第一章\n{body}\n## 第二章\n短文本'
        results = detect_cd002(content, 'outline.md')
        assert len(results) > 0
        assert results[0].rule_id == 'CD-002'

    def test_no_false_positive_short_sections(self):
        content = '## 第一章\n短文本。\n## 第二章\n也是短文本。'
        results = detect_cd002(content, 'outline.md')
        assert len(results) == 0


# ============================================================================
# CD-003: 口播脚本包含书面语
# ============================================================================

class TestCD003:
    def test_detects_formal_language(self):
        content = '综上所述，我们可以得出结论。'
        results = detect_cd003(content, 'script.md')
        assert len(results) > 0
        assert any('综上所述' in r.message for r in results)

    def test_detects_another_formal_pattern(self):
        content = '由此可见，这个方法是有效的。'
        results = detect_cd003(content, 'script.md')
        assert len(results) > 0

    def test_no_false_positive_colloquial(self):
        content = '说白了就是这么回事。你看，其实很简单。我们聊聊吧。'
        results = detect_cd003(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# CD-005: 缺乏 Hook
# ============================================================================

class TestCD005:
    def test_detects_no_hook(self):
        # Opening without question/exclamation/address
        content = '咖啡是一种饮料。它由咖啡豆制成。世界各地都有种植。'
        results = detect_cd005(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'CD-005'

    def test_no_false_positive_with_question(self):
        content = '你有没有想过，咖啡为什么会变苦？'
        results = detect_cd005(content, 'script.md')
        assert len(results) == 0

    def test_no_false_positive_with_exclamation(self):
        content = '太不可思议了！这个发现改变了一切。'
        results = detect_cd005(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# CD-006: 表达 DNA 未注入
# ============================================================================

class TestCD006:
    def test_detects_no_perspective(self):
        content = '这是一段没有任何特定风格标记的普通脚本内容。'
        results = detect_cd006(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'CD-006'

    def test_no_false_positive_with_perspective(self):
        content = '使用费曼视角来解释这个概念。Expression DNA: colloquial.'
        results = detect_cd006(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# VO-001: 语速异常
# ============================================================================

class TestVO001:
    def test_detects_abnormal_rate_from_json(self):
        data = {
            'segments': [
                {'text': '这是很长的一段话用来测试语速', 'start': 0, 'end': 1}  # Very fast
            ]
        }
        content = json.dumps(data, ensure_ascii=False)
        results = detect_vo001(content, 'audio.json')
        assert len(results) > 0
        assert results[0].rule_id == 'VO-001'

    def test_no_false_positive_normal_rate(self):
        data = {
            'segments': [
                {'text': '正常语速的一句话', 'start': 0, 'end': 3}  # ~160 chars/min
            ]
        }
        content = json.dumps(data, ensure_ascii=False)
        results = detect_vo001(content, 'audio.json')
        assert len(results) == 0


# ============================================================================
# VO-002: 单句长度 >50 字
# ============================================================================

class TestVO002:
    def test_detects_long_sentence(self):
        content = '这是一段超过五十个字的很长很长很长的句子用来测试单句长度检测规则是否能够正确工作并且报告出问题所在的位置信息'
        results = detect_vo002(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'VO-002'

    def test_no_false_positive_short_sentences(self):
        content = '短句。另一个短句。第三句。'
        results = detect_vo002(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# VO-003: 多音字未标注
# ============================================================================

class TestVO003:
    def test_detects_unannotated_polyphone(self):
        content = '金融行业发展迅速。'
        results = detect_vo003(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'VO-003'

    def test_no_false_positive_with_annotation(self):
        content = '银行(háng)业发展迅速。'
        results = detect_vo003(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# VO-004: 缺乏停顿标记
# ============================================================================

class TestVO004:
    def test_detects_no_pause_markers(self):
        lines = ['没有标点的句子'] * 6
        content = '\n'.join(lines)
        results = detect_vo004(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'VO-004'

    def test_no_false_positive_with_punctuation(self):
        lines = ['有标点的句子，', '另一句。', '第三句！', '第四句？', '第五句；']
        content = '\n'.join(lines)
        results = detect_vo004(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# SL-001: 假共情
# ============================================================================

class TestSL001:
    def test_detects_fake_empathy(self):
        content = '我知道你可能觉得这很难。'
        results = detect_sl001(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'SL-001'
        assert results[0].severity == 'critical'

    def test_detects_another_pattern(self):
        content = '你是不是也遇到过这种情况？'
        results = detect_sl001(content, 'script.md')
        assert len(results) > 0

    def test_no_false_positive_genuine(self):
        content = '今天我们来聊聊冷萃咖啡。'
        results = detect_sl001(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# SL-002: 假深刻
# ============================================================================

class TestSL002:
    def test_detects_fake_depth(self):
        content = '恰恰是这种思维方式导致了问题。'
        results = detect_sl002(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'SL-002'

    def test_detects_faner(self):
        content = '反而让事情变得更复杂了。'
        results = detect_sl002(content, 'script.md')
        assert len(results) > 0

    def test_no_false_positive_direct_statement(self):
        content = '咖啡凉了会更苦。这是科学事实。'
        results = detect_sl002(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# SL-003: 自我标榜
# ============================================================================

class TestSL003:
    def test_detects_self_promotion(self):
        content = '颠覆认知的事实是——'
        results = detect_sl003(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'SL-003'

    def test_detects_must_listen(self):
        content = '你一定要听完这个内容！'
        results = detect_sl003(content, 'script.md')
        assert len(results) > 0

    def test_no_false_positive_normal(self):
        content = '今天我们来做一个实验。准备两杯咖啡。'
        results = detect_sl003(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# SL-004: 万能模板
# ============================================================================

class TestSL004:
    def test_detects_template_phrase(self):
        content = '说白了就是这么回事。'
        results = detect_sl004(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'SL-004'

    def test_detects_benzhi(self):
        content = '本质上这是一个化学反应。'
        results = detect_sl004(content, 'script.md')
        assert len(results) > 0

    def test_no_false_positive_direct(self):
        content = '咖啡里有两拨东西。一拨负责苦，一拨负责香。'
        results = detect_sl004(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# SL-005: 排比堆砌
# ============================================================================

class TestSL005:
    def test_detects_parallel_structure(self):
        lines = [
            '这种咖啡很苦。',
            '这种茶叶很香。',
            '这种果汁很甜。',
        ]
        content = '\n'.join(lines)
        results = detect_sl005(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'SL-005'

    def test_no_false_positive_varied_structure(self):
        lines = [
            '咖啡很苦。',
            '你试过冷萃吗？',
            '加冰会好一些。',
        ]
        content = '\n'.join(lines)
        results = detect_sl005(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# SL-006: 套话结尾
# ============================================================================

class TestSL006:
    def test_detects_template_ending(self):
        content = '以上就是本期内容，感谢观看。'
        results = detect_sl006(content, 'script.md')
        assert len(results) > 0
        assert results[0].rule_id == 'SL-006'

    def test_detects_thanks_for_watching(self):
        content = '感谢收看，我们下期再见！'
        results = detect_sl006(content, 'script.md')
        assert len(results) > 0

    def test_no_false_positive_creative_ending(self):
        content = '下次你泡咖啡的时候，记得趁热喝。凉了就做冷萃吧。'
        results = detect_sl006(content, 'script.md')
        assert len(results) == 0


# ============================================================================
# Rule registry tests
# ============================================================================

class TestRuleRegistry:
    def test_all_rules_count(self):
        assert len(ALL_RULES) == 20  # TR:5 + CD:5 + VO:4 + SL:6

    def test_get_rules_by_ids(self):
        rules = get_rules_by_ids(['TR-001', 'SL-001'])
        assert len(rules) == 2
        assert {r.id for r in rules} == {'TR-001', 'SL-001'}

    def test_get_rules_by_ids_unknown_raises(self):
        with pytest.raises(ValueError, match='Unknown rule IDs'):
            get_rules_by_ids(['XX-999'])

    def test_rule_dataclass_fields(self):
        r = ALL_RULES[0]
        assert isinstance(r, Rule)
        assert r.id and r.name and r.severity and r.detect and r.description

    def test_rule_result_dataclass(self):
        rr = RuleResult(
            rule_id='TEST', name='test', severity='warning',
            file_path='test.md', message='msg', line_number=1,
        )
        assert rr.rule_id == 'TEST'
        assert rr.line_number == 1
