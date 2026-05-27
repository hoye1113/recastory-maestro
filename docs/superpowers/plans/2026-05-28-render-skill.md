# Render Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 render skill，用 Puppeteer 录屏 + FFmpeg 编码将 storyboard + voice 合成为最终 MP4 视频。

**Architecture:** 单文件 bash 脚本 `tools/render-video.sh` 负责编排：启动 Vite dev server → Puppeteer 按步骤截图（1920×1080）→ FFmpeg 合成截图 + 音频 → 输出 MP4。纯确定性逻辑，无 LLM 参与。

**Tech Stack:** Bash, Node.js (Puppeteer), FFmpeg, Vite dev server

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `tools/render-video.sh` | 主脚本：编排 dev server + Puppeteer + FFmpeg |
| Create | `tools/render-video.test.sh` | 测试：验证渲染逻辑 |
| Create | `tools/puppeteer-capture.js` | Puppeteer 脚本：按步骤截图 |
| Modify | `skills/voice/SKILL.md` | 新增 Step 9: 调用 render-video.sh |
| Modify | `skills/storyboard/SKILL.md` | 更新产出说明：加入渲染步骤 |

---

## 前置条件

- FFmpeg 已安装（`ffmpeg -version`）
- Node.js 已安装（`node -v`）
- Puppeteer 需安装（`npm install puppeteer`）

---

### Task 1: 安装 Puppeteer

**Files:**
- Modify: `package.json`（根目录）

- [ ] **Step 1: 检查是否已有 package.json**

```bash
ls -la package.json 2>/dev/null || echo "No root package.json"
```

- [ ] **Step 2: 创建或更新 package.json**

如果不存在，创建：
```json
{
  "name": "recastory-maestro",
  "private": true,
  "dependencies": {
    "puppeteer": "^24.0.0"
  }
}
```

如果已存在，添加 puppeteer 依赖。

- [ ] **Step 3: 安装依赖**

```bash
npm install
```

Expected: puppeteer 安装成功，Chromium 下载完成。

- [ ] **Step 4: 验证 Puppeteer 可用**

```bash
node -e "const puppeteer = require('puppeteer'); console.log('Puppeteer OK:', puppeteer.executablePath())"
```

Expected: 输出 Chromium 路径。

- [ ] **Step 5: Commit**

```bash
git add package.json package-lock.json
git commit -m "chore: add puppeteer dependency for render skill"
```

---

### Task 2: 编写 Puppeteer 截图脚本

**Files:**
- Create: `tools/puppeteer-capture.js`

- [ ] **Step 1: 编写 puppeteer-capture.js**

```javascript
// tools/puppeteer-capture.js
// 按步骤截图 storyboard 项目
// Usage: node puppeteer-capture.js <storyboard-url> <output-dir> <step-count>

const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

async function captureSteps(url, outputDir, totalSteps) {
  // Ensure output directory exists
  fs.mkdirSync(outputDir, { recursive: true });

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });

  // Navigate to storyboard with auto mode
  const autoUrl = `${url}?auto=1`;
  console.log(`Navigating to: ${autoUrl}`);
  await page.goto(autoUrl, { waitUntil: 'networkidle0', timeout: 30000 });

  // Wait for React to render
  await page.waitForSelector('#root', { timeout: 10000 });

  for (let step = 1; step <= totalSteps; step++) {
    const padded = String(step).padStart(2, '0');
    const outputFile = path.join(outputDir, `${padded}.png`);

    // Wait for animation/render to settle
    await new Promise(r => setTimeout(r, 500));

    // Capture screenshot
    await page.screenshot({
      path: outputFile,
      type: 'png',
      clip: { x: 0, y: 0, width: 1920, height: 1080 }
    });

    console.log(`Captured step ${step}/${totalSteps}: ${outputFile}`);

    // Navigate to next step (press right arrow or click)
    if (step < totalSteps) {
      await page.keyboard.press('ArrowRight');
      // Wait for transition
      await new Promise(r => setTimeout(r, 800));
    }
  }

  await browser.close();
  console.log(`Capture complete: ${totalSteps} frames in ${outputDir}`);
}

// Main
const args = process.argv.slice(2);
if (args.length < 3) {
  console.error('Usage: node puppeteer-capture.js <storyboard-url> <output-dir> <step-count>');
  process.exit(1);
}

const [url, outputDir, stepCount] = args;
captureSteps(url, outputDir, parseInt(stepCount, 10))
  .catch(err => {
    console.error('Capture failed:', err.message);
    process.exit(1);
  });
```

