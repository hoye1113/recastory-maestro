# Render Pipeline Fixes - Specs Document

> **OBSOLETE**: 本文档 §1-8 记录的 FFmpeg gdigrab 方案已被 CDP screencast 替代。§9-10 为当前方案。

> 记录渲染流水线的所有修复和经验教训

---

## 1. 字幕问题

### 1.1 字幕字体大小

**问题**：FontSize=24 太大，遮挡画面内容

**修复**：FontSize=18，MarginV=30（底部边距）

```bash
-filter_complex "subtitles=filename=${srt_copy}:force_style='FontSize=18,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2,MarginV=30'"
```

### 1.2 字幕长度超限

**问题**：VOICE SKILL.md 规定单句 >50 字需拆分，但实际有大量超长字幕（最长 170 字）

**检测命令**：
```bash
for srt in workspace/*/voice/public/audio/*/*.srt; do
  while IFS= read -r line; do
    if [[ ! "$line" =~ ^[0-9]+$ ]] && [[ ! "$line" =~ ^[0-9]{2}: ]] && [[ -n "$line" ]]; then
      len=${#line}
      if [ "$len" -gt 50 ]; then
        echo "[$len字] $srt: $line"
      fi
    fi
  done < "$srt"
done
```

**修复方案**：
1. 在 voice Skill 的 TTS 合成前拆分长句（推荐）
2. 或在 merge-srt.sh 后处理拆分（不推荐，会丢失音频同步）

---

## 2. 浏览器焦点问题

### 2.1 页面切换后失去焦点

**问题**：Puppeteer 点击"下一页"后，浏览器可能失去焦点，FFmpeg 录到 IDE

**根因**：`bringToForeground()` 只在初始启动时调用，页面切换后未重新激活

**修复**：在 puppeteer-launch.js 的 auto-play 循环中，每次步骤切换后重新调用 `bringToForeground()`

### 2.2 Win32 API 调用 (AttachThreadInput 方案)

**关键发现**：Windows 限制了后台进程调用 `SetForegroundWindow` 的权限。必须使用 `AttachThreadInput` 将当前线程附加到前台窗口的线程，才能成功切换焦点。

```javascript
// 使用 AttachThreadInput 绕过 SetForegroundWindow 限制
// 写入临时 PS1 文件（比每次内联执行更快）
const psScript = `
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Win32 {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
}
'@
$procs = Get-Process -Name msedge,chrome -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }
foreach ($p in $procs) {
  $h = $p.MainWindowHandle
  $fg = [Win32]::GetForegroundWindow()
  $fgThread = [Win32]::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
  $myThread = [Win32]::GetCurrentThreadId()
  [Win32]::AttachThreadInput($myThread, $fgThread, $true) | Out-Null
  [Win32]::ShowWindow($h, 9) | Out-Null
  [Win32]::SetForegroundWindow($h) | Out-Null
  [Win32]::AttachThreadInput($myThread, $fgThread, $false) | Out-Null
}
`
execSync(`powershell -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}"`, { stdio: 'pipe', timeout: 3000 })
```

### 2.3 页面切换后焦点丢失

**问题**：Puppeteer 自动播放过程中，页面切换（如从一页跳到下一页）时，浏览器可能失去焦点，FFmpeg 录到 IDE 或其他窗口

**根因**：`bringToForeground()` 只在初始启动时调用，自动播放循环中未重新激活

**修复 1**：在 auto-play 循环中，每次步骤切换时重新调用 `bringToForeground()`

```javascript
// 在 auto-play 轮询循环中
if (currentStep === '100%') {
  stableCount++
} else {
  bringToForeground()
  stableCount = 0
}
```

**修复 2**：使用 `setInterval` 每 2 秒周期性激活浏览器前台（比仅在步骤切换时更可靠）

```javascript
// 启动后立即开始周期性前台激活
const fgInterval = setInterval(() => bringToForeground(), 2000)

// 浏览器关闭时清理
clearInterval(fgInterval)
```

**修复 3**：使用 `AttachThreadInput` 替代纯 `SetForegroundWindow`（绕过 Windows 后台进程限制）

### 2.4 验证流程

**问题**：无法确认录制内容是否正确（焦点丢失导致录到 IDE）

**修复**：添加 `verify-render.sh` 脚本，从最终视频中提取截图，使用 mmx MCP 读取验证

```bash
# 提取 5 张均匀分布的截图
bash tools/verify-render.sh workspace/<id> 5

