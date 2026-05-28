# mmx-cli Image Generation Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 质量门禁（每 Task 强制执行）

参考 ElectronHound development-process.md，每个 Task 完成后执行 **3 轮 Code Review**，无需人工介入：

```text
Task 执行 → Code Review #1 → 修复全部问题 → Code Review #2 → 修复回归问题 → Code Review #3 → 最终验证 → Commit
```

### Review 流程

1. **Code Review #1（Spec Compliance）** — 检查代码是否完整实现计划规格
2. **修复** — 修复 #1 发现的所有 `[Required]` 问题
3. **Code Review #2（Regression Check）** — 检查修复过程中是否引入回归
4. **修复** — 修复 #2 发现的回归问题
5. **Code Review #3（Final Quality）** — 最终质量验证
6. **Commit** — 三次 Review 全部通过后提交

**Goal:** 集成 mmx-cli 图像生成能力到 Recastory storyboard 流水线，用 AI 生成的图片替换占位卡片，提升视觉质量。

**Architecture:** 新增 `tools/generate-images.sh` 脚本，扫描 outline.md 中的 `<!-- img: -->` 标记，调用 `mmx image generate` 生成图片，输出到 `storyboard/public/img/`。storyboard SKILL.md 新增 Step 4.5 图片资产步骤，Chapter.tsx 优先使用生成的图片。纯确定性工具调用，无 LLM 参与。

**Tech Stack:** Bash, mmx-cli (image generate), FFmpeg (可选图片处理)

**参考：**
- `skills/voice/SKILL.md` — mmx-cli 集成模式（config + 脚本）
- `skills/voice/mmx-config.json` — 配置文件模板
- `skills/storyboard/SKILL.md` — storyboard 流程
- mmx-cli `image generate --help` — API 参数

---

## 设计决策（已确认）

### 1. 图片标记规范

**主格式：`<!-- img: 描述 -->` HTML 注释，紧跟步骤的"屏幕"描述之后。**

```markdown
## 第1章：what — 什么是冷萃？

### 步骤 1
屏幕：冷萃咖啡特写
<!-- img: 一杯冷萃咖啡的特写，水珠凝结在玻璃杯壁，自然光，摄影风格 -->

### 步骤 2
屏幕：温度对比图
<!-- img: 温度计显示40度，左侧热咖啡冒蒸汽，右侧冷咖啡无蒸汽，信息图风格 -->
```

**标记规则：**
- 格式：`<!-- img: 描述文本 -->`
- 位置：在步骤的"屏幕"描述之后，空一行
- 描述语言：中文或英文均可，mmx 支持多语言
- 每步最多 1 张图片
- 描述粒度：自然语言描述（非完整 prompt），脚本自动加 prompt prefix

**素材清单自动生成：** `generate-images.sh` 执行时，先扫描所有 `<!-- img: -->` 标记，输出汇总清单到 stdout，然后再逐个生成。用户可在生成前确认清单。

**与 web-video-presentation 的关系：** 独立发展，共享 `<!-- img: -->` 标记规范。同一 outline.md 可被两个 skill 使用，但图片路径和 Chapter 结构各自独立。

### 2. 集成触发点

**Step 4.5（Scaffold 之后，Chapter 开发之前），图片生成不阻塞后续步骤。**

- scaffold 创建了 `public/img/` 目录结构
- Agent 此时有完整 outline 上下文
- mmx 不可用或生成失败 → Chapter 开发继续用 CSS/emoji
- Checkpoint 降级为"可选预览"，不是硬性门禁

### 3. Chapter.tsx 图片使用策略

**原则 2 扩展 + 降级链：**

原原则 2："每章必须有 1-2 个动画/演示元素。纯文字章节 = 不合格。"

扩展为："每章必须有 1-2 个视觉演示元素。优先级：生成图片 > CSS/SVG 动画 > 占位卡片。纯文字章节 = 不合格。"

