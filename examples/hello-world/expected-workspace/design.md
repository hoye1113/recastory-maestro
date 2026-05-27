# Design: rm-hello-world

## 输入
- 类型：article
- 来源：examples/hello-world/article.md

## 输出
- 格式：short-video（30 秒）
- 风格：explainer
- 注册表：product（克制、信息密度优先）

## 视角
- 名称：feynman
- Expression DNA：短锚长展、中文口语化、具体到抽象、自嘲幽默
- 注入点：distill（Expression DNA）、storyboard（Mental Models）

## 流水线
- 跳过：ingest, transcribe（输入为文章）
- 并行模式：A（逐章确认）

## 双源策略
- script.md：定节拍（口播顺序 = 视觉顺序）
- article.md：定画面密度（口播跳过的细节上屏幕）

## 检查点
- DESIGN: 确认 design.md
- STORYBOARD_PREVIEW: 第一章渲染图 + 口播前 30 秒
- VOICE_PREVIEW: TTS 前 15 秒
- FINAL: 最终视频

## 反模式规则
- 启用：CD-001~CD-006, SB-001~SB-005, SL-001~SL-006, VO-001~VO-004
