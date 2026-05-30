---
name: voice
version: 1.1.0
description: 将口播稿 script.md 的每个步骤合成为独立 TTS 音频（MP3）和字幕（SRT），支持多 Provider 降级链、多章节批量合成、语速/音色配置、SRT 合并。触发条件：/recastory voice 或被 using-recastory 调度。
---

> Darwin Skill: 90.3/100 (baseline 88 → optimized 2026-05-30)

# Skill: voice

## IRON LAW

**每步一个 MP3，文件名必须匹配 outline.md 步骤编号（如 `01-what/01.mp3`）。音频文件是 storyboard 和 render 的依赖，编号不可错位。** **Provider 可降级，编号规则不可变。**

## Purpose

将口播稿的每个步骤合成为独立音频文件，并生成对应的 SRT 字幕。

## Input

| 文件 | 必须 | 说明 |
| --- | --- | --- |
| `plan.json` | 是 | 包含 pipeline_id、voice 参数（可选）、speed 参数（可选） |
| `distill/script.md` | 是 | 口播稿，按 `## 第N章` / `### 步骤 N` 结构组织 |
| `distill/outline.md` | 是 | 大纲，用于步骤编号对照 |
| `skills/voice/tts-config.json` | 是 | TTS 配置：fallback_order、providers（voice_map、synthesize_template、defaults） |

## Preconditions

- `plan.json` 已存在
- `distill/script.md` 已存在
- `distill/outline.md` 已存在（用于步骤编号对照）
- 至少一个 TTS Provider 可用（步骤 3 降级链检查）

## Agent-Tool 边界

| 步骤 | 谁做 | 产物 |
| --- | --- | --- |
| Step 1-2 | Agent（创作性） | audio-segments.json |
| Step 3 | Agent（调用工具检查） | Provider 选择结果 |
| Step 4 | Agent 调用 provider 脚本（工具执行） | MP3 + SRT 文件 |
| Step 4.5 | Agent（展示 + 等确认） | 用户确认 |
| Step 5 | Agent 调用合并逻辑（工具执行） | 章节级 SRT |
| Step 6-7 | Agent（记录 + 报告） | plan.json 更新 |

## Steps

### 1. 读取计划和口播稿

从 `plan.json` 获取：

- `pipeline_id` — 用于输出目录
- `voice` 参数（如有）— 中文名称或音色 ID
- `speed` 参数（如有）— 语速倍数，默认 1.0

读取 `distill/script.md`，解析章节/步骤结构：

```markdown
## 第1章：what — 什么是冷萃？
### 步骤 1
你有没有发现...
### 步骤 2
其实原因很简单...
## 第2章：why — 为什么会这样？
### 步骤 1
原因其实很简单...
### 步骤 2
具体来说...
### 步骤 3
所以结论是...
```

**输出**：`pipeline_id`、`voice` 参数值、`speed` 参数值、解析后的章节/步骤列表。

### 2. 生成 audio-segments.json

将 script.md 转化为结构化的音频段落映射：

```json
{
  "segments": [
    {
      "id": "01-what-01",
      "chapter": "01-what",
      "chapterIndex": 1,
      "stepIndex": 1,
      "text": "你有没有发现，冷咖啡喝起来比热咖啡更苦？",
      "audioPath": "voice/public/audio/01-what/01.mp3"
    },
    {
      "id": "01-what-02",
      "chapter": "01-what",
      "chapterIndex": 1,
      "stepIndex": 2,
      "text": "其实原因很简单...",
      "audioPath": "voice/public/audio/01-what/02.mp3"
    },
    {
      "id": "02-why-01",
      "chapter": "02-why",
      "chapterIndex": 2,
      "stepIndex": 1,
      "text": "原因其实很简单...",
      "audioPath": "voice/public/audio/02-why/01.mp3"
    },
    {
      "id": "02-why-02",
      "chapter": "02-why",
      "chapterIndex": 2,
      "stepIndex": 2,
      "text": "具体来说...",
      "audioPath": "voice/public/audio/02-why/02.mp3"
    },
    {
      "id": "02-why-03",
      "chapter": "02-why",
      "chapterIndex": 2,
      "stepIndex": 3,
      "text": "所以结论是...",
      "audioPath": "voice/public/audio/02-why/03.mp3"
    }
  ]
}
```

