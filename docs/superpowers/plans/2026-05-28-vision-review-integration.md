# mmx-cli Vision Review Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 质量门禁（每 Task 强制执行）

每个 Task 完成后执行 **3 轮 Code Review**：

```text
Task 执行 → Code Review #1 → 修复全部问题 → Code Review #2 → 修复回归问题 → Code Review #3 → 最终验证 → Commit
```

**Goal:** 集成 mmx-cli vision 能力到 Recastory 审计流水线，用 VLM 自动检测 storyboard 的视觉质量问题（AI 味指纹、对比度、占位卡片、信息密度等）。

**Architecture:** 扩展 Puppeteer 脚本支持逐步骤截图，在 `tools/audit/rules.py` 中新增 VV 系列规则，调用 `mmx vision describe` 分析截图。VV 规则复用现有 `Rule` 数据类架构，与 TR/CD/VO/SL 规则并行运行。

**Tech Stack:** Node.js (Puppeteer 截图), Python (audit rules), mmx-cli (vision describe), Bash (编排脚本)

**参考：**
- `tools/audit/rules.py` — 现有规则架构（Rule dataclass + detect 函数）
- `tools/audit/scanner.py` — 文件扫描器
- `tools/puppeteer-launch.js` — Puppeteer 自动播放脚本
- `ARCHITECTURE.md` CH-001~006 / SB-001~005 — 已定义未实现的视觉规则
- mmx-cli `vision describe --help` — API 参数

---

## 设计决策（已确认）

### 1. 截图方式：扩展 Puppeteer 脚本

在 `puppeteer-launch.js` 中添加 `--screenshot-steps` 模式：
- 每次 step 切换后，等待渲染稳定（500ms）
- 调用 `page.screenshot()` 保存到 `workspace/<id>/storyboard/screenshots/step-N.png`
- 不影响现有录屏流程（截图是独立模式）

### 2. 规则架构：复用现有 Rule dataclass

VV 系列规则遵循与 TR/CD/VO/SL 相同的模式：
- 规则 ID：VV-001 ~ VV-005
- 输入：截图文件路径（而非 .md 文本）
- 调用：`mmx vision describe --image <path> --prompt "<检查提示>" --output json`
- 输出：RuleResult（pass/warn/fail + message）

### 3. 检查维度（5 条规则）

| 规则 | 检查内容 | 对应已有规则 |
|------|---------|-------------|
| VV-001 | AI 味指纹（紫粉渐变/圆角彩色边框/emoji 当图标） | CH-001, CH-003 |
| VV-002 | 信息密度（每步视觉元素数是否过于均匀） | CH-003 (信息密度无起伏) |
| VV-003 | 占位卡片未替换（检测 "image · 16:9" 文字） | SB-005 |
| VV-004 | 总结式结尾（大号"谢谢"/进度条终点） | CH-004 |
| VV-005 | 文字过多（单步屏幕文字 > 80 字） | SB-001 |

### 4. 集成点：Phase 4 Audit

VV 规则作为 `python -m tools.audit` 的一部分运行：
- scanner.py 扫描 `screenshots/*.png` 文件
- VV 规则对每张截图调用 mmx vision
- 结果与其他规则合并输出

### 5. 降级策略

- mmx vision 不可用 → 跳过 VV 规则，输出 warning
- 截图不存在 → 跳过 VV 规则（无图可查）
- mmx vision 调用失败 → 单条规则 skip，不影响其他规则

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Modify | `tools/puppeteer-launch.js` | 添加 `--screenshot-steps` 截图模式 |
| Create | `tools/audit/vision_rules.py` | VV 系列规则（调用 mmx vision） |
| Modify | `tools/audit/rules.py` | 注册 VV 规则 |
| Modify | `tools/audit/scanner.py` | 添加 screenshots/ 文件扫描 |
| Create | `tools/audit/vision_rules.test.py` | VV 规则测试 |
| Modify | `tools/audit/test_rules.py` | 添加 VV 规则集成测试 |
| Modify | `tools/capture-screenshots.sh` | 编排脚本：Puppeteer 截图 → 审计 |
| Modify | `references/storyboard/REFERENCE.md` | 添加视觉审查指南 |

---

## mmx vision describe 参数参考

