# Legacy Code Cleanup Spec

## Metadata

- Iteration: 8
- Track: v3.1.0 cleanup
- Created: 2026-05-30

## Context

CDP screencast 迁移已完成（capture-chrome.js + render-video.sh），但多个文件仍残留 gdigrab/sentinel/focus/Puppeteer 录屏相关内容，需清理防止团队误读。

## Changes

### 更新（2 个文件）

| 文件 | 修改内容 |
|------|---------|
| `README.md` | "Puppeteer 录屏 + FFmpeg 编码" → "CDP Screencast 录屏 + FFmpeg 编码" |
| `WORKFLOW.md` | L263: "Puppeteer 打开浏览器 + 按 SPACE 启动自动播放" → "CDP Screencast 浏览器内录，自动播放驱动帧推送" |

### 标记过时（2 个文件）

| 文件 | 操作 |
|------|------|
| `specs/render-pipeline-fixes.md` | 顶部加 `> **OBSOLETE**: 本文档 §1-8 记录的 FFmpeg gdigrab 方案已被 CDP screencast 替代。§9 为当前方案。` |
| `docs/superpowers/plans/2026-05-28-render-skill.md` | 顶部加 `> **OBSOLETE**: 本计划基于 FFmpeg gdigrab 方案，已被 CDP screencast 替代。` |

### 不动（确认保留）

| 文件 | 原因 |
|------|------|
| `tools/puppeteer-launch.js` | 截图工具仍在用（capture-screenshots.sh） |
| `skills/render/SKILL.md` | Puppeteer 引用是正确的（capture-chrome.js 确实用 Puppeteer 启动 Chrome） |
| `references/render/REFERENCE.md` | 已是 CDP 描述，无需修改 |

## Acceptance Criteria

- [ ] README.md 不含 "Puppeteer 录屏"
- [ ] WORKFLOW.md L263 更新为 CDP 描述
- [ ] 2 个过时文件顶部有 OBSOLETE 标记