- [ ] **Step 2: 验证脚本语法**

```bash
node --check tools/puppeteer-capture.js
```

Expected: 无输出（语法正确）。

- [ ] **Step 3: Commit**

```bash
git add tools/puppeteer-capture.js
git commit -m "feat(render): add puppeteer screenshot capture script"
```

---

### Task 3: 编写 render-video.sh 主脚本

**Files:**
- Create: `tools/render-video.sh`
- Create: `tools/render-video.test.sh`

- [ ] **Step 1: 编写 render-video.sh**

```bash
#!/bin/bash
# tools/render-video.sh
# 合成 storyboard + voice → MP4 视频
# Usage: bash render-video.sh <workspace-dir>
#
# 流程：
# 1. 读取 audio-segments.json 获取章节结构
# 2. 启动 Vite dev server
# 3. Puppeteer 按步骤截图
# 4. FFmpeg 合成每章视频（截图 + 音频）
# 5. 合并所有章节为最终视频
# 6. 生成 manifest.json

set -euo pipefail

WORKSPACE="${1:?Usage: render-video.sh <workspace-dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Paths
STORYBOARD_DIR="$WORKSPACE/storyboard"
VOICE_DIR="$WORKSPACE/voice"
SEGMENTS_FILE="$VOICE_DIR/audio-segments.json"
AUDIO_DIR="$VOICE_DIR/public/audio"
OUTPUT_DIR="$WORKSPACE/render"
CAPTURE_DIR="$OUTPUT_DIR/frames"
FINAL_OUTPUT="$OUTPUT_DIR/final.mp4"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Cleanup handler
DEV_SERVER_PID=""
cleanup() {
    if [ -n "$DEV_SERVER_PID" ] && kill -0 "$DEV_SERVER_PID" 2>/dev/null; then
        log_info "Stopping dev server (PID: $DEV_SERVER_PID)"
        kill "$DEV_SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Validate inputs
if [ ! -d "$STORYBOARD_DIR" ]; then
    log_error "Storyboard directory not found: $STORYBOARD_DIR"
    exit 1
fi

if [ ! -f "$SEGMENTS_FILE" ]; then
    log_error "audio-segments.json not found: $SEGMENTS_FILE"
    exit 1
fi

# Check dependencies
command -v ffmpeg >/dev/null 2>&1 || { log_error "FFmpeg not installed"; exit 1; }
command -v node >/dev/null 2>&1 || { log_error "Node.js not installed"; exit 1; }
[ -f "$SCRIPT_DIR/puppeteer-capture.js" ] || { log_error "puppeteer-capture.js not found"; exit 1; }

log_info "Starting render pipeline for: $WORKSPACE"

# Create output directories
mkdir -p "$OUTPUT_DIR" "$CAPTURE_DIR"

# Step 1: Start Vite dev server
log_info "Starting Vite dev server..."
cd "$STORYBOARD_DIR"
npx vite --port 0 --host 127.0.0.1 &
DEV_SERVER_PID=$!

# Wait for server to be ready
for i in $(seq 1 30); do
    if curl -s http://127.0.0.1:$(lsof -p $DEV_SERVER_PID -a -i 2>/dev/null | grep LISTEN | awk '{print $9}' | cut -d: -f2) >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Get the actual port (Vite auto-selects if default is busy)
DEV_PORT=$(lsof -p $DEV_SERVER_PID -a -i 2>/dev/null | grep LISTEN | awk '{print $9}' | tail -1 | cut -d: -f2)
if [ -z "$DEV_PORT" ]; then
    # Fallback: check common ports
    for port in 5173 5174 5175 5176; do
        if curl -s "http://127.0.0.1:$port" >/dev/null 2>&1; then
            DEV_PORT=$port
            break
        fi
    done
fi

if [ -z "$DEV_PORT" ]; then
    log_error "Could not determine dev server port"
    exit 1
fi

STORYBOARD_URL="http://127.0.0.1:$DEV_PORT"
log_info "Dev server running at: $STORYBOARD_URL"

# Step 2: Extract chapter structure from audio-segments.json
CHAPTERS=$(grep -o '"chapter"[[:space:]]*:[[:space:]]*"[^"]*"' "$SEGMENTS_FILE" | \
           sed 's/.*"chapter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | \
           sort -u)

CHAPTER_VIDEOS=""

for chapter in $CHAPTERS; do
    log_info "Processing chapter: $chapter"

    # Get step count for this chapter
    STEP_COUNT=$(grep "\"chapter\"[[:space:]]*:[[:space:]]*\"$chapter\"" "$SEGMENTS_FILE" | \
                 grep -o '"stepIndex"[[:space:]]*:[[:space:]]*[0-9]*' | \
                 sed 's/.*"stepIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/' | \
                 sort -n | tail -1)

    if [ -z "$STEP_COUNT" ] || [ "$STEP_COUNT" -eq 0 ]; then
        log_warn "No steps found for chapter: $chapter"
        continue
    fi

    # Step 3: Capture frames
    CHAPTER_CAPTURE_DIR="$CAPTURE_DIR/$chapter"
    log_info "Capturing $STEP_COUNT frames for $chapter..."
    node "$SCRIPT_DIR/puppeteer-capture.js" "$STORYBOARD_URL" "$CHAPTER_CAPTURE_DIR" "$STEP_COUNT"

    # Step 4: Get chapter audio file
    CHAPTER_AUDIO="$AUDIO_DIR/${chapter}.srt"
    CHAPTER_MP3="$AUDIO_DIR/${chapter}.mp3"

    # Check if we have per-chapter MP3 (merged) or need to use step MP3s
    if [ -f "$CHAPTER_MP3" ]; then
        AUDIO_INPUT="-i $CHAPTER_MP3"
    else
        # Concatenate step MP3s
        STEP_MP3S=""
        for step_idx in $(seq 1 "$STEP_COUNT"); do
            STEP_MP3_FILE="$AUDIO_DIR/$chapter/$(printf "%02d" "$step_idx").mp3"
            if [ -f "$STEP_MP3_FILE" ]; then
                STEP_MP3S="$STEP_MP3S|$STEP_MP3_FILE"
            fi
        done
        if [ -n "$STEP_MP3S" ]; then
            # Create concat file for FFmpeg
            CONCAT_FILE="$OUTPUT_DIR/${chapter}-concat.txt"
            for step_idx in $(seq 1 "$STEP_COUNT"); do
                STEP_MP3_FILE="$AUDIO_DIR/$chapter/$(printf "%02d" "$step_idx").mp3"
                if [ -f "$STEP_MP3_FILE" ]; then
                    echo "file '$(realpath "$STEP_MP3_FILE")'" >> "$CONCAT_FILE"
                fi
            done
            AUDIO_INPUT="-f concat -safe 0 -i $CONCAT_FILE"
        else
            log_warn "No audio found for chapter: $chapter"
            AUDIO_INPUT=""
        fi
    fi

    # Step 5: FFmpeg - combine frames + audio into chapter video
    CHAPTER_VIDEO="$OUTPUT_DIR/${chapter}.mp4"

    # Get audio duration to determine frame duration
    if [ -n "$AUDIO_INPUT" ]; then
        AUDIO_DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$CHAPTER_MP3" 2>/dev/null || echo "0")
        if [ "$AUDIO_DURATION" = "0" ] || [ -z "$AUDIO_DURATION" ]; then
            # Estimate from step MP3s
            AUDIO_DURATION=0
            for step_idx in $(seq 1 "$STEP_COUNT"); do
                STEP_MP3_FILE="$AUDIO_DIR/$chapter/$(printf "%02d" "$step_idx").mp3"
                if [ -f "$STEP_MP3_FILE" ]; then
                    STEP_DUR=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$STEP_MP3_FILE" 2>/dev/null || echo "0")
                    AUDIO_DURATION=$(echo "$AUDIO_DURATION + $STEP_DUR" | bc 2>/dev/null || echo "$AUDIO_DURATION")
                fi
            done
        fi
    else
        AUDIO_DURATION=$(( STEP_COUNT * 5 ))  # Default 5s per step
    fi

    # Calculate per-frame duration
    FRAME_DURATION=$(echo "scale=3; $AUDIO_DURATION / $STEP_COUNT" | bc 2>/dev/null || echo "5")

    # Create frame list for FFmpeg
    FRAME_LIST="$OUTPUT_DIR/${chapter}-frames.txt"
    > "$FRAME_LIST"
    for step_idx in $(seq 1 "$STEP_COUNT"); do
        PADDED=$(printf "%02d" "$step_idx")
        FRAME_FILE="$CHAPTER_CAPTURE_DIR/${PADDED}.png"
        if [ -f "$FRAME_FILE" ]; then
            echo "file '$(realpath "$FRAME_FILE")'" >> "$FRAME_LIST"
            echo "duration $FRAME_DURATION" >> "$FRAME_LIST"
        fi
    done

    # Encode chapter video
    if [ -n "$AUDIO_INPUT" ]; then
        eval ffmpeg -y -f concat -safe 0 -i "$FRAME_LIST" \
            $AUDIO_INPUT \
            -c:v libx264 -preset medium -crf 18 \
            -c:a aac -b:a 128k \
            -pix_fmt yuv420p -r 30 \
            -shortest \
            "$CHAPTER_VIDEO" 2>/dev/null
    else
        ffmpeg -y -f concat -safe 0 -i "$FRAME_LIST" \
            -c:v libx264 -preset medium -crf 18 \
            -pix_fmt yuv420p -r 30 \
            "$CHAPTER_VIDEO" 2>/dev/null
    fi

    log_info "Chapter video: $CHAPTER_VIDEO"
    CHAPTER_VIDEOS="$CHAPTER_VIDEOS|$CHAPTER_VIDEO"
done

# Step 6: Concatenate all chapter videos
if [ -n "$CHAPTER_VIDEOS" ]; then
    CONCAT_CHAPTERS="$OUTPUT_DIR/final-concat.txt"
    > "$CONCAT_CHAPTERS"
    IFS='|' read -ra VIDEOS <<< "$CHAPTER_VIDEOS"
    for vid in "${VIDEOS[@]}"; do
        [ -n "$vid" ] && echo "file '$(realpath "$vid")'" >> "$CONCAT_CHAPTERS"
    done

    ffmpeg -y -f concat -safe 0 -i "$CONCAT_CHAPTERS" \
        -c copy \
        "$FINAL_OUTPUT" 2>/dev/null

    log_info "Final video: $FINAL_OUTPUT"
fi

# Step 7: Generate manifest.json
MANIFEST="$WORKSPACE/manifest.json"
cat > "$MANIFEST" << MANIFEST_EOF
{
  "pipeline_id": "$(basename "$WORKSPACE")",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "output": {
    "video": "$FINAL_OUTPUT",
    "chapters": [
$(for chapter in $CHAPTERS; do
    echo "      {\"id\": \"$chapter\", \"video\": \"$OUTPUT_DIR/${chapter}.mp4\"},"
done | sed '$ s/,$//')
    ]
  },
  "duration_seconds": $(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$FINAL_OUTPUT" 2>/dev/null || echo "0"),
  "resolution": "1920x1080",
  "format": "mp4"
}
MANIFEST_EOF

log_info "Manifest: $MANIFEST"
log_info "Render complete!"
```

