# DS/CH/SB Rule Engine Spec

## Metadata

- Iteration: 7
- Track: v3.1.0 rule engine
- Created: 2026-05-30

## Context

ARCHITECTURE.md 定义了 17 条规则（DS-001~006, CH-001~006, SB-001~005），但 rules.py 中未实现。当前 audit skill 只有 TR/VO/SL/CD/RD/VV 规则。

## Rules to Implement

### DS-001~006 (Distill-Style)

| ID | 检测 | 实现方式 |
|----|------|---------|
| DS-001 | 信息保留度 <60% | 字符比：script.md / article.md |
| DS-002 | 单句 >20 字 | 正则：按句号/问号/叹号分割，检查字数 |
| DS-003 | 第三人称疏离 | 正则：匹配"用户""读者""大家" |
| DS-004 | 无钩子开头 | 检查前 100 字是否含问号/反差词 |
| DS-005 | 结构词堆砌 | 正则：匹配"首先.*其次.*最后" |
| DS-006 | 数字未翻译 | 正则：匹配纯百分比/大数字无上下文 |

### CH-001~006 (Chapter Visual)

| ID | 检测 | 实现方式 |
|----|------|---------|
| CH-001 | 纯文字无视觉 | grep Chapter.tsx 无 img/SVG/animation |
| CH-002 | 列表一次揭示 | grep Chapter.tsx 多项同 step |
| CH-003 | AI 视觉指纹 | grep 紫粉渐变/圆角彩色边框/emoji |
| CH-004 | 假数据 | grep "X0K users"/假 logo |
| CH-005 | 全场同动画 | grep 单一 animation 名称重复 |
| CH-006 | 动画过多 | grep 每步都有 ken burns/光晕 |

### SB-001~005 (Storyboard Design)

| ID | 检测 | 实现方式 |
|----|------|---------|
| SB-001 | 单页 >80 字 | 检查 narrations.ts 每项字数 |
| SB-002 | 默认主题 | 检查 theme.css 是否为默认 |
| SB-003 | 对比度不足 | 解析 CSS 计算对比度 |
| SB-004 | 动画 >3 种 | grep Chapter.css animation 属性 |
| SB-005 | 占位图 | grep "image · 16:9" 或 placeholder |

## File Changes

- `tools/audit/rules.py` — 添加 DS/CH/SB 规则类
- `tools/audit/__init__.py` — 注册新规则
- `skills/audit/SKILL.md` — 更新规则覆盖表

## Acceptance Criteria

- [ ] `python -m tools.audit --rule DS-001` 输出检测结果
- [ ] `python -m tools.audit --rule CH-001` 输出检测结果
- [ ] `python -m tools.audit --rule SB-001` 输出检测结果
- [ ] 17 条规则全部注册到审计引擎
- [ ] 现有 TR/VO/SL/CD/RD/VV 规则不受影响
