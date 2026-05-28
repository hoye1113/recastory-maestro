# mmx-cli Music BGM Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 质量门禁（每 Task 强制执行）

每个 Task 完成后执行 **3 轮 Code Review**：

```text
Task 执行 → Code Review #1 → 修复全部问题 → Code Review #2 → 修复回归问题 → Code Review #3 → 最终验证 → Commit
```

**Goal:** 集成 mmx-cli 音乐生成能力到 Recastory 流水线，为视频生成背景音乐（BGM）并混音。

**Architecture:** 新增 `tools/mix-bgm.sh` 脚本，在 `render-video.sh` 生成 `final.mp4` 后调用。脚本读取 BGM 配置，调用 `mmx music generate --instrumental` 生成纯音乐，再用 FFmpeg `amix` 滤镜将 BGM 混入最终视频。BGM 生成是可选步骤，失败不阻塞流水线。

**Tech Stack:** Bash, mmx-cli (music generate), FFmpeg (amix 混音)

**参考：**
- `skills/voice/mmx-config.json` — mmx 配置模板
- `skills/storyboard/image-config.json` — 图片生成配置模板
- `tools/render-video.sh` — 当前渲染流水线（final.mp4 输出点）
- `tools/generate-images.sh` — mmx CLI 调用模式参考
- mmx-cli `music generate --help` — API 参数

---

## 设计决策（已确认）

### 1. 集成方式：后处理混音（Option C）

在 `render-video.sh` 生成 `final.mp4` 之后，独立脚本 `mix-bgm.sh` 负责：
1. 调用 `mmx music generate --instrumental` 生成 BGM MP3
2. 用 FFmpeg `amix` 将 BGM 混入 final.mp4
3. 输出 `final-with-bgm.mp4`

**理由：**
- 不修改 render-video.sh 核心逻辑
- BGM 生成失败不阻塞渲染
- 当前录屏无音频（已知限制），BGM 可作为唯一音轨
- 未来修复音频捕获后，BGM 自动混入口播下方

### 2. BGM 与口播的关系

当前状态：`final.mp4` 无音频轨道（录屏只捕获视频）。
- → BGM 成为唯一音轨，音量 = 100%

未来修复音频捕获后：
- → BGM 作为底音，音量降至 15-25%
- → 口播段落期间 BGM 自动 duck（降低音量）

脚本设计为两种模式都支持，通过 `--volume` 参数控制。

### 3. BGM Prompt 来源

两种方式：
- `--prompt` 参数直接传入描述
- 从 `plan.json` 的 `register` 字段自动推导风格

脚本优先使用 `--prompt`，无 prompt 时从 plan.json 推导。

### 4. 幂等性

- BGM MP3 已存在 → skip（`--force` 覆盖）
- `final-with-bgm.mp4` 已存在 → skip（`--force` 覆盖）
- mmx 不可用 → 警告并退出，不阻塞

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `skills/storyboard/bgm-config.json` | mmx music 配置（模型、参数模板） |
| Create | `tools/mix-bgm.sh` | 主脚本：生成 BGM → FFmpeg 混音 |
| Create | `tools/mix-bgm.test.sh` | 测试 |
| Modify | `tools/render-video.sh` | 渲染完成后调用 mix-bgm.sh（可选） |
| Modify | `references/render/REFERENCE.md` | 添加 BGM 混音指南 |

---

## mmx music generate 参数参考

```bash
mmx music generate --prompt <text> [--instrumental] [flags]

# 关键参数
--prompt <text>              # 音乐风格描述
--instrumental               # 纯音乐，无人声
--genre <text>               # 流派（folk, pop, jazz, cinematic）
--mood <text>                # 情绪（warm, uplifting, tense, calm）
--instruments <text>         # 乐器（acoustic guitar, piano, strings）
--tempo <text>               # 速度（fast, slow, moderate）
--bpm <number>               # BPM
--key <text>                 # 调性（C major, A minor）
--avoid <text>               # 避免的元素
--use-case <text>            # 用途（background music for video）
--references <text>          # 参考风格
--out <path>                 # 输出路径
--quiet                      # 静默模式
```

---

### Task 1: 创建 bgm-config.json

**Files:**
- Create: `skills/storyboard/bgm-config.json`

- [ ] **Step 1: 编写配置文件**

```json
{
  "provider": "minimax",
  "cli": "mmx",
  "auth_check": "mmx auth status",
  "generate_template": {
    "command": "mmx music generate",
    "params": {
      "prompt": "{{prompt}}",
      "instrumental": true,
      "use-case": "background music for video",
      "out": "{{output_path}}",
      "quiet": true
    }
  },
  "defaults": {
    "model": "music-2.6-free",
    "volume": 0.2,
    "fade_in_seconds": 3,
    "fade_out_seconds": 3
  },
  "style_presets": {
    "知识科普": "Cinematic orchestral, building tension, intellectual, moderate tempo",
    "产品介绍": "Upbeat electronic, modern, clean, positive energy",
    "科技评测": "Tech ambient, futuristic, minimal beats, moderate tempo",
    "人文故事": "Warm acoustic, gentle piano, emotional, slow tempo",
    "商业分析": "Corporate ambient, confident, steady rhythm, moderate tempo",
    "默认": "Cinematic ambient, moderate tempo, subtle tension, orchestral"
  }
}
```

