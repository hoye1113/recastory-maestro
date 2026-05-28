# Development Loop Protocol

> Claude Code 自主循环开发协议。触发后无需人工干预，直到暂停或达到停止条件。

---

## 触发条件

当用户说以下任一关键词时启动：
- "开始循环开发" / "loop" / "自动优化" / "循环开发"

## 循环结构

```
┌──────────────────────────────────────────────────────────────┐
│  Iteration N                                                  │
│                                                               │
│  1. AUDIT      → 多视角扫描（见下方扫描协议）                   │
│  2. TRIAGE     → 按 Track 优先级 + 严重度排序                  │
│  3. SPEC       → 为每个 issue 生成 spec 文件                   │
│  4. FIX        → subagent 修复（每个 issue 一个 subagent）     │
│  5. REVIEW     → 三轮审查（spec → quality → neutrality）       │
│  6. REGRESSION → 回归检查（修复是否引入新问题）                  │
│  7. E2E        → 必要时插入端到端验证                           │
│  8. COMMIT     → 本轮修复打包提交                               │
│  9. PROGRESS   → 更新进度文件，对比上轮改善                      │
│ 10. LOOP       → 回到 1                                       │
└──────────────────────────────────────────────────────────────┘
```

---

## 多视角扫描协议（Step 1 详细）

每轮 AUDIT 阶段调用以下 skill/agent，多角度发现问题：

| 阶段 | 调用方式 | 目的 | 输出 |
|------|---------|------|------|
| 1a. 结构扫描 | Agent(Explore) | 文件引用、目录结构、死链接 | issue 列表 |
| 1b. Skill 质量 | Skill(darwin-skill) | 8 维度评分（对 SKILL.md 文件） | 分数 + 改进建议 |
| 1c. 代码质量 | Agent(Explore) shell/JSON focus | shell 脚本缺陷、JSON schema 不一致 | issue 列表 |
| 1d. 文档一致性 | Agent(Explore) cross-doc | ARCHITECTURE/WORKFLOW/AGENT 与实际代码对齐 | 差异列表 |
| 1e. 安全扫描 | Agent(Explore) security focus | shell injection、hardcoded secrets、权限问题 | issue 列表 |
| 1f. 上轮回归 | diff HEAD~1 vs HEAD | 检查上轮修复是否引入新问题 | regression 列表 |

**扫描合并**: 所有视角的 issue 去重后合并，按 Track 分类，按严重度排序。

**何时用 darwin-skill**:
- 纯 SKILL.md 文件修改 → 用 darwin-skill 三轮审查替代 code-review
- 代码/脚本修改 → 用标准三轮 code-review
- 混合修改 → 先 darwin-skill 审查 SKILL.md 部分，再 code-review 代码部分

---

## Sub-Agent Dispatch 策略（Step 4 详细）

### 分工原则

| 角色 | 模型 | 职责 |
|------|------|------|
| Controller | 主模型（当前 session） | 协调、triage、进度追踪 |
| Implementer | sonnet（简单）/ opus（复杂） | 执行修复 |
| Spec Reviewer | sonnet | 检查改动是否匹配 spec |
| Code Quality Reviewer | sonnet | 代码质量审查 |
| Darwin Reviewer | opus | SKILL.md 8 维度审查 |

### Dispatch 规则

1. **每个 issue 一个 Implementer subagent** — 不同 issue 串行执行（避免文件冲突）
2. **每个 Implementer 完成后 → Spec Reviewer → Code Quality Reviewer** — 串行
3. **SKILL.md 修改 → 替代为 darwin-skill 三轮** — 与 code-review 并行
4. **所有 issue 修复完毕 → 统一 regression check** — 一个 subagent

### Implementer Prompt 模板

```
你是 Implementer subagent。修复以下 issue:

## Issue
[从 spec 文件复制完整内容]

## 上下文
- 项目: recastory-maestro
- 相关文件: [文件路径列表]
- 注意事项: [从 controller 传入的额外约束]

## 要求
1. 只修改 spec 中列出的文件
2. 修改后运行 bash -n / node -e "JSON.parse(...)" 验证
3. 完成后报告: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
```

