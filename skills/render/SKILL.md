---
name: render
version: 1.0.0
description: 将 storyboard 幻灯片和 voice 音频合成为最终 MP4 视频，含录屏、字幕烧录、章节拼接、可选 BGM。用于流水线最后一步渲染。触发词：/recastory render、"合成视频"、"渲染最终视频"。
---

> Darwin Skill: 88.8/100 (baseline 85 → optimized 2026-05-30)

# Skill: render

## IRON LAW

**音画同步是底线。章节目录时长与录屏时长偏差不得超过 0.5 秒。MP3 编号必须与 outline 步骤编号完全匹配。**

## Purpose

将 storyboard 幻灯片项目和 voice 音频合成为最终 MP4 视频。流水线：合并步骤级 MP3 → 启动 Vite 开发服务器 → CDP Screencast 录屏 + FFmpeg 编码 → 烧录口播字幕 → 拼接章节视频 → 可选 BGM 混音。

## Preconditions

- `plan.json` 已存在
- `storyboard/` 目录存在（Vite+React+TS 项目）
- `voice/audio-segments.json` 存在（章节/步骤结构）
- `voice/public/audio/<chapter>.mp3` 存在（步骤级 MP3 已由 voice Skill 合成）
- `voice/public/audio/<chapter>.srt` 存在（步骤级 SRT 已由 voice Skill 生成）
- `ffmpeg` / `ffprobe` 已安装
- `node` 已安装（Puppeteer 需要）
- `npx vite` 可用
- `tools/render-video.sh`、`tools/merge-mp3.sh`、`tools/mix-bgm.sh` 脚本可用（项目内置工具）
- `scripts/tts-providers/` 目录存在（voice Skill 的 provider 脚本）

## Agent-Tool 边界

| 步骤 | 谁做 | 产物 |
|------|------|------|
| Step 1 | Agent（验证） | 前置文件确认 |
| Step 2 | Agent 调用 bash 脚本（工具执行） | 合并 MP3 + 录屏 + 字幕烧录 + 拼接 |
| Step 3 | Agent（可选） | BGM 混音 |
| Step 4 | Agent（验证） | final.mp4 + manifest.json 确认 |
| Step 5 | Agent（报告） | plan.json 更新 |

## Steps

### 1. 验证前置文件

检查以下文件/目录存在：

```
workspace/<id>/
├── storyboard/              ← Vite 项目
├── voice/
│   ├── audio-segments.json  ← 步骤结构
│   └── public/audio/
│       ├── 01-intro/01.mp3  ← 步骤级 MP3
│       ├── 01-intro/01.srt  ← 步骤级 SRT
│       └── ...
```

任一关键文件缺失 → 阻断，报告用户缺少哪个前置产出。

### 2. 执行渲染流水线

调用确定性工具：

```bash
bash tools/render-video.sh workspace/<pipeline_id> \
  --resolution 1920x1080 \
  --fps 30 \
  --codec h264
```

**CLI 参数说明**：

| 参数 | 默认值 | 说明 |
| ---- | ------ | ---- |
| `--resolution` | 1920x1080 | 输出分辨率：1280x720 / 1920x1080 |
| `--fps` | 30 | 录屏帧率：24 / 30 / 60 |
| `--codec` | h264 | 视频编码：h264 / h265 |

工具自动完成以下步骤：

1. **合并步骤级 MP3**（merge-mp3.sh）：将 `01.mp3` + `02.mp3` + ... 合并为 `<chapter>.mp3`
2. **启动 Vite 开发服务器**：`npx vite --port 5173`，等待 30 秒超时
3. **逐章录屏**：
   - CDP Screencast 浏览器内录（`tools/capture-chrome.js`）：
     - Puppeteer 启动 Chromium，打开 `http://127.0.0.1:<port>/?chapter=<id>`
     - CDP `Page.startScreencast` 捕获 compositor 帧（JPEG）
     - `ffprobe` 预读 MP3 时长，`setTimeout` + `dispatchEvent` 驱动翻页
     - 不在浏览器内播放 MP3（规避 Chrome autoplay policy）
     - 事后 FFmpeg 混流：无声视频 + 原始 MP3 → 最终 MP4
