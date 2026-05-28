# A-003: render-video.sh Missing puppeteer-launch.js Validation

## Metadata
- Iteration: 1
- Track: A
- Severity: warning
- Created: 2026-05-29

## Problem

`tools/render-video.sh` line 130 调用 `node "$SCRIPT_DIR/puppeteer-launch.js"` 但未检查该文件是否存在。其他依赖（ffmpeg, ffprobe）在脚本开头有检查，唯独 puppeteer-launch.js 没有。

## Root Cause

puppeteer-launch.js 是后添加的功能，遗漏了前置检查。

## Affected Files

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| tools/render-video.sh | modify | 添加 puppeteer-launch.js 存在检查 |

## Fix Strategy

在脚本开头的依赖检查区域（ffmpeg/ffprobe 检查附近）添加：

```bash
# Check puppeteer-launch.js exists
if [ ! -f "$SCRIPT_DIR/puppeteer-launch.js" ]; then
    log_error "puppeteer-launch.js not found in $SCRIPT_DIR"
    exit 1
fi
```

## Acceptance Criteria

- [ ] 脚本开头检查 puppeteer-launch.js 存在
- [ ] 不存在时输出明确错误并 exit 1
- [ ] bash -n 语法检查通过

## Review Checklist

- [ ] Spec Compliance: 仅在依赖检查区域添加
- [ ] Code Quality: bash -n 通过
- [ ] Runtime Neutrality: 无平台锁定

## Regression Risk

极低。仅添加前置检查，不改变已有逻辑。