文件路径规则：`voice/public/audio/<chapter-id>/<step>.mp3`

**输出**：`voice/audio-segments.json` 文件，包含所有章节和步骤的结构化映射。

### 3. Provider 选择与降级

#### 3a. 配置文件检查

读取 `skills/voice/tts-config.json`：

- 文件不存在 → 阻断，报告："tts-config.json 缺失，请检查 skills/voice/ 目录"
- 文件存在但 JSON 格式错误 → 阻断，报告："tts-config.json 格式错误，请修复"
- 文件存在且合法 → 提取 `fallback_order` 和 `providers` 配置，继续 3b

#### 3b. 降级链检查

遍历 `fallback_order` 数组 `["minimax", "qwen3-tts", "edge-tts", "piper-tts"]`，对每个 provider 执行其 `tts_check` 脚本：

```bash
bash scripts/tts-providers/<name>.sh tts_check
```

第一个通过检查（exit 0）的 provider 成为活跃 provider，向用户报告选定结果。

**Provider 降级表**：

| 优先级 | Provider | 类型 | 检查命令 | 降级条件 |
| --- | --- | --- | --- | --- |
| 1 | minimax | 云付费 | `mmx auth status` | auth 失败或配额耗尽 |
| 2 | qwen3-tts | 本地 GPU | `python -c "from qwen_tts import QwenTTS"` | 导入失败 |
| 3 | edge-tts | 云免费 | `uvx edge-tts --version` | 命令不存在 |
| 4 | piper-tts | 本地 CPU | `piper --version` | 命令不存在 |

**全部 Provider 不可用** → 阻断，输出 `tts-config.json` 中的 `tts_install_help` 安装指引，报告用户。

### 4. [正常路径] TTS 合成

> **dry_run 模式**：如 plan.json 中 `dry_run: true`，跳过实际合成，仅生成 audio-segments.json 并输出将要执行的命令列表（每段一行），用于验证流程正确性。

**VO-002 预检查**：在合成前，检查每步文本长度。如单句 >50 字，必须在合成前拆分为短句（以逗号、句号、分号为断点），然后分段合成后拼接为单个 MP3。这确保字幕不会过长，避免观众阅读困难。

**dry_run 输出示例**（2 章 5 步，假设选定 minimax）：

```text
[dry_run] 将执行 5 次 TTS 合成（Provider: minimax）：
  1. bash scripts/tts-providers/minimax.sh tts_synthesize "你有没有发现..." "voice/public/audio/01-what/01.mp3" "male-qn-qingse"
  2. bash scripts/tts-providers/minimax.sh tts_synthesize "其实原因很简单..." "voice/public/audio/01-what/02.mp3" "male-qn-qingse"
  3. bash scripts/tts-providers/minimax.sh tts_synthesize "原因其实很简单..." "voice/public/audio/02-why/01.mp3" "male-qn-qingse"
  4. bash scripts/tts-providers/minimax.sh tts_synthesize "具体来说..." "voice/public/audio/02-why/02.mp3" "male-qn-qingse"
  5. bash scripts/tts-providers/minimax.sh tts_synthesize "所以结论是..." "voice/public/audio/02-why/03.mp3" "male-qn-qingse"
[dry_run] 音色: male-qn-qingse, 语速: 1.0
[dry_run] 预估耗时: ~30 秒（每步 ~6 秒）
[dry_run] 输出目录: voice/public/audio/
[dry_run] 完成。实际合成请移除 dry_run 标志。
```

对每个 segment：

1. 从 `tts-config.json` 的 `providers[selected].voice_map` 中，将用户指定的音色名称映射为 voice_id（如未指定，用 `providers[selected].defaults` 中的默认值）
2. 执行 provider 脚本：

```bash
bash scripts/tts-providers/<provider>.sh tts_synthesize "<text>" "<output_path>" "<voice_id>"
```