Agent 在开发 Chapter 时检查 `public/img/` 是否有可用图片：
- 有图片 → 使用 `<img src="/img/<chapter>/<step>.jpg" />`
- 无图片 → 使用 CSS/SVG/emoji（现有行为）
- 图片加载失败 → Vite 静态文件服务保证可靠性，不额外处理降级

### 4. 幂等性设计

- 目标路径已有文件 → skip（`--force` flag 覆盖）
- 生成失败 → 记录警告，继续下一个
- 不支持断点续传（重新运行时跳过已成功的）
- `--force` flag：重新生成所有图片（用户对第一版不满意时使用）
- `--only <chapter-step>` flag：精确指定重生成哪张（可选，Task 2 实现）

### 5. 目录与版本控制

- `public/img/` 目录由 `generate-images.sh` 的 `mkdir -p` 自动创建，不需要修改 scaffold.sh 或 skeleton
- 生成的图片位于 `workspace/<id>/storyboard/public/img/`，被根 `.gitignore` 的 `workspace/` 规则忽略
- 图片是临时产物（ephemeral），可从 outline.md + mmx 重新生成，不需要版本控制
- Vite 自动服务 `public/` 目录下的静态文件，无需额外配置

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `skills/storyboard/image-config.json` | mmx image 配置（模型、尺寸、参数模板） |
| Create | `tools/generate-images.sh` | 主脚本：扫描 outline.md → 生成图片 |
| Create | `tools/generate-images.test.sh` | 测试 |
| Modify | `skills/storyboard/SKILL.md` | 新增 Step 4.5 + 更新原则 2 |
| Modify | `references/storyboard/REFERENCE.md` | 添加图片生成指南 |

---

## mmx image generate 参数参考

```bash
mmx image generate --prompt <text> [flags]

# 关键参数
--prompt <text>              # 图片描述
--aspect-ratio <ratio>       # 16:9, 1:1, etc.
--width <px>                 # 512-2048, multiple of 8
--height <px>                # 512-2048, multiple of 8
--seed <n>                   # 可复现种子
--subject-ref <params>       # 人物一致性：type=character,image=path-or-url
--prompt-optimizer           # 自动优化 prompt
--out <path>                 # 输出路径
--out-dir <dir>              # 输出目录
--quiet                      # 静默模式
```

---

### Task 1: 创建 image-config.json

**Files:**
- Create: `skills/storyboard/image-config.json`

- [ ] **Step 1: 编写配置文件**

参照 `skills/voice/mmx-config.json` 的结构：

```json
{
  "provider": "minimax",
  "cli": "mmx",
  "auth_check": "mmx auth status",
  "generate_template": {
    "command": "mmx image generate",
    "params": {
      "prompt": "{{prompt}}",
      "aspect-ratio": "16:9",
      "prompt-optimizer": true,
      "out": "{{output_path}}",
      "quiet": true
    }
  },
  "defaults": {
    "model": "image-01",
    "aspect_ratio": "16:9",
    "width": 1920,
    "height": 1080
  },
  "prompt_prefix": {
    "hero": "Cinematic, high quality, 16:9 aspect ratio, ",
    "icon": "Clean icon design, minimalist, ",
    "diagram": "Clean infographic style, data visualization, "
  }
}
```

- [ ] **Step 2: 验证 JSON 格式**

```bash
python -c "import json; json.load(open('skills/storyboard/image-config.json'))"
```

- [ ] **Step 3: Commit**

```bash
git add skills/storyboard/image-config.json
git commit -m "feat(storyboard): add mmx image generation config"
```

---

### Task 2: 编写 generate-images.sh

**Files:**
- Create: `tools/generate-images.sh`
- Create: `tools/generate-images.test.sh`

- [ ] **Step 1: 编写 generate-images.sh**

脚本职责：读取 outline.md 中的 `<!-- img: -->` 标记，调用 `mmx image generate` 生成图片。

**核心逻辑：**

