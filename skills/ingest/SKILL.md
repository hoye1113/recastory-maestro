---
name: ingest
version: 1.0.0
description: 从视频 URL 一键完成下载、音频提取、转写，生成 article.md。用于在线视频导入场景（YouTube/Bilibili/Vimeo/Dailymotion）。本地文件请用 transcribe。触发词：/recastory ingest、视频 URL、"下载这个视频"。
---

# Skill: ingest

## IRON LAW

**下载-提取-转写是原子流水线。任一步骤失败，已产出的中间文件保留，但流水线立即暂停，不可跳过失败步骤继续。**

## Purpose

将视频 URL 转化为可供 distill 使用的 article.md。流水线：yt-dlp 下载视频 → FFmpeg 提取音频 → Faster-Whisper 转写 → 按停顿分段生成 article.md。

## Preconditions

- `plan.json` 已存在（由 using-recastory 生成）
- 用户提供了视频 URL（YouTube / Bilibili / Vimeo / Dailymotion）
- `yt-dlp` 已安装（`pip install yt-dlp`）
- `ffmpeg` / `ffprobe` 已安装（系统包管理器）
- `faster-whisper` 已安装（`pip install faster-whisper`）
- `tools/ingest/` 模块可用（项目内置工具）

## Agent-Tool 边界

| 步骤 | 谁做 | 产物 |
|------|------|------|
| Step 1 | Agent（验证） | URL 格式确认 |
| Step 2 | Agent 调用 CLI（工具执行） | 视频 + 音频 + article.md |
| Step 3 | Agent（验证） | 产出文件检查 |
| Step 4 | Agent（记录） | plan.json 更新 |

## Steps

### 1. 读取计划并验证输入

从 `plan.json` 获取：
- `pipeline_id` — 用于输出目录
- 输入 URL
- 可选参数：quality、model、language、device

验证 URL 格式：必须以 `http://` 或 `https://` 开头，指向支持的平台（YouTube、Bilibili、Vimeo、Dailymotion）。

**不支持的 URL** → 阻断，报告用户。

### 2. 执行导入流水线

调用确定性工具：

```bash
python -m tools.ingest "<url>" -o workspace/<pipeline_id> \
  --quality 720 \
  --model base \
  --language auto \
  --device auto
```

**CLI 参数说明**：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--quality` | 720 | 最大视频分辨率：360 / 480 / 720 / 1080 |
| `--model` | base | Whisper 模型：tiny / base / small / medium / large |
| `--language` | auto | 强制语言（如 `zh`、`en`），默认自动检测 |
| `--device` | auto | 计算设备：auto / cpu / cuda |

> **dry_run 模式**：如 plan.json 中 `dry_run: true`，跳过实际下载和转写，仅输出将要执行的命令和预期产物路径。用于验证 URL 有效性和参数合理性。
>
> dry_run 输出示例：
>
> ```text
> [dry_run] 将执行以下步骤：
>   1. yt-dlp download "https://..." → video/<title>.mp4
>   2. ffmpeg extract audio → audio/<title>.wav
>   3. faster-whisper transcribe → article.md
> [dry_run] 预估耗时: ~60 秒（取决于视频时长和网络速度）
> [dry_run] 完成。实际导入请移除 dry_run 标志。
> ```

工具自动完成 4 个步骤：
1. yt-dlp 下载视频 → `workspace/<id>/video/<title>.mp4`
2. FFmpeg 提取音频（16kHz mono WAV） → `workspace/<id>/audio/<title>.wav`
3. Faster-Whisper 转写 → segments
4. 按 >1.5s 停顿分段 → `workspace/<id>/article.md`

**article.md 输出格式**：

```markdown
# <视频标题>

段落 1（停顿间隔内的连续文本，通常 30-80 字）

段落 2（下一个停顿间隔的文本）

段落 3...
```

**格式硬性规则**：

- 一级标题（`#`）为视频标题，从 yt-dlp 元数据提取
- 每个段落对应一次语音停顿（>1.5s）间隔内的连续文本
- 段落之间用**一个空行**分隔（不可多空行）
- 保留原始转写文本，不做任何改写、润色、纠错
- 段落字数范围：通常 30-80 字（过短段落 <5 字应与相邻段落合并）
- 禁止添加说话人标签、时间戳、章节标记等非转写内容

**退出码**：0 = 成功，1 = 失败，130 = 用户中断。

### 3. 验证产出

检查以下文件：
- `workspace/<id>/article.md` 存在且 > 0 字节
- `workspace/<id>/video/` 下有视频文件
- `workspace/<id>/audio/` 下有音频文件

