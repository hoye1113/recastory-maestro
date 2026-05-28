# mmx-cli Video Supplement Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 质量门禁（每 Task 强制执行）

每个 Task 完成后执行 **3 轮 Code Review**：

```text
Task 执行 → Code Review #1 → 修复全部问题 → Code Review #2 → 修复回归问题 → Code Review #3 → 最终验证 → Commit
```

**Goal:** 集成 mmx-cli 视频生成能力到 Recastory 流水线，作为补充素材（非替代录屏）。生成的短视频片段可用于章节过渡、场景插图、片头片尾。

**Architecture:** 新增 `tools/generate-videos.sh` 脚本，扫描 outline.md 中的 `<!-- video: -->` 标记，调用 `mmx video generate --async` 异步生成，轮询等待完成，下载到 `storyboard/public/video/`。视频生成是可选步骤，失败不阻塞流水线。

**Tech Stack:** Bash, mmx-cli (video generate/task get/download), FFmpeg (可选视频处理)

**参考：**
- `tools/generate-images.sh` — mmx CLI 调用模式参考
- `skills/storyboard/image-config.json` — 配置模板
- mmx-cli `video generate --help` — API 参数

**重要限制：**
- mmx video 生成时长有限（几秒到十几秒）
- 异步任务，需要轮询等待
- 不适合完整叙事视频，仅作为补充素材
- 生成成本较高，应谨慎使用

---

## 设计决策（已确认）

### 1. 定位：补充素材，非替代录屏

mmx video 生成的片段用于：
- 章节过渡动画（2-3 秒）
- 场景插图（配合口播的视觉片段）
- 片头/片尾动效
- 数据可视化动画片段

**不用于：** 替代 Puppeteer + FFmpeg 录屏流程。

### 2. 标记规范

与图片标记类似，在 outline.md 中使用 `<!-- video: 描述 -->`：

```markdown
### 步骤 3
屏幕：咖啡豆研磨过程
<!-- video: 咖啡豆在研磨机中被慢慢研磨，特写镜头，慢动作，电影感 -->
```

### 3. 异步工作流

mmx video 是异步的：
1. `mmx video generate --prompt "..." --async` → 返回 taskId
2. `mmx video task get --task-id <id>` → 轮询状态
3. `mmx video download --file-id <id> --out <path>` → 下载完成视频

脚本需要实现轮询逻辑。

### 4. 幂等性

- 目标路径已有文件 → skip（`--force` 覆盖）
- 生成失败 → 记录警告，继续下一个
- 不支持断点续传

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `skills/storyboard/video-config.json` | mmx video 配置 |
| Create | `tools/generate-videos.sh` | 主脚本：扫描标记 → 异步生成 → 下载 |
| Create | `tools/generate-videos.test.sh` | 测试 |
| Modify | `references/storyboard/REFERENCE.md` | 添加视频生成指南 |

---

## mmx video generate 参数参考

```bash
mmx video generate --prompt <text> [flags]

# 关键参数
--prompt <text>              # 视频描述
--model <model>              # MiniMax-Hailuo-2.3 (default) or MiniMax-Hailuo-2.3-Fast
--first-frame <path-or-url>  # 首帧图片（可选）
--async                      # 异步模式，返回 taskId
--download <path>            # 下载完成视频
--poll-interval <seconds>    # 轮询间隔（默认 5）

# 异步工作流
mmx video generate --prompt "..." --async           # → {"taskId": "..."}
mmx video task get --task-id <id>                    # → 状态
mmx video download --file-id <id> --out video.mp4    # → 下载
```

---

### Task 1: 创建 video-config.json

**Files:**
- Create: `skills/storyboard/video-config.json`

- [ ] **Step 1: 编写配置文件**

```json
{
  "provider": "minimax",
  "cli": "mmx",
  "auth_check": "mmx auth status",
  "generate_template": {
    "command": "mmx video generate",
    "params": {
      "prompt": "{{prompt}}",
      "async": true,
      "quiet": true
    }
  },
  "defaults": {
    "model": "MiniMax-Hailuo-2.3",
    "poll_interval": 10,
    "max_wait_seconds": 300
  },
  "prompt_prefix": {
    "transition": "Smooth cinematic transition, ",
    "scene": "Cinematic, high quality, ",
    "motion": "Slow motion, dramatic, "
  }
}
```

- [ ] **Step 2: 验证 JSON**

```bash
node -e "JSON.parse(require('fs').readFileSync('skills/storyboard/video-config.json','utf8')); console.log('Valid JSON')"
```

- [ ] **Step 3: Commit**

```bash
git add skills/storyboard/video-config.json
git commit -m "feat(storyboard): add mmx video generation config"
```

---

### Task 2: 编写 generate-videos.sh

**Files:**
- Create: `tools/generate-videos.sh`
- Create: `tools/generate-videos.test.sh`

- [ ] **Step 1: 编写 generate-videos.sh**

脚本职责：扫描 outline.md 中的 `<!-- video: -->` 标记，异步生成视频，轮询等待，下载。

**命令行接口：**

```bash
bash tools/generate-videos.sh <workspace-dir> [--force] [--dry-run]
```

**核心逻辑：**