```bash
mmx vision describe --image <path-or-url> [--prompt <text>] [--output json]

# 关键参数
--image <path-or-url>        # 本地图片路径或 URL
--prompt <text>              # 关于图片的问题（默认 "Describe the image."）
--output json                # JSON 格式输出
--quiet                      # 静默模式
```

---

### Task 1: 扩展 Puppeteer 截图功能

**Files:**
- Modify: `tools/puppeteer-launch.js`

- [ ] **Step 1: 读取现有 puppeteer-launch.js**

理解当前结构：auto-play 模式、step 推进逻辑、完成检测。

- [ ] **Step 2: 添加 --screenshot-steps 命令行参数**

在脚本参数解析中添加：
```javascript
const screenshotSteps = process.argv.includes('--screenshot-steps');
const screenshotDir = process.argv.find(a => a.startsWith('--screenshot-dir='))?.split('=')[1]
  || path.join(workspaceDir, 'storyboard', 'screenshots');
```

- [ ] **Step 3: 在 step 切换后添加截图逻辑**

在每次 SPACE press 后、等待渲染稳定后：

```javascript
if (screenshotSteps) {
  await new Promise(r => setTimeout(r, 500)); // 等待渲染稳定
  const stepFile = path.join(screenshotDir, `step-${String(stepIndex).padStart(2, '0')}.png`);
  fs.mkdirSync(screenshotDir, { recursive: true });
  await page.screenshot({ path: stepFile, fullPage: false });
  console.log(`[SCREENSHOT] ${stepFile}`);
}
```

- [ ] **Step 4: 添加 --screenshot-only 模式（不录屏，只截图）**

```javascript
if (screenshotOnly) {
  // 不启动 auto-play，逐个 step 截图
  for (let i = 0; i < totalSteps; i++) {
    await new Promise(r => setTimeout(r, 500));
    const stepFile = path.join(screenshotDir, `step-${String(i).padStart(2, '0')}.png`);
    await page.screenshot({ path: stepFile, fullPage: false });
    console.log(`[SCREENSHOT] ${stepFile}`);
    await page.keyboard.press('Space');
  }
  await browser.close();
  process.exit(0);
}
```

- [ ] **Step 5: Commit**

```bash
git add tools/puppeteer-launch.js
git commit -m "feat(puppeteer): add --screenshot-steps per-step capture mode"
```

---

### Task 2: 创建 VV 规则模块

**Files:**
- Create: `tools/audit/vision_rules.py`
- Create: `tools/audit/vision_rules.test.py`

- [ ] **Step 1: 编写 vision_rules.py**

模块职责：定义 VV-001 ~ VV-005 规则，调用 mmx vision describe 分析截图。