4. **烧录口播字幕**：将章节级 SRT 烧入录屏视频底部（口播旁白文字，与 PPT 画面文字互补）
5. **拼接章节视频**：FFmpeg concat demuxer 拼接所有章节为 final.mp4
6. **生成 manifest.json**：pipeline_id、created_at、output 路径、duration、resolution

**预期中间产物**（用于验证子步骤是否成功）：

| 子步骤 | 产物路径 | 验证方式 |
|--------|---------|---------|
| 合并 MP3 | `voice/public/audio/<chapter>.mp3` | 文件存在且时长 = 各步骤 MP3 之和 |
| 录屏 | `render/<chapter>.mp4` | 文件存在且时长 > 0 |
| 字幕烧录 | `render/<chapter>.mp4` | 底部可见口播字幕 |
| 拼接 | `render/final.mp4` | 文件存在且时长 = 各章之和 |

**环境变量**（可选）：

| 变量 | 默认值 | 说明 |
| ---- | ------ | ---- |
| `ENABLE_BGM` | false | 是否启用 BGM 混音 |
| `BGM_PROMPT` | （空） | BGM 风格描述，如 "轻快的电子音乐" |
| `BGM_VOLUME` | 0.2 | BGM 音量（0-1） |
| `VITE_PORT` | 5173 | Vite 开发服务器端口 |
| `VITE_TIMEOUT` | 30 | Vite 启动超时（秒） |
| `RECORD_BUFFER` | 3 | 录屏缓冲时长（秒），录制时长 = 音频时长 + 此值 |

### 2.5 平台输出优化（可选）

渲染完成后，可为目标平台生成优化版本：

| 平台 | 分辨率 | CRF | 音频 | 特殊要求 |
|------|--------|-----|------|---------|
| B站 | 1920x1080 | 18-20 | AAC 192k | `--movflags faststart` |
| YouTube | 1920x1080 | 18 | AAC 192k 48kHz | profile high, level 4.0 |
| 抖音/TikTok | 1080x1920 | 20 | AAC 128k | 竖屏，max 10min |
| Twitter/X | 1280x720 | 24 | AAC 128k | max 140s, 512MB |
| Web 嵌入 | 1280x720 | 26 | AAC 128k | baseline profile |

**命令示例**（B站优化）：

```bash
ffmpeg -i render/final.mp4 -c:v libx264 -crf 20 -preset medium \
  -c:a aac -b:a 192k -movflags faststart render/final-bilibili.mp4
```

**硬件加速**（可选，显著提升编码速度）：

| 平台 | 编码器 | 用法 |
|------|--------|------|
| NVIDIA GPU | h264_nvenc | `-c:v h264_nvenc -preset p5` |
| macOS | h264_videotoolbox | `-c:v h264_videotoolbox -b:v 8M` |
| Intel QSV | h264_qsv | `-c:v h264_qsv -preset medium` |

### 3. 可选 BGM 混音

如 `ENABLE_BGM=true`，工具自动调用 `mix-bgm.sh`：

1. 读取 `plan.json` 推导 BGM 风格（或使用 `BGM_PROMPT`）
2. 调用 `mmx music generate` 生成 BGM
3. FFmpeg `amix` 将 BGM 与视频音频混合
4. 3 秒淡入淡出
5. 输出 `render/final-with-bgm.mp4`

BGM 混音失败时不阻断流水线，降级使用无 BGM 版本。

### 4. 验证产出

检查：
- `render/final.mp4` 存在且 > 0 字节
- `manifest.json` 存在且包含有效 duration
- 如启用 BGM：`render/final-with-bgm.mp4` 存在

读取 manifest.json，报告视频时长和分辨率。

### 5. 检查点：确认渲染结果 [CHECKPOINT: RENDER_CONFIRM]

**必须暂停，等待用户明确确认后才可继续。不可自动跳过。**

向用户展示渲染结果摘要：

```text
渲染结果摘要：
- 输出文件：render/final.mp4
- 视频时长：<duration>
- 分辨率：<resolution>
- 章节数：<chapter_count>
- BGM 状态：<enabled/disabled/failed>
- 音画同步偏差：<0.5s（IRON LAW 要求）
```