1. 验证：outline.md 存在、mmx 已安装、mmx auth 通过
2. 扫描 outline.md 中的 `<!-- img: 描述 -->` 标记
3. 解析章节上下文（从 `## 第N章：xxx` 标题提取 chapter id）
4. 为每张图片生成输出路径：`<workspace>/storyboard/public/img/<chapter>/<step>.jpg`
5. 跳过已存在的文件（除非 `--force`）
6. 调用 `mmx image generate --prompt "<prefix><desc>" --aspect-ratio 16:9 --prompt-optimizer --out <path> --quiet`
7. 验证生成的文件存在且非空
8. 输出汇总：generated / skipped / failed 计数

**命令行接口：**

```bash
bash tools/generate-images.sh <workspace-dir> [--force] [--dry-run]
```

- `<workspace-dir>`：必需，workspace 路径（包含 `distill/outline.md`）
- `--force`：重新生成已有图片
- `--dry-run`：只输出清单，不实际生成

**章节 ID 提取规则：**

扫描 outline.md 中的 `## 第N章：<id> — <标题>` 模式，提取 `<id>` 作为目录名。如果找不到章节标题，使用 `misc` 作为默认目录。

步骤编号从 `### 步骤 N` 或 `### Step N` 提取。如果找不到步骤编号，按出现顺序递增。

**Prompt 构建：**

从 `skills/storyboard/image-config.json` 读取 `prompt_prefix`，根据描述内容自动选择 prefix 类型（hero/icon/diagram），拼接为完整 prompt。如果无法判断类型，使用空前缀。

**输出示例：**

```
[INFO] Scanning outline.md for image markers...
[INFO] Found 5 image markers:
  1. 01-what/01.jpg — 一杯冷萃咖啡的特写
  2. 01-what/02.jpg — 温度对比图
  3. 02-how/01.jpg — 咖啡豆研磨过程
  4. 02-how/02.jpg — 分子结构示意
  5. 03-why/01.jpg — 风味轮盘
[INFO] Generating images...
[INFO]   ✅ 01-what/01.jpg
[INFO]   ✅ 01-what/02.jpg
[INFO]   ✅ 02-how/01.jpg
[WARN]   ⏭️ 02-how/02.jpg (exists, skipping)
[INFO]   ✅ 03-why/01.jpg
[INFO] Done: 4 generated, 1 skipped, 0 failed
```

- [ ] **Step 2: 编写测试**

```bash
#!/bin/bash
# tools/generate-images.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

echo "=== generate-images.sh tests ==="

# Test 1: Script exists
[ -f "$SCRIPT_DIR/generate-images.sh" ] && pass "Script exists" || fail "Script missing"

# Test 2: Syntax check
bash -n "$SCRIPT_DIR/generate-images.sh" 2>/dev/null && pass "Syntax OK" || fail "Syntax error"

# Test 3: No arguments shows usage
output=$(bash "$SCRIPT_DIR/generate-images.sh" 2>&1 || true)
echo "$output" | grep -qi "usage" && pass "No args shows usage" || fail "No usage message"

# Test 4: Non-existent directory
output=$(bash "$SCRIPT_DIR/generate-images.sh" /nonexistent 2>&1 || true)
echo "$output" | grep -qi "not found\|error" && pass "Non-existent dir errors" || fail "No error for bad dir"

# Test 5: Missing outline.md
TMPDIR=$(mktemp -d)
output=$(bash "$SCRIPT_DIR/generate-images.sh" "$TMPDIR" 2>&1 || true)
echo "$output" | grep -qi "outline" && pass "Missing outline.md errors" || fail "No error for missing outline"
rm -rf "$TMPDIR"

# Test 6: --dry-run with valid outline
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/distill"
cat > "$TMPDIR/distill/outline.md" << 'OUTLINE'
## 第1章：test — 测试章节

### 步骤 1
屏幕：测试图片
<!-- img: 一张测试图片 -->

### 步骤 2
屏幕：无图片步骤
这里是文字内容
OUTLINE
output=$(bash "$SCRIPT_DIR/generate-images.sh" "$TMPDIR" --dry-run 2>&1 || true)
echo "$output" | grep -qi "1.*image\|dry-run\|清单" && pass "Dry-run shows marker count" || fail "Dry-run missing marker info"
rm -rf "$TMPDIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

- [ ] **Step 3: 运行测试**

```bash
chmod +x tools/generate-images.sh tools/generate-images.test.sh
bash tools/generate-images.test.sh
```

- [ ] **Step 4: Commit**

```bash
git add tools/generate-images.sh tools/generate-images.test.sh
git commit -m "feat(tools): add generate-images.sh for mmx image generation"
```

---

### Task 3: 更新 storyboard SKILL.md

**Files:**
- Modify: `skills/storyboard/SKILL.md`

- [ ] **Step 1: 在 Step 4 (Scaffold) 之后添加 Step 4.5**

在现有 Step 4 和 Step 5 之间插入新步骤：

```markdown
### 4.5 生成图片资产（可选）

