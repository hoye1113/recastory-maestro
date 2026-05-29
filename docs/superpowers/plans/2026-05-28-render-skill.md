# Render Skill Implementation Plan

> **OBSOLETE**: 本计划基于 FFmpeg gdigrab 方案，已被 CDP screencast 替代。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 质量门禁（每 Task 强制执行）

参考 ElectronHound development-process.md，每个 Task 完成后执行 **3 轮 Code Review**，无需人工介入：

```text
Task 执行 → Code Review #1 → 修复全部问题 → Code Review #2 → 修复回归问题 → Code Review #3 → 最终验证 → Commit
```

### Review 流程

1. **Code Review #1（Spec Compliance）** — 检查代码是否完整实现计划规格
   - 所有 spec 要求均已实现（无遗漏）
   - 无超出 spec 的多余功能
   - 命名、签名与计划一致
2. **修复** — 修复 #1 发现的所有 `[Required]` 问题
3. **Code Review #2（Regression Check）** — 检查修复过程中是否引入回归
   - 之前通过的功能仍然正常
   - 修复没有引入新问题
4. **修复** — 修复 #2 发现的回归问题
5. **Code Review #3（Final Quality）** — 最终质量验证
   - 代码质量、安全性、可维护性
   - 测试通过
   - 无遗留问题
6. **Commit** — 三次 Review 全部通过后提交

### Review 标签

- **[Required]** — 必须修复，阻断继续
- **[Optional]** — 建议改进，不阻断
- **[Question]** — 需要澄清
- **[FYI]** — 信息同步

**Goal:** 实现 render skill，用 Puppeteer 自动化浏览器操作 + FFmpeg 录屏，将 storyboard + voice 合成为最终 MP4 视频。

**Architecture:** App.tsx 支持 `?auto=1` URL 参数实现自动播放。`tools/render-video.sh` 编排：启动 Vite dev server → 合并步骤级 MP3 → Puppeteer 打开浏览器并按 SPACE 启动自动播放 → FFmpeg 录屏 → 烧入字幕 → 输出 MP4。纯确定性逻辑，无 LLM 参与。

**Tech Stack:** Bash, Node.js (Puppeteer), FFmpeg, Vite dev server, React

**参考：** `skills/web-video-presentation/references/RECORDING.md` — Auto 模式录屏方案

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `tools/render-video.sh` | 主脚本：dev server + Puppeteer + FFmpeg 录屏 + 字幕烧入 |
| Create | `tools/render-video.test.sh` | 测试 |
| Create | `tools/puppeteer-launch.js` | Puppeteer：打开浏览器 + 按 SPACE + 等待播放完成 |
| Create | `tools/merge-mp3.sh` | 合并步骤级 MP3 → 章节级 MP3 |
| Create | `tools/merge-mp3.test.sh` | 测试 |
| Modify | `skills/storyboard/skeleton/src/App.tsx` | 新增 `?auto=1` 自动播放模式 |
| Modify | `workspace/rm-test-002/storyboard/src/App.tsx` | 同步 auto mode |
| Modify | `package.json` | 添加 puppeteer 依赖 |
| Modify | `WORKFLOW.md` | 更新 Phase 7 |

---

## 前置条件

- FFmpeg 已安装（`ffmpeg -version`）
- Node.js 已安装（`node -v`）
- Puppeteer 已安装（Task 1 完成后）
- storyboard 项目已有步骤级 MP3

---

### Task 1: 安装 Puppeteer + 实现 App.tsx auto mode

**Files:**
- Modify: `package.json`
- Modify: `skills/storyboard/skeleton/src/App.tsx`
- Modify: `workspace/rm-test-002/storyboard/src/App.tsx`

- [ ] **Step 1: 安装 Puppeteer**

```bash
npm install puppeteer
```

- [ ] **Step 2: 实现 App.tsx `?auto=1` 模式**

在现有 App.tsx 基础上添加：

1. URL 参数解析：`?auto=1`
2. "Press SPACE to start" 蒙层
3. SPACE 键启动自动播放
4. 每步播放对应 MP3（`/audio/<chapterId>/<stepNum>.mp3`）
5. 音频 `ended` 事件 → 200ms 缓冲 → 自动前进一步
6. 最后一步播完停在终态