**voice 参数解析示例**（以 minimax 为例）：

| plan.json 中的 voice 值 | 解析方式 | 结果 voice_id |
| --- | --- | --- |
| `"活力女声"` | providers.minimax.voice_map 查表 | `female-shaonv` |
| `"female-shaonv"` | 直接使用 | `female-shaonv` |
| 未指定 | providers.minimax.defaults["默认"] | `male-qn-qingse` |

**speed 参数调整**：如 plan.json 指定了 speed（如 `1.2`），传入 provider 脚本。未指定时使用 `providers[selected].defaults.speed`（默认 1.0）。

**Provider 脚本契约**（统一接口）：

| 命令 | 作用 | 返回 |
| --- | --- | --- |
| `tts_check` | 检查 provider 可用性 | exit 0 = 可用 |
| `tts_synthesize "<text>" "<output>" "<voice>"` | 合成语音 + SRT | exit 0 = 成功，生成 MP3 + SRT |

**默认语速**：120-180 字/分钟范围。如文本字数 / 预估时长超出范围，调整 speed 参数。

每步合成后验证：

- MP3 文件存在且 >0 字节
- SRT 文件存在且格式正确

**进度报告格式**（每步合成后输出）：

```text
[voice] 2/5 合成完成: 01-what/02.mp3 (3.2s, 42字) [minimax]
[voice] 3/5 合成完成: 02-why/01.mp3 (4.1s, 56字) [minimax]
```

**预估耗时**：每步 TTS 合成约 3-8 秒（取决于文本长度和 provider），SRT 合并约 1-2 秒/章。5 步 2 章的典型任务总耗时约 30-50 秒。

**[Checkpoint: VOICE_PREVIEW]** — **触发时机**：第一章全部步骤合成完成后、合并 SRT 之前。

向用户报告：

- 第一个 MP3 文件路径（用户自行试听）
- 第一个 SRT 内容（前 5 条字幕）
- 音色 ID、语速参数、使用的 Provider
- 合成耗时

**必须收到用户明确确认才可继续。** 用户可要求：调整音色 / 调整语速 / 重新合成 / 继续。提供以下选项供用户选择：继续、调整音色、调整语速、重新合成。

### 5. [正常路径] 合并 SRT

调用确定性脚本合并章节级 SRT：

```bash
bash tools/merge-srt.sh <workspace-dir>
```

脚本自动完成：

1. 读取 `voice/audio-segments.json` 获取章节结构
2. 遍历每章的步骤级 SRT
3. 计算 cumulative offset
4. 输出章节级 `<chapter>.srt`

> **注意**：edge-tts 在合成时自动生成 SRT，合并步骤逻辑与其他 provider 相同，但无需额外 SRT 生成步骤。

**不做手动计算。** 脚本失败时：

- 检查 exit code 和 stderr 输出
- 常见失败：某章节的步骤级 SRT 缺失（因合成失败跳过）→ 跳过该章节的合并，继续其他章节
- 全部章节合并失败 → 停下报告用户
- 部分成功 → 在 plan.json 中记录哪些章节合并成功、哪些跳过

### 6. 错误处理与结果汇总