- [ ] **Step 2: 验证 JSON 格式**

```bash
node -e "JSON.parse(require('fs').readFileSync('skills/storyboard/bgm-config.json','utf8')); console.log('Valid JSON')"
```

- [ ] **Step 3: Commit**

```bash
git add skills/storyboard/bgm-config.json
git commit -m "feat(storyboard): add mmx music BGM generation config"
```

---

### Task 2: 编写 mix-bgm.sh

**Files:**
- Create: `tools/mix-bgm.sh`
- Create: `tools/mix-bgm.test.sh`

- [ ] **Step 1: 编写 mix-bgm.sh**

脚本职责：生成 BGM 并混入 final.mp4。

**命令行接口：**

```bash
bash tools/mix-bgm.sh <workspace-dir> [--prompt <text>] [--volume <0-1>] [--force] [--dry-run]
```

- `<workspace-dir>`：必需，workspace 路径
- `--prompt <text>`：BGM 风格描述（可选，无则从 config 的 style_presets 推导）
- `--volume <0-1>`：BGM 音量（默认 0.2，即 20%）
- `--force`：重新生成已有 BGM
- `--dry-run`：只输出混音计划，不执行

**核心逻辑：**

1. 验证：
   - workspace 目录存在
   - `render/final.mp4` 存在（render-video.sh 已完成）
   - mmx 已安装且 auth 通过
   - FFmpeg 可用
2. 确定 BGM prompt：
   - 有 `--prompt` 参数 → 使用
   - 无 → 读取 `plan.json` 的 `register` 字段，查 `bgm-config.json` 的 `style_presets`
   - 都无 → 使用默认 preset
3. 生成 BGM：
   - 输出路径：`<workspace>/render/bgm.mp3`
   - 跳过已存在（除非 `--force`）
   - 调用：`mmx music generate --prompt "<prompt>" --instrumental --out <path> --quiet`
4. 混音：
   - 获取 final.mp4 时长：`ffprobe -v quiet -show_entries format=duration -of csv=p=0`
   - FFmpeg 混音命令：
     ```bash
     ffmpeg -y -i final.mp4 -i bgm.mp3 \
       -filter_complex "[1:a]volume=<volume>,afade=t=in:d=3,afade=t=out:st=<dur-3>:d=3[bgm];[0:a][bgm]amix=inputs=2:duration=first[aout]" \
       -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 192k \
       final-with-bgm.mp4
     ```
   - 如果 final.mp4 无音频轨道（当前状态），简化为：
     ```bash
     ffmpeg -y -i final.mp4 -i bgm.mp3 \
       -filter_complex "[1:a]volume=<volume>,afade=t=in:d=3,afade=t=out:st=<dur-3>:d=3[aout]" \
       -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 192k \
       final-with-bgm.mp4
     ```
5. 更新 manifest.json（如有 jq）
6. 输出汇总

**输出示例：**

```
[INFO] BGM prompt: Cinematic orchestral, building tension, intellectual
[INFO] Generating BGM: render/bgm.mp3
[INFO]   ✅ BGM generated (duration: 180s)
[INFO] Mixing BGM into final video...
[INFO]   Input: render/final.mp4 (120s)
[INFO]   BGM: render/bgm.mp3 (180s, volume: 20%)
[INFO]   Output: render/final-with-bgm.mp4
[INFO]   ✅ Mix complete
[INFO] BGM pipeline complete
```

- [ ] **Step 2: 编写测试**

测试用例：
1. 脚本存在
2. 语法检查（`bash -n`）
3. 无参数显示 usage
4. 不存在的目录报错
5. 缺少 final.mp4 报错
6. `--dry-run` 输出混音计划（用 stub mmx 和 stub ffmpeg）

- [ ] **Step 3: 运行测试**

```bash
chmod +x tools/mix-bgm.sh tools/mix-bgm.test.sh
bash tools/mix-bgm.test.sh
```

- [ ] **Step 4: Commit**

```bash
git add tools/mix-bgm.sh tools/mix-bgm.test.sh
git commit -m "feat(tools): add mix-bgm.sh for mmx music BGM generation"
```

---

### Task 3: 更新 render-video.sh

**Files:**
- Modify: `tools/render-video.sh`

- [ ] **Step 1: 在渲染完成后添加可选 BGM 调用**

在 `main` 函数的 `log_info "Render complete!"` 之前，添加：

```bash
# Optional BGM mixing
if [ "${ENABLE_BGM:-false}" = "true" ]; then
    local bgm_prompt="${BGM_PROMPT:-}"
    local bgm_volume="${BGM_VOLUME:-0.2}"
    if [ -n "$bgm_prompt" ]; then
        bash "$SCRIPT_DIR/mix-bgm.sh" "$workspace" --prompt "$bgm_prompt" --volume "$bgm_volume" || log_warn "BGM mixing failed, continuing without BGM"
    else
        bash "$SCRIPT_DIR/mix-bgm.sh" "$workspace" --volume "$bgm_volume" || log_warn "BGM mixing failed, continuing without BGM"
    fi
fi
```