关键实现：
```typescript
const params = new URLSearchParams(window.location.search)
const isAutoMode = params.get('auto') === '1'
const [isStarted, setIsStarted] = useState(false)
const audioRef = useRef<HTMLAudioElement | null>(null)

// SPACE to start (auto mode only)
useEffect(() => {
  if (!isAutoMode) return
  const handler = (e: KeyboardEvent) => {
    if (e.key === ' ' && !isStarted) {
      e.preventDefault()
      setIsStarted(true)
    }
  }
  window.addEventListener('keydown', handler)
  return () => window.removeEventListener('keydown', handler)
}, [isAutoMode, isStarted])

// Auto-play: play audio per step, advance on ended
useEffect(() => {
  if (!isAutoMode || !isStarted) return

  // Find chapter/localStep from globalStep
  let acc = 0, chIdx = 0, local = 0
  for (let i = 0; i < chapters.length; i++) {
    if (globalStep < acc + chapters[i].stepCount) {
      chIdx = i; local = globalStep - acc; break
    }
    acc += chapters[i].stepCount
  }

  const chapterId = chapters[chIdx].id
  const stepNum = String(local + 1).padStart(2, '0')
  const audio = new Audio(`/audio/${chapterId}/${stepNum}.mp3`)
  audioRef.current = audio

  const onEnded = () => {
    setTimeout(() => {
      setGlobalStep(s => Math.min(s + 1, totalSteps - 1))
    }, 200)
  }
  audio.addEventListener('ended', onEnded)
  audio.play().catch(console.error)

  return () => {
    audio.pause()
    audio.removeEventListener('ended', onEnded)
    audioRef.current = null
  }
}, [globalStep, isAutoMode, isStarted])
```

蒙层：
```typescript
if (isAutoMode && !isStarted) {
  return (
    <div style={{
      width: 1920, height: 1080,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: '#000', color: '#fff', fontSize: 32
    }}>
      Press SPACE to start
    </div>
  )
}
```

- [ ] **Step 3: 同步到 rm-test-002 和 skeleton**

两个文件保持一致。

- [ ] **Step 4: TypeScript 编译验证**

```bash
cd skills/storyboard/skeleton && npx tsc --noEmit
cd workspace/rm-test-002/storyboard && npx tsc --noEmit
```

- [ ] **Step 5: Commit**

```bash
git add package.json package-lock.json skills/storyboard/skeleton/src/App.tsx workspace/rm-test-002/storyboard/src/App.tsx
git commit -m "feat(render): add puppeteer + App.tsx auto-play mode"
```

---

### Task 2: 编写 merge-mp3.sh

**Files:**
- Create: `tools/merge-mp3.sh`
- Create: `tools/merge-mp3.test.sh`

- [ ] **Step 1: 编写 merge-mp3.sh**

用 FFmpeg concat 合并步骤级 MP3 → 章节级 MP3。结构同 `tools/merge-srt.sh`。

```bash
#!/bin/bash
# tools/merge-mp3.sh
# Usage: bash merge-mp3.sh <workspace-dir>
set -euo pipefail

WORKSPACE="${1:?Usage: merge-mp3.sh <workspace-dir>}"
VOICE_DIR="$WORKSPACE/voice"
SEGMENTS_FILE="$VOICE_DIR/audio-segments.json"
AUDIO_DIR="$VOICE_DIR/public/audio"

[ -f "$SEGMENTS_FILE" ] || { echo "ERROR: $SEGMENTS_FILE not found" >&2; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ERROR: FFmpeg not installed" >&2; exit 1; }

CHAPTERS=$(grep -o '"chapterIndex"[[:space:]]*:[[:space:]]*[0-9]*\|"chapter"[[:space:]]*:[[:space:]]*"[^"]*"' "$SEGMENTS_FILE" | \
           paste - - | \
           sed 's/.*"chapterIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*"chapter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1 \2/' | \
           sort -n | awk '{print $2}' | uniq)

for chapter in $CHAPTERS; do
    CHAPTER_DIR="$AUDIO_DIR/$chapter"
    OUTPUT="$AUDIO_DIR/${chapter}.mp3"
    [ -d "$CHAPTER_DIR" ] || { echo "WARN: $CHAPTER_DIR not found, skipping" >&2; continue; }

    STEPS=$(grep "\"chapter\"[[:space:]]*:[[:space:]]*\"$chapter\"" "$SEGMENTS_FILE" | \
            grep -o '"stepIndex"[[:space:]]*:[[:space:]]*[0-9]*' | \
            sed 's/.*"stepIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/' | sort -n)

    CONCAT="/tmp/merge-mp3-$$.txt"
    > "$CONCAT"
    for step in $STEPS; do
        f="$CHAPTER_DIR/$(printf "%02d" "$step").mp3"
        [ -f "$f" ] && echo "file '$(realpath "$f")'" >> "$CONCAT"
    done

    [ -s "$CONCAT" ] && ffmpeg -y -f concat -safe 0 -i "$CONCAT" -c copy "$OUTPUT" 2>/dev/null && echo "  ✅ $OUTPUT"
    rm -f "$CONCAT"
done
echo "MP3 merge completed"
```