### Reviewer Prompt 模板

```
你是 [Spec/Code Quality] Reviewer subagent。

## 审查对象
- 变更文件: [git diff 或文件列表]
- 对应 spec: [spec 文件路径]

## 审查标准
[从 loop.md 对应 Review 阶段复制]

## 输出
- ✅ APPROVED / ❌ REJECTED + 具体问题列表
```

---

## 优化 Tracks（按优先级排序）

### Track A: Critical Code Fixes
**优先级: P0 — 每轮必须优先处理**

| ID | Issue | 文件 | 严重度 |
|----|-------|------|--------|
| A-001 | qwen3-tts.sh shell injection vulnerability | scripts/tts-providers/qwen3-tts.sh | critical |
| A-002 | TTS provider scripts 缺少 set -e / error handling | scripts/tts-providers/*.sh (4 files) | critical |
| A-003 | render-video.sh 未校验 puppeteer-launch.js 存在 | tools/render-video.sh | warning |

**完成标准**: 所有 shell 脚本通过 `bash -n` 语法检查，无直接变量插值到 Python/Node 代码中。

---

### Track B: Documentation Alignment
**优先级: P1 — 文档与实际代码对齐**

| ID | Issue | 文件 | 严重度 |
|----|-------|------|--------|
| B-001 | ARCHITECTURE.md 引用 6 个不存在的 anti-patterns.md | ARCHITECTURE.md:225-241 | critical |
| B-002 | ARCHITECTURE.md 引用不存在的 schema.ts/anti-patterns.ts/index.ts | ARCHITECTURE.md:618-674 | critical |
| B-003 | AGENT.md Skills 表缺少 6 个 skill | AGENT.md:36-45 | warning |
| B-004 | README.md "MVP 开发中" vs AGENT.md "v3.0.0" | README.md:86, AGENT.md:7 | warning |
| B-005 | ARCHITECTURE.md 版本号不一致 (v2.0 vs v2.2.0) | ARCHITECTURE.md:1,977 | warning |
| B-006 | WORKFLOW.md Phase 7 缺少 BGM/platform 优化步骤 | WORKFLOW.md:254-266 | warning |
| B-007 | tts-config.json 缺少 tts_install_help 字段 | skills/voice/tts-config.json | warning |
| B-008 | references/INDEX.md 缺少 render 命令条目 | references/INDEX.md | info |

**完成标准**: 所有文档中的文件引用可在项目中找到对应文件，版本号一致。

---

### Track C: Anti-Pattern ID Resolution
**优先级: P1 — 消除规则冲突**

| ID | Issue | 文件 | 严重度 |
|----|-------|------|--------|
| C-001 | RD-001~004 在 ARCHITECTURE.md 和 render/SKILL.md 中定义不同 | 两个文件 | warning |
| C-002 | DS-001~006 在 ARCHITECTURE.md 定义但 rules.py 未实现 | rules.py:11 | warning |
| C-003 | CH-001~006, SB-001~005 同上 | rules.py | warning |
| C-004 | VV_RULE_IDS 手动维护，新规则需手动添加 | rules.py:783 | info |

**策略选择**:
- 方案 1: 统一 ID 命名，render/SKILL.md 的规则改为 RR-001~004（Render-Rule）
- 方案 2: 保留 RD 前缀，但以 rules.py 为准，SKILL.md 中的规则改用 RD-S001 等子前缀
- 方案 3: 实现所有未落地的规则（工作量大，可后续迭代）

**建议采用方案 1**：最小改动，消除冲突。

---

### Track D: Shell Script Quality
**优先级: P2 — 提升脚本健壮性**

| ID | Issue | 文件 | 严重度 |
|----|-------|------|--------|
| D-001 | capture-screenshots.sh 用 sleep 3 而非 polling | tools/capture-screenshots.sh:35 | warning |
| D-002 | capture-screenshots.sh 与 render-video.sh 端口不同 (5174 vs 5173) | 两个文件 | info |
| D-003 | merge-srt.sh 缺少 cleanup trap | tools/merge-srt.sh | info |
| D-004 | render-video.sh heredoc 未 quoted EOF | tools/render-video.sh:168 | info |
| D-005 | generate-images.sh 有死代码 promptPrefix fallback | tools/generate-images.sh:35-36 | info |

**完成标准**: 核心脚本（render-video, merge-mp3, capture-screenshots）使用一致的错误处理模式。

---

### Track E: Config & Reference Cleanup
**优先级: P2 — 配置一致性**

| ID | Issue | 文件 | 严重度 |
|----|-------|------|--------|
| E-001 | tts-config.json defaults 缺少 voice_map | skills/voice/tts-config.json | warning |
| E-002 | 历史 plan 文件仍引用 mmx-config.json | docs/superpowers/plans/*.md (3 files) | info |
| E-003 | package.json test 脚本是 placeholder | package.json:16 | info |
| E-004 | SKILL-TEMPLATE.md 引用不存在的 recastory-test/recastory-score | SKILL-TEMPLATE.md | info |

**完成标准**: 所有 config 文件 schema 一致，无死引用。

---

### Track F: Test Coverage
**优先级: P3 — 补充测试**

| ID | Issue | 文件 | 严重度 |
|----|-------|------|--------|
| F-001 | 9/14 skills 缺少 test-prompts.json | 多个 skill 目录 | warning |
| F-002 | 现有 test-prompts.json 仅 3-5 个 happy-path case | 5 个文件 | warning |
| F-003 | 0 个 skill 有 test/ 目录 | 全局 | warning |

**策略**: 为 render, ingest, transcribe, audit 4 个核心 skill 补充 test-prompts.json，其余后续迭代。

---

### Track G: End-to-End Pipeline Verification
**优先级: P1 — 真实流水线验证**

**触发条件**: Track A-C 完成后，或用户明确要求时插入。

**验证流程**（全自动，无人工干预）:

```
1. INGEST    → 选取一个短视频 URL（≤2min）
2. TRANSCRIBE → ASR 转写
3. DISTILL   → 生成 script.md + outline.md
4. STORYBOARD → 生成分镜
5. VOICE     → TTS 合成（走 tts-config.json 降级链）
6. RENDER    → 渲染 MP4
7. VALIDATE  → 产物验证（见下文）
```

**产物验证步骤**:

| 步骤 | 工具 | 检查内容 |
|------|------|---------|
| G-V1 | ffmpeg | MP4 文件完整，可播放，时长 >0 |
| G-V2 | ffmpeg → mp3 | MP4 转码为 MP3，文件大小合理 |
| G-V3 | ASR (whisper/edge-tts) | MP3 提取文字，与 script.md 对比，相似度 ≥80% |
| G-V4 | puppeteer screenshot | 截图落盘，文件存在且 >10KB |
| G-V5 | MiniMax vision | 截图内容与分镜描述匹配（可选，消耗额度） |
| G-V6 | srt 对比 | 字幕时间戳与音频时长对齐，偏差 ≤0.5s |

**失败处理**:
- G-V1 失败 → 阻断，回溯 render SKILL.md
- G-V2~V3 失败 → 记录 warning，继续
- G-V4 失败 → 检查 capture-screenshots.sh
- G-V5~V6 失败 → 记录 info，不阻断

---

## 三轮审查机制

每轮修复提交前，必须通过以下三轮审查：

### Review 1: Spec Compliance (subagent: Spec Reviewer)
- 检查每项改动是否匹配对应的 issue spec
- 检查是否有超出 spec 范围的额外改动
- 检查是否遗漏 spec 中的 Acceptance Criteria
- 不通过 → Implementer subagent 返修

### Review 2: Code Quality (subagent: Code Quality Reviewer 或 darwin-skill)

**代码文件** (.sh, .py, .json):
- Shell 脚本: `bash -n` 语法检查
- JSON 文件: `node -e "JSON.parse(...)"` 验证
- 无 dead code、无 unused variables
- 变量命名一致、错误处理完备

**SKILL.md 文件** — 替代为 darwin-skill 三轮审查:
- 8 维度评分: Clarity / Completeness / Consistency / Correctness / Concreteness / Runtime-Neutrality / Executability / Maintainability
- 每轮评分 → hill-climbing → 重新评分，直到分数 ≥90 或连续两轮无改善
- darwin-skill 的输出直接替代 code-review 的 SKILL.md 部分

### Review 3: Runtime Neutrality (subagent: Neutrality Reviewer)
- 无 Claude-Code-specific / IDE-specific 语言
- 无 hardcoded paths（除项目约定路径如 `skills/`, `tools/`, `scripts/`）
- 无 platform-specific assumptions（除已知 platform spec）
- 无 "在 Claude Code 中" / "使用 VS Code" 等锁定表述

**审查结果处理**:
- ✅ APPROVED → 进入 COMMIT
- ❌ REJECTED → Implementer 返修 → 重新审查（最多 3 轮）
- 3 轮仍不通过 → 记录 BLOCKED，跳过该 issue，继续下一个

---

## 回归检查（Step 6 详细）

每轮修复提交前，检查修复是否引入新问题：

| 检查项 | 工具 | 通过标准 |
|--------|------|---------|
| 新增文件引用是否存在 | grep + ls | 所有新引用可找到 |
| JSON 文件是否 valid | node JSON.parse | 全部通过 |
| Shell 脚本语法 | bash -n | 全部通过 |
| 上轮已修 issue 是否复发 | 对比上轮 issue 列表 | 无复发 |
| git diff 大小 | wc -l | 单文件改动 ≤200 行 |

**回归失败处理**:
- 引入新 critical → 阻断，立即修复
- 引入新 warning → 记录到下轮 issue 列表
- 上轮 issue 复发 → 阻断，调查根因

---

## 进度追踪（Step 9 详细）

每轮 COMMIT 后更新进度文件：

**文件**: `.claude/loop-progress.md`

```markdown
# Loop Progress

| Iteration | Date | Track | Issues Fixed | Issues Remaining | Regression | Notes |
|-----------|------|-------|-------------|-----------------|------------|-------|
| 1 | 2026-05-29 | A | A-001, A-002, A-003 | 17 | 0 | shell injection + error handling |
| 2 | 2026-05-29 | B | B-001, B-002, B-003, B-004 | 13 | 0 | doc alignment |
| ... | | | | | | |
```

**对比指标**:
- 上轮 issue 总数 vs 本轮 issue 总数 → 改善率
- 上轮 critical 数 vs 本轮 critical 数 → 是否归零
- 上轮 darwin-skill 平均分 vs 本轮 → skill 质量趋势

---

## Spec 文件详细模板

每轮选定的 issue 生成 spec 文件到 `docs/loop-specs/` 目录：

**文件命名**: `iteration-{NNN}-{ISSUE_ID}-{short-title}.md`

**模板**:

```markdown
# [Issue ID]: [Title]

## Metadata
- Iteration: N
- Track: [A-G]
- Severity: critical / warning / info
- Created: YYYY-MM-DD

## Problem
[描述问题，引用具体文件和行号]

## Root Cause
[分析为什么会出现这个问题]

## Affected Files
| 文件 | 改动类型 | 说明 |
|------|---------|------|
| path/to/file | modify / create / delete | 改动说明 |

## Fix Strategy
[具体的修复方案，包含代码片段或伪代码]

## Acceptance Criteria
- [ ] [具体可验证的条件 1]
- [ ] [具体可验证的条件 2]
- [ ] bash -n / JSON.parse 通过

## Review Checklist
- [ ] Spec Compliance: 改动匹配 spec
- [ ] Code Quality / darwin-skill: ≥90 分
- [ ] Runtime Neutrality: 无平台锁定

## Regression Risk
[评估此修复可能影响的其他功能]
```

---

## 安全阀

| 规则 | 说明 |
|------|------|
| 每轮最多改 8 个文件 | 防止大范围破坏性改动 |
| 只修 warning + critical | info 级别记录但不自动修 |
| 每轮必须 commit | 可回滚 |
| 不碰 .env / credentials | 安全红线 |
| shell 脚本改完必须 bash -n | 质量底线 |
| E2E 验证消耗额度时需确认 | 避免意外消耗（仅 mmx 付费部分） |

---

## 停止条件

| 条件 | 类型 |
|------|------|
| 用户说 "暂停" / "停" / "pause" | 手动 |
| 连续两轮扫描无新 issue | 自动 |
| 达到最大迭代次数（默认 10 轮） | 自动 |
| E2E 验证连续 2 次失败 | 自动（需人工排查） |

---

## 端到端验证协议（Track G 详细）

E2E 验证在 Track A-C 完成后触发，或每 3 轮迭代后自动触发一次。

### 全自动流水线

```
Phase 1: 内容生产
  INGEST → TRANSCRIBE → DISTILL → STORYBOARD → VOICE → RENDER
  (选取 ≤2min 短视频，走完整 using-recastory 流程)

Phase 2: 产物验证
  MP4 完整性 → MP3 转码 → ASR 文字提取 → 口播正确性 → 截图落盘

Phase 3: 质量回归
  对比 script.md 原文 vs ASR 提取文字 → 相似度评分
  截图文件存在性 + 大小校验
```

### 口播正确性验证 (G-V3 详细)

| 步骤 | 操作 | 工具 |
|------|------|------|
| 3a | MP4 → MP3 转码 | ffmpeg -i input.mp4 -q:a 2 output.mp3 |
| 3b | MP3 → 文字 ASR | edge-tts --write-subtitles 或 whisper |
| 3c | 提取文字 vs script.md | diff / 相似度算法 |
| 3d | 标点、断句、专有名词检查 | LLM 对比审查 |

**通过标准**: 相似度 ≥80%，无关键信息丢失（专有名词、数字、术语）

### 截图落盘验证 (G-V4 详细)

| 步骤 | 操作 | 通过标准 |
|------|------|---------|
| 4a | 检查 screenshot 目录存在 | 目录存在 |
| 4b | 检查截图文件数量 | ≥ outline 步骤数 |
| 4c | 检查每张截图大小 | ≥ 10KB（非空白） |
| 4d | 可选: MiniMax vision 描述 | 内容与分镜匹配 |

### E2E 失败处理

| 失败级别 | 处理 |
|----------|------|
| 流水线中断 (Phase 1) | 阻断，定位失败步骤，创建新 issue |
| MP4 无法播放 | 阻断，回溯 render SKILL.md |
| 口播相似度 <60% | 阻断，voice SKILL.md 需检查 |
| 口播相似度 60-80% | warning，下轮优化 |
| 截图缺失/空白 | warning，capture-screenshots.sh 需检查 |
| 字幕偏差 >0.5s | info，记录但不阻断 |

---

## 当前审计结果快照

> 2026-05-29 全项目扫描结果

| 严重度 | 数量 | 关键项 |
|--------|------|--------|
| Critical | 3 | A-001 (shell injection), A-002 (no error handling), B-001 (6 missing anti-patterns.md) |
| Warning | 17 | B-002~007, C-001~003, D-001, E-001, F-001~003 |
| Info | 6 | B-008, C-004, D-002~005, E-002~004 |

**预计迭代轮次**: 4-6 轮可清零所有 warning+critical

---

## 环境约束（Loop 执行前置条件）

| 约束 | 说明 |
|------|------|
| 无网络代理 | download.pytorch.org / HuggingFace 等国外源不可达 |
| Qwen3-TTS | 暂不可用（需 PyTorch + CUDA 下载），标记为 deferred |
| 可用 TTS | minimax (✅) + edge-tts (✅)，优先级 1+3 |
| GPU | RTX 3060 6GB，CUDA 13.0，当前仅用于显示 |
| Python | 3.13 (系统) + uv 可创建 3.11 venv |
| mmx 额度 | 有每日限制，E2E 验证时控制调用次数 |

**影响范围**:
- Track A: 无影响（shell 脚本修复不依赖网络）
- Track B-F: 无影响（文档/配置/测试修复）
- Track G (E2E): VOICE 步骤仅用 minimax/edge-tts，跳过 qwen3-tts 验证