读取 article.md 前 200 字，确认内容非空且包含实际转写文本。

### 4. 反模式检查

| 规则 | 检测 | 修复 |
|------|------|------|
| IG-001 | URL 不匹配支持平台 | 提示用户更换 URL 或使用本地文件路径 |
| IG-002 | yt-dlp 退出码非 0 | 检查网络、URL 有效性、yt-dlp 版本 |
| IG-003 | article.md 为空或仅含 "(No content transcribed)" | 检查音频是否有效、Whisper 模型是否正确 |
| IG-004 | 视频 >60 秒但 article.md < 100 字 | 检查转写质量、尝试更大模型 |

### 5. 检查点：确认导入结果 [CHECKPOINT: INGEST_CONFIRM]

**必须暂停，等待用户明确确认后才可继续。不可自动跳过。**

向用户展示以下摘要：

```text
导入结果摘要：
- 视频标题：<title>
- 时长：<duration>
- article.md 字数：<word_count>
- 反模式检查结果：IG-001~004 状态
- 产出文件路径列表
```

**等待用户决策**：

| 用户输入 | 处理 |
| -------- | ---- |
| 确认 / 继续 / OK | 进入步骤 6 |
| 调整 / 重试 | 用不同参数（model/language/quality）重新执行步骤 2 |
| 终止 / 取消 | 保留已产出文件，更新 plan.json 状态为 aborted |

### 6. 报告结果

向用户报告：
- 视频标题 + 时长
- article.md 路径 + 字数
- 视频/音频文件路径
- 耗时

更新 plan.json：记录 article.md 路径到 `double_source.article`。

## Output

- `workspace/<id>/video/<title>.mp4` — 原始视频
- `workspace/<id>/audio/<title>.wav` — 提取的音频（16kHz mono）
- `workspace/<id>/article.md` — 转写文本（按停顿分段的 markdown）

## Resources

| 资源 | 路径 | 用途 |
| ---- | ---- | ---- |
| 转写参考 | `references/transcription/REFERENCE.md` | Whisper 参数调优 |
| 测试用例 | `skills/ingest/test-prompts.json` | 典型 prompt 和期望输出 |
| 摄取工具 | `tools/ingest/` | Python 模块（yt-dlp + FFmpeg + Whisper） |

## Anti-Patterns

步骤 4 中检测的运行时规则（详见 Failure Modes 获取恢复策略）：

| ID | 名称 | 检测方式 | 严重度 |
| -- | ---- | -------- | ------ |
| IG-001 | 无效 URL | URL 不匹配支持平台格式 | critical |
| IG-002 | 下载失败 | yt-dlp 返回非 0 退出码 | critical |
| IG-003 | 转写为空 | article.md 无实际内容 | critical |
| IG-004 | 文章过短 | 视频 >60s 但 article.md < 100 字 | warning |

## Failure Modes

前置依赖和运行时错误的恢复策略（Anti-Patterns 规则交叉引用）：

| 场景 | 检测方式 | 恢复策略 |
| ---- | -------- | -------- |
| URL 不支持（IG-001） | yt-dlp 报错 "Unsupported URL" | 阻断，提示支持平台：YouTube / Bilibili / Vimeo / Dailymotion，建议用户更换 URL 或使用 transcribe 处理本地文件 |
| yt-dlp 未安装 | `yt-dlp --version` 返回非 0 | 阻断，提示 `pip install yt-dlp`，安装后重试 |
| FFmpeg 未安装 | `ffmpeg -version` 返回非 0 | 阻断，提示系统包管理器安装（apt/brew/choco），安装后重试 |
| Whisper 未安装 | `import faster_whisper` 失败 | 阻断，提示 `pip install faster-whisper`，安装后重试 |
| 下载失败（IG-002） | yt-dlp 返回非 0 退出码 | 检查网络连接、URL 有效性、yt-dlp 版本；网络超时则重试 1 次（等待 5 秒） |
| 音频提取失败 | FFmpeg 退出码非 0 | 检查视频文件完整性，尝试不同 quality 参数重新下载 |
| CUDA OOM | Whisper 报 CUDA out of memory | 自动降级到 `--device cpu --model base`，提示用户已降级 |
| 转写为空（IG-003） | article.md 无实际内容 | 检查音频是否有效（>0 字节），尝试更大模型或指定 `--language` |
| 转写质量过低（IG-004） | >60s 视频 <100 字 | 建议用户换 larger 模型（small/medium），或指定 `--language` 强制语言 |