- [ ] **Step 2: 编写测试**

创建模拟 workspace + 静音 MP3（FFmpeg lavfi），验证合并后时长正确。

- [ ] **Step 3: 运行测试 + 真实数据验证**

```bash
chmod +x tools/merge-mp3.sh tools/merge-mp3.test.sh
bash tools/merge-mp3.test.sh
bash tools/merge-mp3.sh workspace/rm-test-002
```

- [ ] **Step 4: Commit**

```bash
git add tools/merge-mp3.sh tools/merge-mp3.test.sh
git commit -m "feat(tools): add merge-mp3.sh for chapter-level audio concatenation"
```

---

### Task 3: 编写 Puppeteer 启动脚本

**Files:**
- Create: `tools/puppeteer-launch.js`

**职责：** 打开浏览器 → 等待页面加载 → 按 SPACE → 等待自动播放完成 → 关闭浏览器

- [ ] **Step 1: 编写 puppeteer-launch.js**

```javascript
// tools/puppeteer-launch.js
// 自动打开浏览器、启动 auto-play、等待播放完成
// Usage: node puppeteer-launch.js <storyboard-url> [--headed]

const puppeteer = require('puppeteer')

async function launch(url, headed = false) {
  const browser = await puppeteer.launch({
    headless: headed ? false : 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  })

  const page = await browser.newPage()
  await page.setViewport({ width: 1920, height: 1080 })

  console.log(`Opening: ${url}`)
  await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 })

  // Wait for React to render
  await page.waitForSelector('#root', { timeout: 10000 })

  // Check if auto mode overlay is showing
  const hasOverlay = await page.evaluate(() => {
    return document.body.textContent.includes('Press SPACE to start')
  })

  if (!hasOverlay) {
    console.log('WARN: Auto mode overlay not found, page may not support ?auto=1')
  }

  // Press SPACE to start
  console.log('Pressing SPACE to start auto-play...')
  await page.keyboard.press('Space')

  // Wait for auto-play to complete
  // Strategy: poll for the page to signal completion
  // The app plays audio per step and advances. When the last step's audio ends,
  // the app stays on the final step. We detect this by watching for stability.
  console.log('Waiting for auto-play to complete...')

  let lastStep = -1
  let stableCount = 0

  while (stableCount < 10) {
    await new Promise(r => setTimeout(r, 1000))

    // Try to detect current step from the page
    const currentStep = await page.evaluate(() => {
      // Look for progress bar or step indicator
      const bar = document.querySelector('.cd-progress-bar')
      if (bar) {
        const width = bar.style.width
        return width // e.g., "100%" for last step
      }
      return null
    }).catch(() => null)

    if (currentStep === '100%') {
      stableCount++
    } else {
      stableCount = 0
    }
  }

  console.log('Auto-play complete')
  await browser.close()
  console.log('Browser closed')
}

const args = process.argv.slice(2)
const url = args[0]
const headed = args.includes('--headed')

if (!url) {
  console.error('Usage: node puppeteer-launch.js <storyboard-url> [--headed]')
  process.exit(1)
}

launch(url, headed).catch(err => {
  console.error('Failed:', err.message)
  process.exit(1)
})
```

- [ ] **Step 2: 验证语法**

```bash
node --check tools/puppeteer-launch.js
```

- [ ] **Step 3: Commit**

```bash
git add tools/puppeteer-launch.js
git commit -m "feat(render): add puppeteer-launch.js for automated browser + SPACE"
```

---

### Task 4: 编写 render-video.sh 主脚本

**Files:**
- Create: `tools/render-video.sh`
- Create: `tools/render-video.test.sh`

