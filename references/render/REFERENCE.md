# references/render/REFERENCE.md — 渲染参考

> render SKILL.md 执行时加载本文件。提供编码参数、录制模式、TTS 契约。

---

## 输出规格
| 参数 | 值 |
|---|---|
| 分辨率 | 1920x1080（浏览器全屏） |
| 帧率 | 60fps（OBS 设置） |
| 编码 | H.264, CRF 18–23 |
| 最终格式 | MP4 |
---
## 字幕同步 + 音画对齐
| 要求 | 值 |
|---|---|
| Auto 推进 | 音频播完 + 200ms 缓冲 → next() |
| 无音频退化 | `max(1500ms, 字数 x 250ms)` |
| 字幕偏差 | ≤0.5s |
| 语速范围 | 120–180 字/分 |
| 单句上限 | ≤50 字 |
---
## 三种录制模式
| URL / 快捷键 | 模式 | 行为 |
|---|---|---|
| 直接打开（默认） | Manual | 点击/方向键推进，不播音频 |
| `?audio=1` 或 `M` | Audio | 自动播音频，手动推进 |
| `?auto=1` / 再按 `M` | Auto | 自动播 + 自动推进（录制用） |
Auto 首次按 `Space` 启动。录屏：全屏 → 录制 → Space → 一镜到底 → 裁头尾。
| 平台 | 工具 | 设置 |
|---|---|---|
| macOS | Cmd+Shift+5 / QuickTime | 浏览器窗口，1920x1080 |
| 跨平台 | OBS Studio | 窗口捕获，1920x1080，60fps |
---
## TTS Provider 契约

<!-- P1 预留：抽象 shell 接口，P0 直接使用下方 mmx-cli 契约 -->

`scripts/tts-providers/<name>.sh` 三函数：
| 函数 | 必需 | 作用 |
|---|---|---|
| `tts_synthesize <text> <out> [<voice>]` | Yes | 文字 → mp3 |
| `tts_check` | No | 校验环境，未就绪 return 非零 |
| `tts_install_help` | No | 打印修复说明 |
### Recastory mmx-cli 契约
| 函数 | 返回 |
|---|---|
| `auth()` | `boolean` |
| `voices()` | `Voice[]`（id, name, language） |
| `synthesize(text, voice, outputPath, options?)` | `{ mp3Path, srtPath }` |
```
auth_check: "mmx auth status"
command:    "mmx speech synthesize --text {{text}} --voice {{voice_id}} --out {{output_path}} --subtitles true"
```
### 内置 Provider
| Provider | 默认 | 何时用 |
|---|---|---|
| `minimax` | Yes | 中文首选（mmx-cli） |
| `openai` | No | 已有 OPENAI_API_KEY |
OpenAI env：`OPENAI_API_KEY`（必须）、`OPENAI_BASE_URL`（代理）、`OPENAI_TTS_MODEL`（tts-1/tts-1-hd）、`--voice=`（alloy/echo/fable/onyx/nova/shimmer）
### 音色映射
| 名称 | voice_id |
|---|---|
| 沉稳男声 | male-qn-qingse |
| 活力女声 | female-shaonv |
| 专业播音 | presenter_male |
| 默认 | male-qn-qingse |
---
## 音频文件命名
```
voice/public/audio/<chapter-id>/<step>.mp3       # 1-indexed
voice/public/audio/<chapter-id>/<step>.srt       # 每步字幕
voice/public/audio/<chapter-id>.srt              # 章节合并字幕
presentation/public/audio/<chapter-id>/<step>.mp3  # web-video-presentation
```
---
## 文件大小控制
| 限制 | 值 |
|---|---|
| mmx 单段上限 | ~5000 字符（超长需拆 step） |
| 预估时长异常 | ≥15s 条目需审查 |
| 短视频总大小 | ≤500MB |
---
## 反模式速查
| ID | 名称 | 检测 | 严重度 |
|---|---|---|---|
| RD-001 | 编号错位 | MP3 文件名与 outline 步骤不匹配 | critical |
| RD-002 | 句子过长 | 单句 >50 字 | warning |
| RD-003 | 语速异常 | <120 或 >180 字/分 | warning |
| RD-004 | 缺少章节 SRT | 章节目录下无合并 SRT | warning |
