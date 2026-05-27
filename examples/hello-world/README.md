# Hello World — Recastory Maestro 最小可运行示例

> 一个 30 秒视频的完整 workspace 结构，用于验证流水线跑通。

## 使用方式

```bash
cd examples/hello-world
/recastory craft article.md --perspective feynman --register product
```

## 预期产出

一个 30 秒的知识讲解视频，包含：
- 3 个章节，每章 2-3 步
- Feynman 风格口播
- Product 注册表（克制、信息密度优先）
- 1080p MP4 + SRT 字幕

## workspace 结构（预期）

```
workspace/rm-hello-world/
├── raw/
│   └── article.md            # 原始文章（本目录提供）
├── distill/
│   ├── script.md             # 口播稿（AI 生成）
│   └── outline.md            # 大纲（AI 生成）
├── storyboard/
│   └── src/chapters/
│       ├── 01-what/
│       │   ├── Chapter.tsx
│       │   └── Chapter.css
│       ├── 02-how/
│       └── 03-why/
├── voice/
│   └── public/audio/
│       ├── 01-what/01.mp3
│       └── ...
├── render/
│   ├── video.mp4
│   └── subtitles.srt
├── design.md
├── plan.json
└── manifest.json
```

## 验证清单

- [ ] `script.md` 口语化，无书面语
- [ ] `outline.md` 同时参考了 script 和 article（双源）
- [ ] 第一章渲染图符合 Feynman 风格（从具体例子出发）
- [ ] TTS 音频节奏自然
- [ ] 最终视频画面与音频同步
- [ ] 无 AI 味（SL-001~SL-006 规则通过）