**流程：**
1. 启动 Vite dev server
2. 调用 merge-mp3.sh 合并章节级音频
3. 计算总音频时长（FFprobe）
4. 启动 FFmpeg 录屏（后台，按总时长 + buffer）
5. Puppeteer 打开浏览器 + 按 SPACE + 等待播放完成
6. FFmpeg 停止录屏
7. 烧入字幕
8. 合并章节视频 + 生成 manifest.json

- [ ] **Step 1: 编写 render-video.sh**

```bash
#!/bin/bash
# tools/render-video.sh
# Usage: bash render-video.sh <workspace-dir>
set -euo pipefail

WORKSPACE="${1:?Usage: render-video.sh <workspace-dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

STORYBOARD_DIR="$WORKSPACE/storyboard"
VOICE_DIR="$WORKSPACE/voice"
SEGMENTS_FILE="$VOICE_DIR/audio-segments.json"
AUDIO_DIR="$VOICE_DIR/public/audio"
OUTPUT_DIR="$WORKSPACE/render"
FINAL_OUTPUT="$OUTPUT_DIR/final.mp4"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

DEV_SERVER_PID=""
FFMPEG_PID=""
cleanup() {
    [ -n "$FFMPEG_PID" ] && kill -0 "$FFMPEG_PID" 2>/dev/null && kill "$FFMPEG_PID" 2>/dev/null
    [ -n "$DEV_SERVER_PID" ] && kill -0 "$DEV_SERVER_PID" 2>/dev/null && kill "$DEV_SERVER_PID" 2>/dev/null
}
trap cleanup EXIT

[ -d "$STORYBOARD_DIR" ] || { log_error "Storyboard not found"; exit 1; }
[ -f "$SEGMENTS_FILE" ] || { log_error "audio-segments.json not found"; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { log_error "FFmpeg not installed"; exit 1; }

log_info "Starting render pipeline"
mkdir -p "$OUTPUT_DIR"

# Step 1: Merge MP3s
log_info "Merging step MP3s..."
bash "$SCRIPT_DIR/merge-mp3.sh" "$WORKSPACE"

# Step 2: Start dev server
log_info "Starting Vite dev server..."
cd "$STORYBOARD_DIR"
npx vite --port 5173 --host 127.0.0.1 &
DEV_SERVER_PID=$!
for i in $(seq 1 30); do curl -s "http://127.0.0.1:5173" >/dev/null 2>&1 && break; sleep 1; done
log_info "Dev server at http://127.0.0.1:5173"

# Step 3: Process chapters
CHAPTERS=$(grep -o '"chapterIndex"[[:space:]]*:[[:space:]]*[0-9]*\|"chapter"[[:space:]]*:[[:space:]]*"[^"]*"' "$SEGMENTS_FILE" | \
           paste - - | sed 's/.*"chapterIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*"chapter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1 \2/' | \
           sort -n | awk '{print $2}' | uniq)

CHAPTER_VIDEOS=""

for chapter in $CHAPTERS; do
    log_info "Rendering chapter: $chapter"

    CHAPTER_MP3="$AUDIO_DIR/${chapter}.mp3"
    CHAPTER_SRT="$AUDIO_DIR/${chapter}.srt"
    CHAPTER_RAW="$OUTPUT_DIR/${chapter}-raw.mp4"
    CHAPTER_VIDEO="$OUTPUT_DIR/${chapter}.mp4"

    [ -f "$CHAPTER_MP3" ] || { log_warn "No MP3 for $chapter, skipping"; continue; }

    # Get audio duration
    AUDIO_DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$CHAPTER_MP3")
    CAPTURE_DUR=$(echo "$AUDIO_DUR + 3" | bc)

    # Step 4: Platform-specific screen capture
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*|Windows*) SCREEN_INPUT="-f gdigrab -framerate 30 -video_size 1920x1080 -i desktop" ;;
        Darwin*) SCREEN_INPUT="-f avfoundation -framerate 30 -i 1:0" ;;
        *) SCREEN_INPUT="-f x11grab -framerate 30 -video_size 1920x1080 -i :0.0" ;;
    esac

    # Step 5: Start FFmpeg recording (background)
    log_info "Starting screen capture (${CAPTURE_DUR}s)..."
    ffmpeg -y $SCREEN_INPUT -t "$CAPTURE_DUR" -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p "$CHAPTER_RAW" &
    FFMPEG_PID=$!
    sleep 1  # Let FFmpeg initialize

    # Step 6: Puppeteer opens browser + presses SPACE
    log_info "Launching browser for auto-play..."
    node "$SCRIPT_DIR/puppeteer-launch.js" "http://127.0.0.1:5173/?auto=1" --headed

    # Step 7: Wait for FFmpeg to finish
    wait $FFMPEG_PID 2>/dev/null || true
    FFMPEG_PID=""

    # Step 8: Burn subtitles
    if [ -f "$CHAPTER_SRT" ]; then
        log_info "Burning subtitles..."
        ffmpeg -y -i "$CHAPTER_RAW" \
            -vf "subtitles=${CHAPTER_SRT}:force_style='FontSize=24,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2'" \
            -c:v libx264 -preset medium -crf 18 -c:a copy "$CHAPTER_VIDEO" 2>/dev/null
        rm -f "$CHAPTER_RAW"
    else
        mv "$CHAPTER_RAW" "$CHAPTER_VIDEO"
    fi

    log_info "Chapter video: $CHAPTER_VIDEO"
    CHAPTER_VIDEOS="$CHAPTER_VIDEOS|$CHAPTER_VIDEO"
done

# Step 9: Concatenate
if [ -n "$CHAPTER_VIDEOS" ]; then
    CONCAT="$OUTPUT_DIR/final-concat.txt"
    > "$CONCAT"
    IFS='|' read -ra VIDS <<< "$CHAPTER_VIDEOS"
    for vid in "${VIDS[@]}"; do [ -n "$vid" ] && echo "file '$(realpath "$vid")'" >> "$CONCAT"; done
    ffmpeg -y -f concat -safe 0 -i "$CONCAT" -c copy "$FINAL_OUTPUT" 2>/dev/null
    log_info "Final video: $FINAL_OUTPUT"
fi

# Step 10: Manifest
cat > "$WORKSPACE/manifest.json" << EOF
{
  "pipeline_id": "$(basename "$WORKSPACE")",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "output": { "video": "$FINAL_OUTPUT" },
  "duration_seconds": $(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$FINAL_OUTPUT" 2>/dev/null || echo "0"),
  "resolution": "1920x1080"
}
EOF

log_info "Render complete!"
```