- [ ] **Step 2: 编写测试脚本 render-video.test.sh**

```bash
#!/bin/bash
# tools/render-video.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RENDER_SCRIPT="$SCRIPT_DIR/render-video.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

assert_file_exists() {
    local test_name="$1"
    local file="$2"
    if [ -f "$file" ]; then
        echo -e "${GREEN}PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: $test_name - File not found: $file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: Script exists and is executable
test_script_exists() {
    echo -e "\n${YELLOW}Test 1: Script exists${NC}"
    assert_file_exists "render-video.sh exists" "$RENDER_SCRIPT"
    assert_file_exists "puppeteer-capture.js exists" "$SCRIPT_DIR/puppeteer-capture.js"
}

# Test 2: Argument validation
test_argument_validation() {
    echo -e "\n${YELLOW}Test 2: Argument validation${NC}"
    if bash "$RENDER_SCRIPT" 2>&1 | grep -q "Usage"; then
        echo -e "${GREEN}PASS${NC}: No arguments shows usage"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: No arguments should show usage"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 3: Missing storyboard directory
test_missing_storyboard() {
    echo -e "\n${YELLOW}Test 3: Missing storyboard${NC}"
    if bash "$RENDER_SCRIPT" "/nonexistent" 2>&1 | grep -q "not found"; then
        echo -e "${GREEN}PASS${NC}: Missing storyboard error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Should error on missing storyboard"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 4: Dependencies check
test_dependencies() {
    echo -e "\n${YELLOW}Test 4: Dependencies${NC}"
    if command -v ffmpeg >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: FFmpeg available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}SKIP${NC}: FFmpeg not installed"
    fi

    if command -v node >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: Node.js available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Node.js not installed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 5: Syntax check
test_syntax() {
    echo -e "\n${YELLOW}Test 5: Syntax check${NC}"
    if bash -n "$RENDER_SCRIPT"; then
        echo -e "${GREEN}PASS${NC}: render-video.sh syntax OK"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: render-video.sh syntax error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    if node --check "$SCRIPT_DIR/puppeteer-capture.js"; then
        echo -e "${GREEN}PASS${NC}: puppeteer-capture.js syntax OK"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: puppeteer-capture.js syntax error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Main
main() {
    echo -e "${YELLOW}Running render-video.sh tests...${NC}"

    test_script_exists
    test_argument_validation
    test_missing_storyboard
    test_dependencies
    test_syntax

    echo -e "\n${YELLOW}Test Summary:${NC}"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
```