**等待用户决策**：

| 用户输入 | 处理 |
| -------- | ---- |
| 确认 / 继续 / OK | 进入报告步骤 |
| 重新渲染 | 用调整后的参数重新执行步骤 2 |
| 调整 BGM | 修改 BGM_PROMPT/BGM_VOLUME，重新执行步骤 3 |
| 同步偏差 > 0.5s | 阻断，检查录屏和音频对齐，修复后重跑 |

### 6. 反模式检查

| 规则 | 检测 | 修复 |
|------|------|------|
| RR-001 | MP3 文件名与 outline 步骤编号不匹配 | 重命名文件对齐 |
| RR-002 | SRT 单句 >50 字 | 拆分短句重新合成 |
| RR-003 | 语速 <120 或 >180 字/分 | 调整 TTS --speed 参数 |
| RR-004 | 章节目录下缺少合并 SRT | 运行 merge-srt.sh |

### 7. 报告结果

向用户报告：
- final.mp4 路径 + 大小
- 视频时长 + 分辨率
- 章节数量
- BGM 状态（启用/禁用/失败）
- manifest.json 路径

## Output

- `render/final.mp4` — 最终视频（1920x1080，H.264）
- `render/<chapter>.mp4` — 章节级视频（含字幕）
- `manifest.json` — 流水线元数据
- `render/final-with-bgm.mp4` — 含 BGM 版本（可选）
- `render/bgm.mp3` — 生成的 BGM（可选）

## Anti-Patterns

步骤 6 中检测的运行时规则（详见 Failure Modes 获取恢复策略）：

| ID | 名称 | 检测方式 | 严重度 |
| -- | ---- | -------- | ------ |
| RR-001 | 编号不匹配 | MP3 文件名与 outline 步骤不一致 | critical |
| RR-002 | 字幕句子过长 | SRT 单句 >50 字 | warning |
| RR-003 | 语速异常 | <120 或 >180 字/分 | warning |
| RR-004 | 缺少章节 SRT | 章节目录下无合并 SRT 文件 | warning |

## Failure Modes

前置依赖和运行时错误的恢复策略（Anti-Patterns 规则交叉引用）：

| 场景 | 检测方式 | 恢复策略 |
| ---- | -------- | -------- |
| storyboard/ 缺失 | 目录不存在 | 阻断，提示先运行 storyboard Skill |
| audio-segments.json 缺失 | 文件不存在 | 阻断，提示先运行 voice Skill |
| FFmpeg 未安装 | `ffmpeg -version` 返回非 0 | 阻断，提示系统包管理器安装（apt/brew/choco） |
| Vite 启动超时 | 30 秒内未响应 `http://127.0.0.1:<port>` | 阻断，检查 storyboard 项目是否完整，运行 `npm install` |
| Puppeteer 失败 | Chromium 启动报错 | 阻断，检查 node 版本（>=18）和 Puppeteer 安装 |
| 录屏失败（单章） | capture-chrome.js 退出码非 0 | 跳过该章，继续其他章节，最后在报告中标注 |
| 浏览器崩溃 | GPU 加速不稳定 | 添加 `--disable-gpu --no-zygote` 等稳定性 flags |
| BGM 生成失败 | mmx music 返回错误 | 降级到无 BGM 版本，不阻断 |
| 音画同步偏差 > 0.5s | manifest.json 中 duration 偏差 | 阻断（IRON LAW），检查录屏和音频对齐 |

## 踩坑参考

渲染相关的历史踩坑记录见 [docs/pitfalls.md](../../docs/pitfalls.md)，关键条目：

- **ffmpeg force_style 多参数失效** — Windows 上逗号被解析为 filter separator，用 ASS override tags 替代
- **ASS 对齐编号** — `\an2`=底部，`\an8`=顶部（键盘布局，非直觉）
- **字幕烧录是破坏性操作** — 录制后先备份到 `render/clean/` 再烧录
- **静态页帧率低** — CSS 动画驱动合成器推帧
