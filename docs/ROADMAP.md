# Recastory Roadmap

## v3.0.0 (current)

Released 2026-05-30.

- CDP Screencast 录屏 + FFmpeg 编码
- SRT 字幕拆行（≤20字/行，底部对齐）
- TTS 多 Provider 降级链
- 完整文档体系
- 9/14 skills 有 test-prompts.json（5 个 LLM 依赖型 skill 豁免，见下方）

## v3.1.0 (planned)

### qwen3-tts 修复

**阻塞项**:
- PyTorch CPU-only：需安装 CUDA 版本（download.pytorch.org 国内不可达）
- SoX 缺失：Windows 上需手动安装
- py launcher 未适配：脚本用 `py` 调用但 venv 内无 `py` 命令

**当前降级方案**: minimax → edge-tts（优先级 1+3），qwen3-tts 作为 P3 provider。

### BGM 混音

**依赖**: mmx-cli music generate 可用 + 风格确定。

**当前状态**: `mix-bgm.sh` 已实现（ENABLE_BGM=true 触发），但无 BGM 素材和风格模板。

### 规则引擎实现

**目标**: audit skill 全量确定性质量门控。

| 规则集 | 当前状态 | v3.1.0 目标 |
|--------|---------|------------|
| RD (render) | ✅ 已实现 | 保持 |
| DS (distill-style) | ✅ 已实现 (2026-05-30) | 6 条口语化规则 via @rule 装饰器 |
| CH (chapter visual) | ✅ 已实现 (2026-05-30) | 6 条视觉规则 via @rule 装饰器 |
| SB (storyboard design) | ✅ 已实现 (2026-05-30) | 5 条分镜规则 via @rule 装饰器 |

**参考**: ARCHITECTURE.md 中 DS-001~006、CH-001~006、SB-001~005 规则定义。

### 测试框架

**目标**: 每个 skill 有最小测试契约。

- 每个 skill 至少有 `test-prompts.json` + `expected-output.md`
- 核心 skill（render/voice/distill/storyboard）有 `test/` 目录
- 定义最小测试契约：输入 → 预期输出 → 自动验证

**豁免 skill（5/14）** — 输出为 LLM 自由文本，无法硬编码预期：

| Skill | 类型 | 豁免原因 |
|-------|------|---------|
| critique | LLM 深度审查 | 输出为自由文本分析 |
| humanizer-zh | 文本改写 | 输入输出均为自然语言 |
| nuwa-skill | 视角工厂 | 15 个视角模板，组合爆炸 |
| perspectives | 视角引擎 | feynman/mrbeast 等，输出不确定 |
| web-video-presentation | 方法论参考 | 纯文档型，无可执行逻辑 |

### Skills 优化（darwin-skill 整合）

> 目标：用 darwin-skill 自主进化系统对 Recastory 的确定性 skills 进行量化评估与定向优化。
> 豁免：critique / humanizer-zh / nuwa-skill / perspectives / web-video-presentation 为 LLM 创意型 skill，不参与 darwin-skill 自动优化，保留人工审计。

#### Phase 1: 测试资产补齐（✅ 已完成 2026-05-30）

- [x] 为 5 个豁免 skills 补 test-prompts.json（或标记 `darwin-exempt: true`）
- [x] 审计现有 9 个 skills 的 test-prompts.json 质量（happy path + edge case 覆盖）

**结果**: critique/humanizer-zh 各 3 条 test-prompts。nuwa-skill/perspectives/web-video-presentation 标记 `darwin-exempt: true`。

#### Phase 2: 基线评估（✅ 已完成 2026-05-30）

- [x] 安装 darwin-skill: `npx skills add alchaincyf/darwin-skill`
- [x] 对 9 个确定性 skills 跑基线评估，生成 results.tsv
- [x] 识别最低分维度，制定优化优先级

**结果**: 平均 85.9 分。最低分: ingest/transcribe (82)。优化优先级: ingest → transcribe → render。

#### Phase 3: 定向优化（✅ 已完成 2026-05-30）

- [x] 对 ingest / transcribe / render 跑 darwin-skill 优化循环（每 skill 3 轮）
- [x] 棘轮机制：只保留可测量改进，自动回滚退步
- [x] 人类检查点：每 skill 优化后暂停确认

**结果**: ingest 82→91.3, transcribe 82→91.3, render 85→88.8。全部 keep。

- [x] 对 audit / research / distill / using-recastory / voice / storyboard 跑 darwin-skill 优化循环
- [x] 棘轮机制：全部 keep，0 回滚

**结果**: audit 84→90.3, research 84→90.3, distill 86→91.3, using-recastory 87→91.3, voice 88→90.3, storyboard 90→92.3。9 个确定性 skills 平均 85.9→90.8。

#### Phase 4: 成果可视化（✅ 已完成 2026-05-30）

- [x] 将 results.tsv 纳入 Recastory 质量报告（docs/skill-evolution/results.tsv）
- [x] 生成 result-card.html 存入 `docs/skill-evolution/`（summary + ingest 两张卡片）
- [x] 更新 skills/*/SKILL.md 头部，标注 darwin-skill 评分与版本（2026-05-30）

**产物**：

- `docs/skill-evolution/results.tsv` — 9 skills × 2 批次优化日志
- `docs/skill-evolution/result-card-summary.html` — 9 skills 总览卡片（85.9→90.8）
- `docs/skill-evolution/result-card-ingest.html` — ingest 深度卡片（82→91.3）
- PNG 截图待 Chrome 环境就绪后生成

### VV_RULE_IDS 自动收集（✅ 已完成 2026-05-30）

**目标**: 消除手动维护规则 ID 列表的风险。

- [x] `@rule` 装饰器自动注册规则到 `_RULE_REGISTRY`，替代手动 VV_RULE_IDS 列表
- [x] `VV_RULE_IDS` / `ALL_RULE_IDS` 从 registry 自动导出
- [x] `get_all_rules()` 函数输出所有注册规则（function + decorator）