- [ ] **Step 3: 设置权限并运行测试**

```bash
chmod +x tools/render-video.sh tools/render-video.test.sh
bash tools/render-video.test.sh
```

Expected: ALL TESTS PASSED（不含 FFmpeg 编码测试，仅验证脚本结构）。

- [ ] **Step 4: 用真实数据端到端测试**

```bash
bash tools/render-video.sh workspace/rm-test-002
```

Expected: 生成 `workspace/rm-test-002/render/final.mp4` + `manifest.json`。

- [ ] **Step 5: Commit**

```bash
git add tools/render-video.sh tools/render-video.test.sh tools/puppeteer-capture.js
git commit -m "feat(render): add render-video.sh for automated video synthesis"
```

---

### Task 4: 更新 SKILL.md 集成 render

**Files:**
- Modify: `skills/using-recastory/SKILL.md`（plan.json 依赖图）
- Modify: `WORKFLOW.md`（Phase 7 说明）

- [ ] **Step 1: 更新 using-recastory SKILL.md 的依赖图**

在 plan.json 依赖图中确认 render 在 storyboard + voice 之后：

```json
{ "name": "render", "depends_on": ["storyboard", "voice"] }
```

- [ ] **Step 2: 更新 WORKFLOW.md Phase 7**

在 Phase 7 部分添加 render 脚本调用说明：