如 outline.md 中包含图片描述标记（`<!-- img: 描述 -->`），自动生成图片：

```bash
bash tools/generate-images.sh <workspace-dir>
```

脚本自动完成：
1. 扫描 `distill/outline.md` 中的 `<!-- img: 描述 -->` 标记
2. 输出图片清单到 stdout，等待确认
3. 调用 `mmx image generate` 生成每张图片
4. 输出到 `storyboard/public/img/<chapter>/<step>.jpg`

**降级处理**：
- mmx-cli 不可用 → 跳过图片生成，使用纯文本/卡片布局
- 单张图片失败 → 记录警告，继续生成其他图片
- 全部失败 → 警告用户，继续使用占位卡片

**[可选预览]** — 图片生成后，可展示首张图片预览供用户确认质量。非硬性门禁。
```

- [ ] **Step 2: 更新原则 2**

将原则 2 从：

```markdown
**原则 2：必须有视觉演示元素**
- 每章必须有 1-2 个动画/演示元素
- 纯文字章节 = 不合格
```

更新为：

```markdown
**原则 2：必须有视觉演示元素**
- 每章必须有 1-2 个视觉演示元素
- 优先级：生成图片 > CSS/SVG 动画 > 占位卡片
- 如有生成的图片（`public/img/`），优先使用 `<img>` 而非纯 CSS 占位
- 纯文字章节 = 不合格
```

- [ ] **Step 3: Commit**

```bash
git add skills/storyboard/SKILL.md
git commit -m "docs(storyboard): add image generation step and update principle 2"
```

---

### Task 4: 更新 storyboard REFERENCE.md

**Files:**
- Modify: `references/storyboard/REFERENCE.md`

- [ ] **Step 1: 添加图片生成指南**

在 REFERENCE.md 末尾追加：

```markdown
---

## 图片生成指南

### mmx image generate 集成

storyboard 支持使用 mmx-cli 生成 AI 图片，替换占位卡片。

#### 命令模板

```bash
mmx image generate \
  --prompt "图片描述" \
  --aspect-ratio 16:9 \
  --prompt-optimizer \
  --out workspace/<id>/storyboard/public/img/<chapter>/<step>.jpg \
  --quiet
```

#### 图片标记规范

在 `distill/outline.md` 的步骤描述后添加 HTML 注释：

```markdown
### 步骤 1
屏幕：冷萃咖啡特写
<!-- img: 一杯冷萃咖啡的特写，水珠凝结在玻璃杯壁，自然光，摄影风格 -->
```

**标记规则：**
- 格式：`<!-- img: 描述文本 -->`
- 位置：在步骤的"屏幕"描述之后
- 描述语言：中文或英文均可
- 每步最多 1 张图片

#### Prompt 编写规范

| 图片类型 | Prompt 前缀 | 示例 |
|---------|------------|------|
| 章节 Hero 图 | `Cinematic, high quality, ` | `Cinematic, high quality, 一杯冷萃咖啡特写` |
| 数据图表 | `Clean infographic, data visualization, ` | `Clean infographic, 温度对比图表` |
| 场景插图 | `Photorealistic, ` | `Photorealistic, 咖啡豆研磨过程` |
| 概念图 | `Minimalist illustration, ` | `Minimalist illustration, 分子结构` |