- [ ] **Step 2: 编写测试**

验证：脚本存在、参数校验、缺少 storyboard 报错、语法正确。

- [ ] **Step 3: 运行测试**

```bash
chmod +x tools/render-video.sh tools/render-video.test.sh
bash tools/render-video.test.sh
```

- [ ] **Step 4: Commit**

```bash
git add tools/render-video.sh tools/render-video.test.sh
git commit -m "feat(render): add render-video.sh with Puppeteer + FFmpeg pipeline"
```

---

### Task 5: 更新文档

**Files:**
- Modify: `WORKFLOW.md`
- Modify: `C:\Users\Hoye\.claude\skills\recastory\SKILL.md`

- [ ] **Step 1: 更新 WORKFLOW.md Phase 7**

```markdown
## Phase 7: Deliver（交付）

1. 合并章节级音频：`bash tools/merge-mp3.sh <workspace-dir>`
2. 渲染视频：`bash tools/render-video.sh <workspace-dir>`

脚本自动完成：
- 启动 Vite dev server
- 合并步骤级 MP3 → 章节级 MP3
- Puppeteer 打开浏览器 + 按 SPACE 启动自动播放
- FFmpeg 录屏
- 烧入章节级 SRT 字幕
- 合并为最终 MP4 + 生成 manifest.json
```

- [ ] **Step 2: 更新 recastory SKILL.md 调度流程**

确认 render 在 storyboard + voice 之后调用。

- [ ] **Step 3: Commit**

```bash
git add WORKFLOW.md "C:/Users/Hoye/.claude/skills/recastory/SKILL.md"
git commit -m "docs: integrate render skill into pipeline"
```

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| Puppeteer 安装 | `node -e "require('puppeteer')"` → OK |
| App.tsx auto mode | 手动 `?auto=1` + SPACE → 自动播放 |
| merge-mp3.sh | `bash tools/merge-mp3.test.sh` → ALL PASSED |
| puppeteer-launch.js | `node --check tools/puppeteer-launch.js` → OK |
| render-video.sh | `bash tools/render-video.test.sh` → ALL PASSED |
| 端到端 | `bash tools/render-video.sh workspace/rm-test-002` → final.mp4 |
| 字幕烧入 | final.mp4 包含可见字幕 |
| manifest.json | 包含 duration、resolution |
