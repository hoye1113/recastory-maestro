---
name: transcribe
version: 1.0.0
description: 将本地音频或视频文件转写为 article.md，支持多语言和多模型。用于已有本地文件的场景。在线视频请用 ingest。触发词：/recastory transcribe、"转写这个"、"识别语音"。
---

# Skill: transcribe

## IRON LAW

**转写精度是整个流水线的地基。地基不稳则后续 distill、storyboard、voice 全部坍塌。宁可慢一点用大模型，也不用垃圾转写敷衍。**

## Purpose

将本地音频文件（或视频中提取的音频）转写为结构化 article.md，供 distill 阶段使用。独立于 ingest，适用于已有本地文件的场景。

## Preconditions

- `plan.json` 已存在（由 using-recastory 生成）
- 输入文件存在：音频文件（.wav/.mp3/.m4a）或视频文件（.mp4/.mov/.avi/.mkv）
- `faster-whisper` 已安装（`pip install faster-whisper`）
- `ffmpeg` 已安装（如输入为视频，需提取音频）
- `tools/ingest/transcriber.py` 模块可用（项目内置工具）

## Agent-Tool 边界

| 步骤 | 谁做 | 产物 |
| ---- | ---- | ---- |
| Step 1 | Agent（读取计划） | 输入路径确认 |
| Step 2 | Agent 调用 FFmpeg（如需） | 音频文件 |
| Step 3 | Agent 调用 Python（工具执行） | 转写 segments |
| Step 4 | Agent（质量门控） | TR-001~005 检查结果 |
| Step 5 | Agent（生成） | article.md |
| Step 6 | Agent（报告） | plan.json 更新 |

## Steps

### 1. 读取计划并确认输入

从 `plan.json` 获取：

- `pipeline_id` — 用于输出目录
- 输入文件路径
- 可选参数：model、language、device

判断输入类型：

- 音频文件（.wav/.mp3/.m4a）→ 直接进入步骤 3
- 视频文件（.mp4/.mov/.avi/.mkv）→ 进入步骤 2 提取音频

### 2. 提取音频（如输入为视频）

```bash
ffmpeg -i "<video-path>" -vn -acodec pcm_s16le -ar 16000 -ac 1 \
  workspace/<pipeline_id>/transcribe/audio.wav
```

参数说明：16kHz mono WAV（Whisper 最佳输入格式）。

### 3. 执行转写

调用 faster-whisper 转写：

```python
from tools.ingest.transcriber import transcribe_audio

result = transcribe_audio(
    "<audio-path>",
    model_size="base",      # tiny/base/small/medium/large
    language=None,           # None=自动检测, "zh"/"en"=强制
    device="auto",           # auto/cpu/cuda
)
```

**模型选择建议**：

| 模型 | 速度 | 精度 | 适用场景 |
| ---- | ---- | ---- | ------- |
| tiny | 最快 | 低 | 快速预览 |
| base | 快 | 中 | 默认选择 |
| small | 中 | 较高 | 重要内容 |
| medium | 慢 | 高 | 专业内容 |
| large | 最慢 | 最高 | 最终交付 |

### 4. 质量门控

对转写结果运行 TR-001~005 规则检查：

```bash
python -m tools.audit workspace/<pipeline_id>/transcribe/ --rule TR-001,TR-002,TR-003,TR-004,TR-005
```

| 规则 | 检测 | 严重度 |
| ---- | ---- | ------ |
| TR-001 | 连续 3+ 无标点长句（>50 字） | warning |
| TR-002 | 说话人标签格式不统一 | warning |
| TR-003 | SRT 时间戳不连续或重叠 | critical |
| TR-004 | 填充词密度 >5% | warning |
| TR-005 | 中英文标点混用 | warning |

**Critical（TR-003）** → 阻断，必须修复后继续。
**Warning** → 记录，继续执行。

### 5. 检查点：确认转写质量 [CHECKPOINT: TRANSCRIBE_CONFIRM]

**必须暂停，等待用户明确确认后才可继续生成 article.md。不可自动跳过。**

向用户展示质量检查结果：

```text
转写质量摘要：
- 检测语言：<language>
- 模型：<model_size>
- TR-001 连续长句：N 处（warning）
- TR-002 标签不统一：N 处（warning）
- TR-003 时间戳重叠：N 处（critical）
- TR-004 填充词密度：X%
- TR-005 标点混用：N 处（warning）
```