# 使用 mmx MCP 读取截图验证内容
mcp__MiniMax__understand_image --image workspace/<id>/render/verify/screenshot-00-5s.jpg
```

---

## 3. 录制窗口问题

### 3.1 分辨率检测

**问题**：硬编码 1920x1080 导致只录到左上角

**修复**：动态检测屏幕分辨率

```bash
# Windows
powershell -NoProfile -Command 'Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::PrimaryScreen.Bounds | ForEach-Object { "$($_.Width)x$($_.Height)" }'

# Linux
xrandr | grep ' connected' | grep -o '[0-9]*x[0-9]*' | head -1
```

### 3.2 H.264 偶数要求

**问题**：分辨率 1707x1067 不是偶数，FFmpeg 编码失败

**错误信息**：`Generic error in an external library`

**修复**：向下取整到最近的偶数

```bash
w=$(( w - w % 2 ))
h=$(( h - h % 2 ))
```

### 3.3 屏幕分辨率不是 1920x1080

**问题**：用户屏幕分辨率是 1707x1067（非标准 1080p），导致录制视频分辨率是 1706x1066

**根因**：FFmpeg gdigrab 捕获的是屏幕可见区域，无法超出物理屏幕大小

**修复**：在 render-video.sh 中，拼接后自动缩放到 1920x1080

```bash
# 拼接后检查分辨率，如果不是 1920x1080 则缩放
final_res=$(ffprobe -v quiet -show_entries stream=width,height -of csv=p=0:s=x "$final_output" | head -1)
if [ "$final_res" != "1920x1080" ]; then
    ffmpeg -y -i "$final_output" \
        -vf "scale=1920:1080:flags=lanczos" \
        -c:v libx264 -preset medium -crf 18 -c:a copy "$output_dir/final-scaled.mp4"
    mv "$output_dir/final-scaled.mp4" "$final_output"
fi
```

### 3.4 浏览器视窗 vs 屏幕分辨率

**问题**：屏幕分辨率 ≠ 浏览器视窗大小（有标题栏、边框）。使用屏幕分辨率作为 FFmpeg `-video_size` 参数会导致录制内容与浏览器实际显示不匹配。

**修复**：使用 Puppeteer 获取实际视窗大小，写入临时文件供 render-video.sh 读取

```javascript
// puppeteer-launch.js
const actualViewport = await page.evaluate(() => ({
  width: window.innerWidth,
  height: window.innerHeight
}))
const viewportFile = path.join(process.cwd(), '.viewport-dimensions.txt')
fs.writeFileSync(viewportFile, `${actualViewport.width}x${actualViewport.height}`)
```

```bash
# render-video.sh - 读取浏览器实际视窗大小
if [ -f "$viewport_file" ]; then
    viewport_res=$(cat "$viewport_file" | tr -d '[:space:]')
    if [[ "$viewport_res" =~ ^[0-9]+x[0-9]+$ ]]; then
        screen_res="$viewport_res"
    fi
    rm -f "$viewport_file"
fi
```

---

## 4. Vite 端口冲突

### 4.1 旧进程占用端口

**问题**：旧 Vite 服务器占据端口 5173，新服务器自动选择其他端口，但脚本连接到旧端口

**修复**：启动前清理旧进程

```bash
pkill -f "vite" 2>/dev/null || true
sleep 2
```

### 4.2 端口检测

```bash
vite_log=$(mktemp /tmp/vite-XXXXXX.log)
npx vite --port 5173 --host 127.0.0.1 > "$vite_log" 2>&1 &
for i in $(seq 1 30); do
    if grep -q "ready in" "$vite_log" 2>/dev/null; then
        detected=$(grep -o 'http://127.0.0.1:[0-9]*' "$vite_log" | tail -1 | sed 's/.*://')
        break
    fi
    sleep 1