```python
"""VV-series rules: Visual Verification via mmx vision."""
import json
import subprocess
from dataclasses import dataclass
from typing import Optional


@dataclass
class RuleResult:
    rule_id: str
    status: str  # "pass", "warn", "fail", "skip"
    message: str
    file: Optional[str] = None


def _call_vision(image_path: str, prompt: str) -> Optional[str]:
    """Call mmx vision describe and return the description text."""
    try:
        result = subprocess.run(
            ["mmx", "vision", "describe", "--image", image_path, "--prompt", prompt, "--output", "json", "--quiet"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            return None
        data = json.loads(result.stdout)
        return data.get("description") or data.get("content") or ""
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        return None


def _mmx_available() -> bool:
    """Check if mmx CLI is installed and authenticated."""
    try:
        result = subprocess.run(["mmx", "auth", "status"], capture_output=True, timeout=10)
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def detect_vv001_ai_fingerprint(image_path: str) -> RuleResult:
    """VV-001: Detect AI visual fingerprints."""
    prompt = (
        "Analyze this slide for AI-generated visual clichés. "
        "Check for: (1) purple-pink gradients, (2) rounded cards with colored left borders, "
        "(3) emoji used as icons, (4) gradient buttons with pill shapes, "
        "(5) generic stock photo aesthetics. "
        "Reply with PASS if none found, or FAIL with specific issues."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return RuleResult("VV-001", "skip", "mmx vision unavailable", image_path)
    status = "fail" if "FAIL" in desc.upper() else "pass"
    return RuleResult("VV-001", status, desc[:200], image_path)


def detect_vv002_info_density(image_path: str) -> RuleResult:
    """VV-002: Detect uniform information density across steps."""
    prompt = (
        "Count the number of distinct visual elements on this slide (text blocks, "
        "images, charts, cards, icons). Reply with just a number."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return RuleResult("VV-002", "skip", "mmx vision unavailable", image_path)
    try:
        count = int(''.join(c for c in desc if c.isdigit()))
        if count > 10:
            return RuleResult("VV-002", "warn", f"High element count: {count}", image_path)
        return RuleResult("VV-002", "pass", f"Element count: {count}", image_path)
    except ValueError:
        return RuleResult("VV-002", "skip", f"Could not parse count: {desc[:100]}", image_path)


def detect_vv003_placeholder(image_path: str) -> RuleResult:
    """VV-003: Detect placeholder cards not replaced with real images."""
    prompt = (
        "Does this slide contain a placeholder card (a card showing text like "
        "'image · 16:9 description' or 'placeholder')? "
        "Reply PASS if no placeholder found, FAIL if placeholder detected."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return RuleResult("VV-003", "skip", "mmx vision unavailable", image_path)
    status = "fail" if "FAIL" in desc.upper() else "pass"
    return RuleResult("VV-003", status, desc[:200], image_path)


def detect_vv004_ending_screen(image_path: str) -> RuleResult:
    """VV-004: Detect template ending screens (thank you, progress bar)."""
    prompt = (
        "Is this slide a generic ending screen (e.g., 'Thank you', 'Thanks', "
        "progress bar at 100%, 'The End', 'Q&A')? "
        "Reply PASS if it has real content, FAIL if it's a generic ending."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return RuleResult("VV-004", "skip", "mmx vision unavailable", image_path)
    status = "fail" if "FAIL" in desc.upper() else "pass"
    return RuleResult("VV-004", status, desc[:200], image_path)


def detect_vv005_text_density(image_path: str) -> RuleResult:
    """VV-005: Detect excessive text on a single slide."""
    prompt = (
        "Estimate the total Chinese character count (or English word count) "
        "visible on this slide. Reply with just a number."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return RuleResult("VV-005", "skip", "mmx vision unavailable", image_path)
    try:
        count = int(''.join(c for c in desc if c.isdigit()))
        if count > 80:
            return RuleResult("VV-005", "fail", f"Text too dense: ~{count} chars", image_path)
        elif count > 50:
            return RuleResult("VV-005", "warn", f"Text moderately dense: ~{count} chars", image_path)
        return RuleResult("VV-005", "pass", f"Text count: ~{count} chars", image_path)
    except ValueError:
        return RuleResult("VV-005", "skip", f"Could not parse count: {desc[:100]}", image_path)


VV_RULES = [
    detect_vv001_ai_fingerprint,
    detect_vv002_info_density,
    detect_vv003_placeholder,
    detect_vv004_ending_screen,
    detect_vv005_text_density,
]


def run_vv_rules(screenshot_dir: str) -> list[RuleResult]:
    """Run all VV rules on screenshots in the given directory."""
    import os
    results = []
    if not _mmx_available():
        results.append(RuleResult("VV", "skip", "mmx CLI not available"))
        return results
    if not os.path.isdir(screenshot_dir):
        results.append(RuleResult("VV", "skip", f"Screenshot dir not found: {screenshot_dir}"))
        return results

    screenshots = sorted(f for f in os.listdir(screenshot_dir) if f.endswith('.png'))
    if not screenshots:
        results.append(RuleResult("VV", "skip", "No screenshots found"))
        return results

    for filename in screenshots:
        filepath = os.path.join(screenshot_dir, filename)
        for rule_fn in VV_RULES:
            result = rule_fn(filepath)
            results.append(result)

    return results
```

- [ ] **Step 2: 编写测试**