```markdown
## Phase 7: Deliver（交付）

1. 调用 render 脚本合成视频：

```bash
bash tools/render-video.sh <workspace-dir>
```

脚本自动完成：
- 启动 Vite dev server
- Puppeteer 按步骤截图（1920×1080）
- FFmpeg 合成每章视频
- 合并为最终 MP4
- 生成 manifest.json

2. 汇总所有输出文件
3. 运行最终 `polish` 检查
4. 清理临时文件（可选）
```

- [ ] **Step 3: Commit**

```bash
git add skills/using-recastory/SKILL.md WORKFLOW.md
git commit -m "docs: integrate render skill into pipeline orchestration"
```

---

### Task 5: 更新 recastory SKILL.md 加入 render

**Files:**
- Modify: `C:\Users\Hoye\.claude\skills\recastory\SKILL.md`（调度逻辑）

- [ ] **Step 1: 更新调度流程**

在 Step 5 调度子 Skill 部分，确认 render 在 storyboard + voice 之后调用：

```
distill → (storyboard + voice 顺序执行) → render
```

- [ ] **Step 2: 更新完成报告**

在 Step 7 完成报告中加入 render 产出：
- final.mp4 路径 + 大小
- manifest.json 路径
- 每章视频列表

- [ ] **Step 3: Commit**

```bash
git add "C:/Users/Hoye/.claude/skills/recastory/SKILL.md"
git commit -m "docs(recastory): add render skill to pipeline"
```

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| Puppeteer 安装 | `node -e "require('puppeteer')"` → OK |
| 截图脚本语法 | `node --check tools/puppeteer-capture.js` → OK |
| render-video.sh 测试 | `bash tools/render-video.test.sh` → ALL TESTS PASSED |
| 端到端渲染 | `bash tools/render-video.sh workspace/rm-test-002` → final.mp4 生成 |
| manifest.json | 包含 duration、resolution、chapters 列表 |
| Dev server 清理 | 渲染完成后 dev server 自动停止 |