done
```

---

## 5. FFmpeg 字幕路径问题

### 5.1 Windows 冒号问题

**问题**：FFmpeg subtitles filter 将 `C:` 解析为参数分隔符

**修复**：使用相对路径

```bash
cp "$chapter_srt" "$output_dir/_sub.srt"
ffmpeg -i "$chapter_raw" -filter_complex "subtitles=filename=../render/_sub.srt:..." ...
```

---

## 6. Manifest 分辨率

### 6.1 自动检测

**问题**：manifest.json 中的 resolution 硬编码为 1920x1080

**修复**：使用 ffprobe 获取实际分辨率

```bash
actual_resolution=$(ffprobe -v quiet -show_entries stream=width,height -of csv=p=0:s=x "$final_output" 2>/dev/null | head -1)
```

---

## 7. Puppeteer 启动顺序

### 7.1 必须先启动浏览器再录屏

**错误顺序**：FFmpeg 先启动 → 浏览器后启动 → 录到 IDE

**正确顺序**：
1. Puppeteer 启动浏览器（后台）
2. 等待 8 秒（浏览器全屏 + 前台）
3. FFmpeg 开始录屏

---

## 8. 浏览器消失问题（FFmpeg/Puppeteer 时序）

### 8.1 浏览器在录屏中消失

**问题**：FFmpeg 录屏过程中浏览器窗口消失，录到 VS Code 桌面

**根因**：`render-video.sh` 中 FFmpeg 和 Puppeteer 的等待顺序错误：
1. FFmpeg 先录完
2. 脚本等待 Puppeteer
3. 但 Puppeteer 的 `finally` 块已调用 `browser.close()` 关闭浏览器
4. FFmpeg 录到了空桌面

**帧分析证据**（mmx 图片理解服务验证）：
- 5s/30s: 浏览器可见
- 60s: VS Code 在前台（浏览器被遮挡）
- 120s/180s: 浏览器恢复
- 230s: VS Code 在前台（浏览器已关闭）

**修复**：哨兵文件机制
```javascript
// puppeteer-launch.js - auto-play 完成后
const sentinelFile = path.join(process.cwd(), '.puppeteer-alive')
fs.writeFileSync(sentinelFile, String(process.pid))
// 等待 bash 删除哨兵文件后才关闭浏览器
await new Promise((resolve) => {
  const checkInterval = setInterval(() => {
    if (!fs.existsSync(sentinelFile)) { clearInterval(checkInterval); resolve() }
  }, 500)
  setTimeout(() => { clearInterval(checkInterval); resolve() }, MAX_WAIT_MS)
})
```

```bash
# render-video.sh - FFmpeg 录完后发信号
rm -f "$storyboard_dir/.puppeteer-alive"
wait $puppeteer_pid  # 此时才等待 puppeteer 关闭浏览器
```

### 8.2 CDP Browser.setWindowBounds 参数冲突

**问题**：`Browser.setWindowBounds` 同时设置 `windowState: 'maximized'` 和 `width/height` 报错

**错误**：`The 'minimized', 'maximized' and 'fullscreen' states cannot be combined with 'left', 'top', 'width' or 'height'`

**修复**：只用 `windowState`，不设 `width/height`
```javascript
await session.send('Browser.setWindowBounds', {
  windowId,
  bounds: { windowState: 'maximized' }  // 不能同时设 width/height
})
```

### 8.3 浏览器稳定性 Chromium flags

**问题**：浏览器在渲染过程中可能崩溃（GPU 相关）

**修复**：添加稳定性 flags
```javascript
args: [
  '--disable-gpu',                    // 防止 GPU 相关崩溃
  '--disable-software-rasterizer',    // 低资源环境稳定性
  '--disable-dev-shm-usage',          // 避免 /dev/shm 问题
  '--no-zygote',                      // 单进程更稳定
]
```

### 8.4 哨兵文件清理

**注意**：`cleanup()` 函数中需清理哨兵文件，防止残留
```bash
cleanup() {
    rm -f "${storyboard_dir:-/dev/null}/.puppeteer-alive" 2>/dev/null
}
```

---

## 9. CDP Screencast 录制方案（替代 FFmpeg gdigrab）

### 9.1 背景

FFmpeg gdigrab 桌面录屏存在多个 Windows 平台问题：
- 浏览器焦点丢失（录到 IDE）
- DPI 缩放导致录制区域偏移
- 浏览器在录屏中消失（Puppeteer/FFmpeg 时序竞争）
- 需要 Win32 API 哨兵文件机制

**解决方案**：使用 CDP `Page.startScreencast` 浏览器内录，消除所有系统级录屏问题。

### 9.2 实现

新增 `tools/capture-chrome.js`，使用 Puppeteer + CDP screencast：
- 浏览器内录，不依赖桌面焦点
- `ffprobe` 预读 MP3 时长，`setTimeout` + `dispatchEvent` 驱动翻页
- 不在浏览器内播放 MP3（规避 Chrome autoplay policy）
- 事后 FFmpeg 混流：无声视频 + 原始 MP3 → 最终 MP4

### 9.3 关键发现

| 发现 | 说明 |
|------|------|
| CDP 帧率 | 事件驱动，实际 30-100fps（非固定 15fps） |
| 动态 fps | 必须从 `frames.length / elapsed` 计算实际 fps，否则视频时长错位 |
| 键盘事件 | `page.keyboard.press` 在 screencast 期间不可靠，需用 `page.evaluate(() => window.dispatchEvent(...))` |
| 内存 | 4000+ JPEG 帧 ≈ 200MB 内存，可接受 |

### 9.4 旧方案（已废弃）

以下章节记录的 FFmpeg gdigrab + puppeteer-launch.js 方案已被 CDP screencast 替代：
- §2 浏览器焦点问题（不再需要）
- §3.1 分辨率检测（CDP 固定 1920x1080）
- §3.4 浏览器视窗 vs 屏幕分辨率（不再适用）
- §7 Puppeteer 启动顺序（不再需要 FFmpeg 启动顺序）
- §8 浏览器消失问题（不再存在）

---

## 10. 文件清单

| 文件 | 修改内容 |
| --- | --- |
| `tools/capture-chrome.js` | **新增**：CDP screencast 录制脚本 |
| `tools/render-video.sh` | 改用 capture-chrome.js 替代 FFmpeg gdigrab + puppeteer-launch.js |
| `tools/puppeteer-launch.js` | 保留，用于非录制场景（截图、验证） |
| `tools/verify-render.sh` | 渲染验证截图提取脚本 |
| `skills/render/SKILL.md` | 更新录制模式说明 |
| `references/render/REFERENCE.md` | 更新录制模式、移除 Windows 焦点/DPI 描述 |
| `specs/render-pipeline-fixes.md` | 本文档 |

---

## 9. 环境检测统一

### 9.1 问题

环境检测代码分散在多个文件中：

- `render-video.sh` 内联 PowerShell 分辨率检测（148-176 行）
- `puppeteer-launch.js` 内联 PowerShell 分辨率检测（52-75 行）
- `puppeteer-launch.js` 内联浏览器路径检测（78-89 行）
- 两处 `ffmpeg_path()` 函数重复

### 9.2 解决方案

新增两个文件：

- `tools/lib/env-common.sh` — 共享检测函数库（平台、分辨率、浏览器、预检、路径工具）
- `tools/env-check.sh` — 独立预检脚本，输出 `env-report.json`

消费者修改：

- `render-video.sh` — source env-common.sh，移除内联检测，添加预检
- `puppeteer-launch.js` — 优先读取 env-report.json，保留内联检测作为降级

### 9.3 DPI 缩放

Windows DPI 缩放导致逻辑分辨率 ≠ 物理分辨率：

- `System.Windows.Forms.Screen` 报告逻辑分辨率（1707x1067）
- WMI `Win32_VideoController` 报告物理分辨率（2560x1600）
- gdigrab 必须使用逻辑分辨率（屏幕坐标空间）
- 最终视频统一缩放到 1920x1080

### 9.4 env-report.json 结构

```json
{
  "platform": "windows",
  "resolution": {
    "logical": "1706x1066",
    "physical": "2560x1600",
    "dpi_scale": 1.5,
    "capture_recommended": "1706x1066",
    "output_target": "1920x1080"
  },
  "browser": { "path": "...", "detected": true },
  "dependencies": { "ffmpeg": {...}, "node": {...}, ... },
  "preflight": { "passed": true, "critical_failures": 0, "warnings": 1 }
}
```
