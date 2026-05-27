---
name: voice
version: 1.0.0
description: 从 script.md 生成 TTS 音频（MP3）和字幕（SRT），通过 mmx-config.json 配置调用 mmx-cli。触发条件：/recastory voice 或被 using-recastory 调度。
---

# Skill: voice

## IRON LAW

**每步一个 MP3，文件名必须匹配 outline.md 步骤编号（如 `01-what/01.mp3`）。音频文件是 storyboard 和 render 的依赖，编号不可错位。**

## Purpose

将口播稿的每个步骤合成为独立音频文件，并生成对应的 SRT 字幕。

## Preconditions

- `plan.json` 已存在
- `distill/script.md` 已存在
- `distill/outline.md` 已存在（用于步骤编号对照）
- mmx-cli 已安装（不可用时步骤 3 阻断）

## Agent-Tool 边界

| 步骤 | 谁做 | 产物 |
|------|------|------|
| Step 1-2 | Agent（创作性） | audio-segments.json |
| Step 3 | Agent（调用工具检查） | mmx auth 状态 |
| Step 4 | Agent 调用 mmx-cli（工具执行） | MP3 + SRT 文件 |
| Step 4.5 | Agent（展示 + 等确认） | 用户确认 |
| Step 5 | Agent 调用合并逻辑（工具执行） | 章节级 SRT |
| Step 6-7 | Agent（记录 + 报告） | plan.json 更新 |

## Steps

### 1. 读取计划和口播稿

从 `plan.json` 获取：
- `pipeline_id` — 用于输出目录
- `voice` 参数（如有）

读取 `distill/script.md`，解析章节/步骤结构：

```
## 第1章：what — 什么是冷萃？
### 步骤 1
你有没有发现...
### 步骤 2
其实原因很简单...
```

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
    }
  ]
}
```

文件路径规则：`voice/public/audio/<chapter-id>/<step>.mp3`

### 3. 降级检查

读取 `skills/voice/mmx-config.json` 获取音色映射和参数模板。

运行 mmx-config.json 中的 `auth_check` 命令（10 秒超时）：

**可用**（exit 0）→ 继续步骤 4
**不可用**（exit 非 0 / 命令不存在 / 超时）→ 停下，报告用户："mmx-cli 不可用，请安装或配置后重试"。不继续执行后续步骤。

### 4. [正常路径] TTS 合成

对每个 segment：
1. 读取 mmx-config.json 的 `voice_map`，将用户指定的音色名称映射为 voice_id（如未指定，用 `defaults` 中的默认值）
2. 用 `synthesize_template` 填充参数：text、voice_id、output_path
3. 执行填充后的命令

**mmx-cli 函数契约**（Provider-agnostic）：

| 函数 | 作用 | 返回 |
|------|------|------|
| `auth()` | 检查认证状态 | `boolean` |
| `voices()` | 列出中文音色 | `Voice[]`（id, name, language） |
| `synthesize(text, voice, outputPath, options?)` | 合成语音 + SRT | `{ mp3Path, srtPath }` |

**默认语速**：120-180 字/分钟范围。如文本字数 / 预估时长超出范围，调整 `--speed` 参数。

每步合成后验证：
- MP3 文件存在且 >0 字节
- SRT 文件存在且格式正确

**[Checkpoint: VOICE_PREVIEW]** — 第一章全部步骤合成完成后，向用户报告：
- 第一个 MP3 文件路径（用户自行试听）
- 第一个 SRT 内容（前 5 条字幕）
- 音色 ID、语速参数
- 合成耗时

**必须收到用户确认才可继续合并 SRT。** 用户可要求：调整音色 / 调整语速 / 重新合成 / 继续。

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

**不做手动计算。** 脚本失败时停下报告用户。

### 6. 失败处理

mmx-cli 不可用已在步骤 3 阻断。单步合成失败时：
- 记录失败步骤及原因到 plan.json
- 继续合成其他步骤
- 全部失败时停下报告用户

### 7. 报告异常

汇总合成结果：
- 成功：N 个步骤合成完成
- 失败：列出失败步骤及原因（网络超时 / 文本过长 / 音色不可用）
- 失败：记录到 plan.json

### 8. 反模式检查

| 规则 | 检测 | 修复 |
|------|------|------|
| VO-001 | MP3 文件名与 outline 步骤编号不匹配 | 重命名文件对齐 |
| VO-002 | 单句 >50 字 | 拆分为短句重新合成 |
| VO-003 | 语速超出 120-180 字/分 | 调整 --speed 参数 |
| VO-004 | 缺少章节级 SRT | 运行合并 |

## Output

- `voice/audio-segments.json` — 段落映射
- `voice/public/audio/<chapter>/<step>.mp3` — 每步音频
- `voice/public/audio/<chapter>/<step>.srt` — 每步字幕
- `voice/public/audio/<chapter>.srt` — 章节级合并字幕

## Anti-Patterns

| ID | 名称 | 检测 | 严重度 |
|----|------|------|--------|
| VO-001 | 编号错位 | MP3 文件名与 outline 步骤不匹配 | critical |
| VO-002 | 句子过长 | 单句 >50 字 | warning |
| VO-003 | 语速异常 | <120 或 >180 字/分 | warning |
| VO-004 | 缺少章节 SRT | 章节目录下无合并 SRT | warning |

## Failure Modes

| 场景 | 处理 |
|------|------|
| mmx-cli 未安装 | 步骤 3 阻断，报告用户 |
| mmx auth 失败 | 步骤 3 阻断，报告用户 |
| 单步合成失败 | 记录错误，继续其他步骤 |
| 全部步骤失败 | 停下报告用户 |
| script.md 格式无法解析 | 阻断，要求修复 script.md 格式 |