**环境变量控制：**
- `ENABLE_BGM=true` → 启用 BGM
- `BGM_PROMPT="Cinematic orchestral"` → BGM 风格
- `BGM_VOLUME=0.2` → BGM 音量（默认 20%）

不设置 `ENABLE_BGM` 时，行为与当前完全一致。

- [ ] **Step 2: Commit**

```bash
git add tools/render-video.sh
git commit -m "feat(render): add optional BGM mixing to render pipeline"
```

---

### Task 4: 更新参考文档

**Files:**
- Modify: `references/render/REFERENCE.md`
- Modify: `ARCHITECTURE.md`

- [ ] **Step 1: 在 render REFERENCE.md 添加 BGM 混音指南**

在 REFERENCE.md 末尾追加：

```markdown

---

## BGM 混音指南

### mmx music generate 集成

render 流水线支持使用 mmx-cli 生成背景音乐并混入最终视频。

#### 使用方式

```bash
# 方式 1：环境变量控制
ENABLE_BGM=true BGM_PROMPT="Cinematic orchestral" bash tools/render-video.sh workspace/<id>

# 方式 2：独立调用
bash tools/mix-bgm.sh workspace/<id> --prompt "Warm acoustic, gentle piano" --volume 0.2
```

#### BGM 风格预设

| 内容类型 | 预设描述 |
|---------|---------|
| 知识科普 | Cinematic orchestral, building tension, intellectual |
| 产品介绍 | Upbeat electronic, modern, clean, positive energy |
| 科技评测 | Tech ambient, futuristic, minimal beats |
| 人文故事 | Warm acoustic, gentle piano, emotional |
| 商业分析 | Corporate ambient, confident, steady rhythm |

#### FFmpeg 混音参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| volume | 0.2 | BGM 音量（0-1），口播存在时建议 0.15-0.25 |
| fade_in | 3s | 开头淡入时长 |
| fade_out | 3s | 结尾淡出时长 |

#### 降级策略

| 场景 | 处理 |
|------|------|
| mmx-cli 未安装 | 跳过 BGM，警告用户 |
| mmx auth 失败 | 跳过 BGM，警告用户 |
| BGM 生成失败 | 跳过 BGM，警告用户 |
| final.mp4 不存在 | 阻断，要求先运行 render-video.sh |
```

- [ ] **Step 2: 更新 ARCHITECTURE.md 工具表**

在 P0 工具清单中添加：

```
| mmx CLI (music) | BGM 生成 | storyboard/SKILL.md (Step 4.5) | skills/storyboard/bgm-config.json |
| mix-bgm.sh | BGM 混音 | render REFERENCE.md | tools/mix-bgm.sh |
```

- [ ] **Step 3: Commit**

```bash
git add references/render/REFERENCE.md ARCHITECTURE.md
git commit -m "docs: add BGM mixing guide and register music tools"
```

---

### Task 5: 真实数据验证

**Files:**
- None (validation only)

- [ ] **Step 1: 验证 mmx music generate**

```bash
mmx music generate --prompt "Cinematic orchestral, moderate tempo" --instrumental --out /tmp/test-bgm.mp3 --quiet
```

Expected: /tmp/test-bgm.mp3 exists and > 0 bytes

- [ ] **Step 2: 测试 FFmpeg 混音（用测试视频）**

```bash
# 创建 10 秒测试视频（无音频）
ffmpeg -y -f lavfi -i "color=c=black:s=1920x1080:d=10" -c:v libx264 /tmp/test-video.mp4

# 混入 BGM
ffmpeg -y -i /tmp/test-video.mp4 -i /tmp/test-bgm.mp3 \
  -filter_complex "[1:a]volume=0.2,afade=t=in:d=2,afade=t=out:st=8:d=2[aout]" \
  -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 192k \
  /tmp/test-with-bgm.mp4
```

Expected: /tmp/test-with-bgm.mp4 has audio track

- [ ] **Step 3: 对 workspace 运行 mix-bgm.sh（如 render/final.mp4 存在）**

```bash
bash tools/mix-bgm.sh workspace/rm-test-002 --dry-run
```

Expected: 输出混音计划

- [ ] **Step 4: Commit（如有修复）**

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| 配置文件 | `node -e "JSON.parse(...)"` → OK |
| 脚本语法 | `bash -n tools/mix-bgm.sh` → OK |
| 测试通过 | `bash tools/mix-bgm.test.sh` → ALL PASSED |
| mmx music | `mmx music generate --instrumental --out /tmp/test.mp3` → OK |
| FFmpeg 混音 | `ffmpeg -i video -i bgm -filter_complex amix ...` → OK |
| 端到端 | `bash tools/mix-bgm.sh workspace/<id>` → final-with-bgm.mp4 |
| render-video.sh | `ENABLE_BGM=true bash tools/render-video.sh <id>` → 自动混音 |
| REFERENCE.md | 包含 BGM 混音指南 |
| ARCHITECTURE.md | 工具表包含 mmx music + mix-bgm.sh |