1. 验证：outline.md 存在、mmx 已安装且 auth 通过
2. 扫描 `<!-- video: 描述 -->` 标记
3. 提取章节/步骤 ID（同 generate-images.sh 逻辑）
4. 对每张标记：
   - 跳过已存在（除非 `--force`）
   - 调用 `mmx video generate --prompt "<desc>" --async --output json`
   - 解析 taskId
   - 轮询 `mmx video task get --task-id <id> --output json` 直到完成或超时
   - 调用 `mmx video download --file-id <id> --out <path>`
   - 验证文件存在且非空
5. 输出汇总

**轮询逻辑：**

```bash
local max_wait=300
local poll_interval=10
local elapsed=0

while [ $elapsed -lt $max_wait ]; do
    local status_json
    status_json=$(mmx video task get --task-id "$task_id" --output json --quiet 2>/dev/null)
    local status
    status=$(echo "$status_json" | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).status||'')")
    
    if [ "$status" = "completed" ] || [ "$status" = "success" ]; then
        # Download
        local file_id
        file_id=$(echo "$status_json" | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).fileId||'')")
        mmx video download --file-id "$file_id" --out "$out_path" --quiet
        break
    elif [ "$status" = "failed" ] || [ "$status" = "error" ]; then
        log_error "Video generation failed: $desc"
        failed=$((failed + 1))
        break
    fi
    
    sleep $poll_interval
    elapsed=$((elapsed + poll_interval))
done

if [ $elapsed -ge $max_wait ]; then
    log_error "Timeout waiting for video: $desc"
    failed=$((failed + 1))
fi
```

- [ ] **Step 2: 编写测试**

测试用例：
1. 脚本存在
2. 语法检查
3. 无参数显示 usage
4. 不存在的目录报错
5. 缺少 outline.md 报错
6. `--dry-run` 输出视频清单

- [ ] **Step 3: 运行测试**

```bash
chmod +x tools/generate-videos.sh tools/generate-videos.test.sh
bash tools/generate-videos.test.sh
```

- [ ] **Step 4: Commit**

```bash
git add tools/generate-videos.sh tools/generate-videos.test.sh
git commit -m "feat(tools): add generate-videos.sh for mmx video supplement"
```

---

### Task 3: 更新参考文档

**Files:**
- Modify: `references/storyboard/REFERENCE.md`

- [ ] **Step 1: 添加视频生成指南**

在 REFERENCE.md 的图片生成指南后追加：

```markdown

---

## 视频补充素材指南

### mmx video generate 集成

storyboard 支持使用 mmx-cli 生成短视频片段作为补充素材。

**重要限制：** mmx video 生成时长有限（几秒到十几秒），仅适用于补充素材，不替代录屏流程。

#### 视频标记规范

在 `distill/outline.md` 的步骤描述后添加 HTML 注释：

```markdown
### 步骤 3
屏幕：咖啡豆研磨过程
<!-- video: 咖啡豆在研磨机中被慢慢研磨，特写镜头，慢动作，电影感 -->
```

#### 使用方式

```bash
# 扫描标记并生成
bash tools/generate-videos.sh <workspace-dir>

# 仅查看清单
bash tools/generate-videos.sh <workspace-dir> --dry-run

# 强制重新生成
bash tools/generate-videos.sh <workspace-dir> --force
```

#### 输出路径

视频输出到 `storyboard/public/video/<chapter>/<step>.mp4`，在 Chapter.tsx 中使用：

```tsx
if (step === 2) return (
  <div className="cd-stage">
    <video src="/video/01-what/03.mp4" autoPlay loop muted className="cd-bg-video" />
  </div>
);
```

#### 适用场景

| 场景 | 适用性 |
|------|--------|
| 章节过渡（2-3s） | ✅ 适合 |
| 场景插图（配合口播） | ✅ 适合 |
| 片头/片尾动效 | ✅ 适合 |
| 完整叙事视频 | ❌ 不适合（时长限制） |
| 替代录屏 | ❌ 不适合 |

#### 降级策略

| 场景 | 处理 |
|------|------|
| mmx-cli 未安装 | 跳过视频生成 |
| mmx auth 失败 | 跳过视频生成 |
| 生成超时（>5min） | 记录警告，继续 |
| 单个视频失败 | 记录警告，继续 |
```

- [ ] **Step 2: Commit**

```bash
git add references/storyboard/REFERENCE.md
git commit -m "docs(storyboard): add video supplement guide to REFERENCE.md"
```

---

### Task 4: 真实数据验证

**Files:**
- None (validation only)

- [ ] **Step 1: 验证 mmx video generate**

```bash
mmx video generate --prompt "A coffee bean being ground in slow motion" --async --output json --quiet
```

Expected: JSON with taskId

- [ ] **Step 2: 测试脚本 dry-run**

```bash
bash tools/generate-videos.sh workspace/rm-test-002 --dry-run
```

Expected: 输出视频清单

- [ ] **Step 3: Commit（如有修复）**

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| 配置文件 | `node -e "JSON.parse(...)"` → OK |
| 脚本语法 | `bash -n tools/generate-videos.sh` → OK |
| 测试通过 | `bash tools/generate-videos.test.sh` → ALL PASSED |
| mmx video | `mmx video generate --async` → taskId |
| 端到端 | `bash tools/generate-videos.sh <workspace>` → 视频文件 |
| REFERENCE.md | 包含视频补充素材指南 |