#### Prompt 优化技巧

1. **具体 > 抽象**：`"一杯冷萃咖啡，玻璃杯，水珠凝结"` > `"冷萃咖啡"`
2. **风格描述**：`"摄影风格"` / `"信息图风格"` / `"插画风格"`
3. **光线描述**：`"自然光"` / `"工作室灯光"` / `"侧光"`
4. **构图描述**：`"特写"` / `"俯视"` / `"45度角"`

#### 图片尺寸

| 用途 | 尺寸 | 说明 |
|------|------|------|
| 全屏背景 | 1920×1080 | `--width 1920 --height 1080` |
| 半屏插图 | 960×540 | `--width 960 --height 540` |
| 图标/小图 | 512×512 | `--width 512 --height 512` |

#### 人物一致性

如需保持角色外观一致，使用 `--subject-ref`：

```bash
mmx image generate \
  --prompt "一个男人在咖啡店" \
  --subject-ref "type=character,image=workspace/id/storyboard/public/img/character-ref.jpg" \
  --out workspace/id/storyboard/public/img/01-what/02.jpg
```

#### Chapter.tsx 中使用图片

```tsx
// 有生成图片时
if (step === 0) return (
  <div className="cd-stage">
    <img src="/img/01-what/01.jpg" alt="冷萃咖啡特写" className="cd-hero-img" />
  </div>
);

// 无图片时保持 CSS/emoji 占位
if (step === 1) return (
  <div className="cd-stage">
    <div className="cd-placeholder">☕</div>
  </div>
);
```

#### 降级策略

| 场景 | 处理 |
|------|------|
| mmx-cli 未安装 | 跳过图片生成，使用纯文本布局 |
| mmx auth 失败 | 跳过图片生成，警告用户 |
| 单张图片失败 | 记录警告，继续生成其他图片 |
| 全部失败 | 使用占位卡片，警告用户 |
```

- [ ] **Step 2: Commit**

```bash
git add references/storyboard/REFERENCE.md
git commit -m "docs(storyboard): add image generation guide to REFERENCE.md"
```

---

### Task 5: 真实数据验证

**Files:**
- None (validation only)

- [ ] **Step 1: 验证 mmx auth**

```bash
mmx auth status
```

Expected: JSON with auth method

- [ ] **Step 2: 测试图片生成**

```bash
mmx image generate --prompt "一杯冷萃咖啡的特写，水珠凝结在玻璃杯壁，自然光，摄影风格" --aspect-ratio 16:9 --out /tmp/test-coffee.jpg --quiet
```

Expected: /tmp/test-coffee.jpg exists and > 0 bytes

- [ ] **Step 3: 对 rm-test-002 运行脚本（如 outline.md 有图片标记）**

```bash
bash tools/generate-images.sh workspace/rm-test-002
```

Expected: 图片生成到 `workspace/rm-test-002/storyboard/public/img/`

- [ ] **Step 4: 验证生成的图片**

```bash
ls -la workspace/rm-test-002/storyboard/public/img/
file workspace/rm-test-002/storyboard/public/img/*/*.jpg
```

Expected: JPEG image data

- [ ] **Step 5: Commit（如有修复）**

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| 配置文件 | `python -c "import json; json.load(open('skills/storyboard/image-config.json'))"` → OK |
| 脚本语法 | `bash -n tools/generate-images.sh` → OK |
| 测试通过 | `bash tools/generate-images.test.sh` → ALL PASSED |
| mmx auth | `mmx auth status` → OK |
| 图片生成 | `mmx image generate --prompt "test" --out /tmp/test.jpg` → OK |
| 端到端 | `bash tools/generate-images.sh workspace/rm-test-002` → 图片生成 |
| SKILL.md | 包含 Step 4.5 + 更新后的原则 2 |
| REFERENCE.md | 包含图片生成指南 |
| --force | `bash tools/generate-images.sh workspace/rm-test-002 --force` → 重新生成 |
| --dry-run | `bash tools/generate-images.sh workspace/rm-test-002 --dry-run` → 只输出清单 |