```python
"""Tests for VV vision rules."""
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.dirname(__file__))
from vision_rules import (
    _mmx_available, _call_vision,
    detect_vv001_ai_fingerprint, detect_vv003_placeholder,
    detect_vv005_text_density, run_vv_rules, RuleResult
)


class TestMmxAvailable(unittest.TestCase):
    @patch('subprocess.run')
    def test_available(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        self.assertTrue(_mmx_available())

    @patch('subprocess.run')
    def test_not_installed(self, mock_run):
        mock_run.side_effect = FileNotFoundError
        self.assertFalse(_mmx_available())


class TestVisionRules(unittest.TestCase):
    @patch('vision_rules._call_vision', return_value=None)
    def test_skip_when_vision_unavailable(self, mock_v):
        result = detect_vv001_ai_fingerprint('/fake/img.png')
        self.assertEqual(result.status, 'skip')

    @patch('vision_rules._call_vision', return_value='PASS. No AI clichés found.')
    def test_pass_clean_slide(self, mock_v):
        result = detect_vv001_ai_fingerprint('/fake/img.png')
        self.assertEqual(result.status, 'pass')

    @patch('vision_rules._call_vision', return_value='FAIL. Purple gradient detected.')
    def test_fail_ai_fingerprint(self, mock_v):
        result = detect_vv001_ai_fingerprint('/fake/img.png')
        self.assertEqual(result.status, 'fail')

    @patch('vision_rules._call_vision', return_value='150')
    def test_fail_text_density(self, mock_v):
        result = detect_vv005_text_density('/fake/img.png')
        self.assertEqual(result.status, 'fail')

    @patch('vision_rules._call_vision', return_value='30')
    def test_pass_text_density(self, mock_v):
        result = detect_vv005_text_density('/fake/img.png')
        self.assertEqual(result.status, 'pass')


class TestRunVvRules(unittest.TestCase):
    @patch('vision_rules._mmx_available', return_value=False)
    def test_skip_when_no_mmx(self, mock_a):
        results = run_vv_rules('/fake/dir')
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].status, 'skip')


if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 3: 运行测试**

```bash
python -m tools.audit.vision_rules.test_vision_rules -v
```

- [ ] **Step 4: Commit**

```bash
git add tools/audit/vision_rules.py tools/audit/vision_rules.test.py
git commit -m "feat(audit): add VV visual verification rules via mmx vision"
```

---

### Task 3: 集成 VV 规则到审计模块

**Files:**
- Modify: `tools/audit/rules.py`
- Modify: `tools/audit/scanner.py`
- Modify: `tools/audit/test_rules.py`

- [ ] **Step 1: 在 rules.py 注册 VV 规则**

在 rules.py 的 `ALL_RULES` 列表中导入并添加 VV 规则：

```python
try:
    from .vision_rules import VV_RULES
    ALL_RULES.extend(VV_RULES)
except ImportError:
    pass  # mmx vision not available