**等待用户决策**：

| 用户输入 | 处理 |
| -------- | ---- |
| 确认 / 继续 / OK | 进入步骤 6 生成 article.md |
| 重试 / 换模型 | 用更大模型（small/medium/large）重新执行步骤 3 |
| 指定语言 | 用 `--language` 参数重新执行步骤 3 |
| 终止 / 取消 | 保留 segments 文件，更新 plan.json 状态为 aborted |

### 6. 生成 article.md

将转写 segments 按 >1.5s 停顿分段，生成 markdown：

```python
from tools.ingest.transcriber import segments_to_article

article = segments_to_article(result.segments, title="转写文本")
```

写入 `workspace/<pipeline_id>/article.md`。

**article.md 格式**：

```markdown
# <标题>

段落 1（停顿间隔内的连续文本，通常 30-80 字）

段落 2（下一个停顿间隔的文本）

段落 3...
```

**格式硬性规则**：

- 一级标题（`#`）为文件名或用户指定标题
- 每个段落对应一次语音停顿（>1.5s）间隔内的连续文本
- 段落之间用**一个空行**分隔（不可多空行）
- 保留原始转写文本，不做任何改写、润色、纠错
- 段落字数范围：通常 30-80 字（过短段落 <5 字应与相邻段落合并）
- 禁止添加说话人标签、时间戳、章节标记等非转写内容

### 7. 反模式检查

| 规则 | 检测 | 修复 |
| ---- | ---- | ---- |
| TR-001 | 连续无标点长句 | 添加标点、拆分长句 |
| TR-002 | 说话人标签不统一 | 统一为 `[说话人]` 格式 |
| TR-003 | 时间戳重叠 | 修复时间戳 |
| TR-004 | 填充词过多 | 清理填充词（嗯/啊/呃/那个） |
| TR-005 | 标点混用 | 统一为中文标点 |

### 8. 报告结果

向用户报告：

- 转写语言（自动检测结果）
- 模型大小 + 耗时
- article.md 路径 + 字数
- TR 规则检查结果

更新 plan.json：记录 article.md 路径到 `double_source.article`。

## Output

- `workspace/<id>/article.md` — 转写文本（按停顿分段）
- `workspace/<id>/transcribe/audio.wav` — 提取的音频（如从视频提取）
- `workspace/<id>/transcribe/transcript.json` — 原始转写 segments（可选）

## Anti-Patterns

步骤 4 中检测的运行时规则（详见 Failure Modes 获取恢复策略）：

| ID | 名称 | 检测方式 | 严重度 |
| -- | ---- | -------- | ------ |
| TR-001 | 连续无标点长句 | 3+ 行 >50 字无句号 | warning |
| TR-002 | 标签格式不统一 | 混用 `[speaker]` 和 `speaker：` | warning |
| TR-003 | 时间戳不连续 | SRT 间隔 >1s 或重叠 | critical |
| TR-004 | 填充词过多 | 密度 >5% | warning |
| TR-005 | 标点混用 | 中英文标点共存 | warning |

## Failure Modes

前置依赖和运行时错误的恢复策略（Anti-Patterns 规则交叉引用）：

| 场景 | 检测方式 | 恢复策略 |
| ---- | -------- | -------- |
| faster-whisper 未安装 | `import faster_whisper` 失败 | 阻断，提示 `pip install faster-whisper`，安装后重试 |
| FFmpeg 未安装 | `ffmpeg -version` 返回非 0 | 阻断，提示系统包管理器安装（apt/brew/choco），安装后重试 |
| CUDA OOM | Whisper 报 CUDA out of memory | 自动降级到 `--device cpu --model base`，提示用户已降级 |
| 音频无语音内容 | article.md 为空或仅含噪音 | 阻断，提示用户检查输入文件是否包含人声 |
| 语言检测错误 | 转写结果语言与预期不符 | 用 `--language` 参数强制指定（如 `zh`、`en`），重新转写 |
| 音频文件损坏 | FFmpeg 解码报错 | 阻断，提示用户检查源文件完整性，尝试重新获取 |
| 音频时长过短 | <1 秒 | 阻断，提示输入文件可能为空或截断 |
| TR-003 时间戳重叠 | 审计工具检测 | 阻断，检查 SRT 源文件，修复后重跑 |