错误处理策略详见 [Failure Modes](#failure-modes) 表。核心原则：

- **单步失败** → 记录到 plan.json，继续其他步骤
- **全部失败** → 停下报告用户
- **配额耗尽**（exit code 4）→ 保留已合成音频，标记未完成步骤

**结果汇总**（全部步骤完成后）：

- 成功：N 个步骤合成完成
- 失败：列出失败步骤及原因（网络超时 / 文本过长 / 音色不可用）
- 使用的 Provider 名称
- 将结果记录到 plan.json

### 7. 反模式检查

运行以下规则检查（详见 [Anti-Patterns](#anti-patterns) 表）：

- **VO-001**（critical）：MP3 文件名与 outline 步骤编号不匹配 → 重命名文件对齐
- **VO-002**（warning）：单句 >50 字 → 拆分为短句重新合成
- **VO-003**（warning）：语速超出 120-180 字/分 → 调整 speed 参数
- **VO-004**（warning）：缺少章节级 SRT → 运行合并

## Output

- `voice/audio-segments.json` — 段落映射
- `voice/public/audio/<chapter>/<step>.mp3` — 每步音频
- `voice/public/audio/<chapter>/<step>.srt` — 每步字幕
- `voice/public/audio/<chapter>.srt` — 章节级合并字幕
- `scripts/tts-providers/<provider>.sh` — provider 脚本

## Resources

| 资源 | 路径 | 用途 |
| --- | --- | --- |
| TTS 配置 | `skills/voice/tts-config.json` | fallback_order、providers（voice_map、synthesize_template、defaults） |
| Provider 脚本 | `scripts/tts-providers/<provider>.sh` | 统一的 tts_check / tts_synthesize 接口 |
| TTS 合成参考 | `references/voice/REFERENCE.md` | 音色表、语速指南、停顿标记、多音字处理 |
| SRT 合并脚本 | `tools/merge-srt.sh` | 步骤级 SRT → 章节级 SRT |
| 测试用例 | `skills/voice/test-prompts.json` | 典型 prompt 和期望输出 |

## Anti-Patterns

| ID | 名称 | 检测 | 严重度 |
| --- | --- | --- | --- |
| VO-001 | 编号错位 | MP3 文件名与 outline 步骤不匹配 | critical |
| VO-002 | 句子过长 | 单句 >50 字 | warning |
| VO-003 | 语速异常 | <120 或 >180 字/分 | warning |
| VO-004 | 缺少章节 SRT | 章节目录下无合并 SRT | warning |

## Failure Modes

| 场景 | 处理 |
| --- | --- |
| tts-config.json 缺失或格式错误 | 步骤 3a 阻断，报告用户 |
| 全部 Provider 不可用 | 步骤 3b 阻断，输出 tts_install_help 安装指引 |
| 首选 Provider 认证失败（自动降级到下一个） | 步骤 3b 自动降级到 fallback_order 中下一个 Provider |
| Qwen3-TTS GPU OOM | 降级到 edge-tts |
| edge-tts 网络不可用 | 降级到 piper-tts |
| 单步合成失败（网络超时） | 重试 1 次（retry.max_retries=1），仍失败则记录并继续 |
| 单步合成失败（配额耗尽） | exit code 4，保留已合成音频，标记未完成步骤 |
| 单步合成失败（音色不可用） | 阻断，提示用户更换音色 |
| 全部步骤失败 | 停下报告用户 |
| script.md 格式无法解析 | 阻断，要求修复 script.md 格式 |
| SRT 合并失败 | 跳过该章节，继续其他章节（见步骤 5） |
| 磁盘空间不足 | 阻断，提示用户清理空间 |

## 典型执行流程

以 test-prompts.json 中的用例 1 为例：

**输入**：`/recastory voice`，plan.json 中 voice="活力女声"，script.md 包含 1 章 2 步

**执行**：

1. 读取 plan.json → pipeline_id="rm-test-001", voice="活力女声"
2. 解析 script.md → 1 章 (01-what), 2 步
3. 生成 audio-segments.json → 2 个 segment
4. Provider 选择 → tts-config.json 合法, 降级链检查 → minimax 可用 → 选定 minimax
5. TTS 合成:
   - [voice] 1/2: 01-what/01.mp3 (3.2s) [minimax] → 验证 MP3>0, SRT 存在
   - [voice] 2/2: 01-what/02.mp3 (2.8s) [minimax] → 验证 MP3>0, SRT 存在
6. VOICE_PREVIEW → 展示 01.mp3 路径 + 前 5 条字幕 → 用户确认
7. 合并 SRT → bash tools/merge-srt.sh workspace/rm-test-001 → 01-what.srt
8. 反模式检查 → VO-001~004 全部通过
9. 结果汇总 → 2/2 成功, Provider: minimax, 记录到 plan.json

**输出**：

- `voice/audio-segments.json`
- `voice/public/audio/01-what/01.mp3` + `01.srt`
- `voice/public/audio/01-what/02.mp3` + `02.srt`
- `voice/public/audio/01-what.srt`（章节级合并）