```

- [ ] **Step 2: 在 scanner.py 添加 screenshots/ 扫描**

添加对 `screenshots/*.png` 文件的扫描映射：

```python
def scan_screenshots(workspace_dir: str) -> list[str]:
    """Scan for screenshot files in storyboard/screenshots/."""
    import glob
    pattern = os.path.join(workspace_dir, 'storyboard', 'screenshots', '*.png')
    return sorted(glob.glob(pattern))
```

- [ ] **Step 3: 更新测试**

在 `test_rules.py` 中添加 VV 规则的集成测试。

- [ ] **Step 4: Commit**

```bash
git add tools/audit/rules.py tools/audit/scanner.py tools/audit/test_rules.py
git commit -m "feat(audit): integrate VV rules into audit pipeline"
```

---

### Task 4: 创建截图编排脚本

**Files:**
- Create: `tools/capture-screenshots.sh`

- [ ] **Step 1: 编写脚本**

```bash
#!/bin/bash
# tools/capture-screenshots.sh
# Capture per-step screenshots from storyboard and optionally run VV audit.
# Usage: bash capture-screenshots.sh <workspace-dir> [--audit]
set -euo pipefail

WORKSPACE="${1:?Usage: capture-screenshots.sh <workspace-dir> [--audit]}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUDIT=false

for arg in "$@"; do
    [ "$arg" = "--audit" ] && AUDIT=true
done

STORYBOARD_DIR="$WORKSPACE/storyboard"
SCREENSHOT_DIR="$STORYBOARD_DIR/screenshots"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Validation
[ -d "$STORYBOARD_DIR" ] || { log_error "Storyboard dir not found: $STORYBOARD_DIR"; exit 1; }

# Start Vite dev server
log_info "Starting Vite dev server..."
cd "$STORYBOARD_DIR"
npx vite --port 5174 --host 127.0.0.1 &
VITE_PID=$!
sleep 3

# Capture screenshots
log_info "Capturing screenshots..."
node "$SCRIPT_DIR/puppeteer-launch.js" \
    --url "http://127.0.0.1:5174/?auto=1" \
    --screenshot-steps \
    --screenshot-dir "$SCREENSHOT_DIR" \
    || log_error "Screenshot capture failed"

# Stop Vite
kill $VITE_PID 2>/dev/null || true

log_info "Screenshots saved to: $SCREENSHOT_DIR"
ls -la "$SCREENSHOT_DIR"/*.png 2>/dev/null | wc -l | xargs -I{} echo "  {} screenshots captured"

# Optional: run VV audit
if [ "$AUDIT" = true ]; then
    log_info "Running visual audit..."
    python -m tools.audit "$WORKSPACE" --rule VV || log_error "VV audit found issues"
fi
```

- [ ] **Step 2: Commit**

```bash
git add tools/capture-screenshots.sh
git commit -m "feat(tools): add capture-screenshots.sh orchestration script"
```

---

### Task 5: 更新参考文档

**Files:**
- Modify: `references/storyboard/REFERENCE.md`
- Modify: `ARCHITECTURE.md`

- [ ] **Step 1: 在 REFERENCE.md 添加视觉审查指南**

在反模式速查后追加：

```markdown

---

## 视觉审查（VV 规则）

mmx vision 支持自动检测 storyboard 截图中的视觉质量问题。

### 运行方式

```bash
# 截图 + 自动审查
bash tools/capture-screenshots.sh workspace/<id> --audit

# 仅截图
bash tools/capture-screenshots.sh workspace/<id>

# 仅审查（截图已存在）
python -m tools.audit workspace/<id> --rule VV
```

### VV 规则列表

| 规则 | 检查内容 | 对应规则 |
|------|---------|---------|
| VV-001 | AI 味指纹（紫粉渐变/圆角彩色边框/emoji 当图标） | CH-001, CH-003 |
| VV-002 | 信息密度（视觉元素数是否过于均匀） | CH-003 |
| VV-003 | 占位卡片未替换 | SB-005 |
| VV-004 | 总结式结尾（大号"谢谢"） | CH-004 |
| VV-005 | 文字过多（> 80 字） | SB-001 |

### 降级策略

| 场景 | 处理 |
|------|------|
| mmx vision 不可用 | 跳过 VV 规则，其他规则正常运行 |
| 截图不存在 | 跳过 VV 规则 |
| mmx vision 调用失败 | 单条规则 skip |
```

- [ ] **Step 2: 更新 ARCHITECTURE.md**

在工具表添加 mmx vision 和 capture-screenshots.sh。

- [ ] **Step 3: Commit**

```bash
git add references/storyboard/REFERENCE.md ARCHITECTURE.md
git commit -m "docs: add visual review guide and register vision tools"
```

---

### Task 6: 真实数据验证

**Files:**
- None (validation only)

- [ ] **Step 1: 验证 mmx vision**

```bash
mmx vision describe --image <any-png> --prompt "Describe this image." --quiet
```

Expected: 描述文本

- [ ] **Step 2: 测试截图功能**

```bash
bash tools/capture-screenshots.sh workspace/rm-test-002
```

Expected: `screenshots/step-01.png` 等文件存在

- [ ] **Step 3: 测试 VV 审计**

```bash
python -m tools.audit workspace/rm-test-002 --rule VV --json
```

Expected: JSON 输出包含 VV-001 ~ VV-005 结果

- [ ] **Step 4: Commit（如有修复）**

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| Puppeteer 截图 | `node puppeteer-launch.js --screenshot-steps` → PNG 文件 |
| VV 规则测试 | `python -m tools.audit.vision_rules.test -v` → ALL PASSED |
| 审计集成 | `python -m tools.audit <workspace> --rule VV` → VV 结果 |
| 编排脚本 | `bash tools/capture-screenshots.sh <workspace> --audit` → 截图 + 审计 |
| 降级处理 | mmx 不可用时 VV 规则 skip，不影响其他规则 |
| REFERENCE.md | 包含视觉审查指南 |
| ARCHITECTURE.md | 工具表包含 mmx vision |
