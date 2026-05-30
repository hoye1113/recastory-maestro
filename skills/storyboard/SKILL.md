---
name: storyboard
version: 1.1.0
description: 从 outline.md 生成 Vite+React+TS 幻灯片项目，含 narrations.ts 单一信源、23 主题、逐章开发。触发条件：/recastory storyboard 或被 using-recastory 调度。
---

> Darwin Skill: 92.3/100 (baseline 90 → optimized 2026-05-30)

# Skill: storyboard

## IRON LAW

**narrations.ts 是步骤数和口播文本的唯一信源。Chapter.tsx 中最大 `step === N` + 1 必须等于 `narrations.length`。5 个位置必须同步：script / outline / chapter code / chapters.ts / audio 文件。**

违反任一条 = 立即停止，报告具体不一致位置，等待修复后继续。

## Purpose

将 outline.md 转化为可运行的 Vite+React+TS 幻灯片项目，每步独占整屏，点击推进节拍。

## Preconditions

- `plan.json` 已存在且包含必需字段：`pipeline_id`、`execution_mode`
- `distill/outline.md` 已存在，格式为 `## N. <id> — <title>（<S> steps · ~<T>s）`
- `distill/script.md` 已存在（用于 narrations.ts 口播文本）
- 如指定 `--perspective`，对应视角 SKILL.md 可用

**前置验证**：

1. 读取 `plan.json`，确认 `pipeline_id` 和 `execution_mode` 字段存在。缺失则阻断，提示用户重新运行 using-recastory 生成 plan.json。
2. 读取 `distill/outline.md`，确认至少包含一个 `## N.` 格式的章节目录。无章节则阻断，提示 outline.md 格式不符合预期。

## Steps

### 1. 读取计划和大纲

从 `plan.json` 获取：
- `pipeline_id` — 项目目录名
- `perspective.name` — 视角名称（如有）
- `execution_mode` — A/B/C 并行模式
- `register` — brand/product（影响配色策略）

读取 `distill/outline.md`，提取：
- 章节数 + 每章步骤数
- 每步屏幕内容描述
- 信息池（数据/引用/案例）

**outline.md 预期格式**：

```markdown
## 1. <chapter-id> — <title>（<N> steps · ~<T>s）

**口播节选**：<narration text>

### Step 1: <step title>
<step content description>
<!-- img: <image description> (optional) -->
```

**解析失败处理**：
- 章节标题不匹配 `## N. <id> — <title>（...）` 格式 → 记录警告，尝试按 `## ` 分割降级解析
- 步骤数缺失 → 默认每章 3 步，警告用户确认
- 口播节选缺失 → 从 script.md 对应段落提取，警告用户

### 2. 视角注入（如 plan.json 指定 perspective）

加载 `skills/perspectives/<name>/SKILL.md`，提取 **Mental Models** 用于指导视觉设计：

- 命名不等于理解 → 用图示替代术语定义（不用文字解释概念，用视觉隐喻）
- 反自欺 → 展示正反两面证据（不只展示支持观点的一面）
- 不确定性是力量 → 用 "?" 标记存疑处（视觉上留白、用问号元素）
- 具体思维 → 物理隐喻优先（用具体物体/场景代替抽象图示）
- 深度游戏 → 允许视觉支线探索（可以有"彩蛋"式视觉元素）

如未指定 perspective，使用中性设计风格。

### 3. 选择主题

从 23 个内置主题中选择 2-3 个推荐，告知用户并等待确认。

**主题推荐逻辑**：
- `register=product` + 知识类 → `paper-press`、`monochrome-print`、`swiss-ikb`
- `register=brand` + 流量类 → `neon-cyber`、`bold-signal`、`creative-voltage`
- 科技类 → `terminal-green`、`blueprint`、`electric-studio`
- 人文类 → `chalk-garden`、`kraft-paper`、`forest-ink`

**23 个主题 ID**：
`midnight-press` / `paper-press` / `warm-keynote` / `newsroom` / `bauhaus-bold` / `chalk-garden` / `terminal-green` / `blueprint` / `dark-botanical` / `neon-cyber` / `bold-signal` / `creative-voltage` / `sunset-zine` / `monochrome-print` / `vintage-editorial` / `pastel-dream` / `split-canvas` / `electric-studio` / `indigo-porcelain` / `forest-ink` / `kraft-paper` / `dune` / `swiss-ikb`

**[Checkpoint: THEME_CONFIRM]** — 展示 2-3 个推荐主题及其视觉特征摘要（色调、字体风格、适用场景），等待用户确认选择。用户可指定列表外的主题 ID。

选定主题后，生成 **11 CSS token 集**（从 4 个基色派生）：

| Token | 来源 | 用途 |
|-------|------|------|
| `--shell` | 基色 | 最外层背景 |
| `--surface` | 基色 | 卡片/面板背景 |
| `--surface-2` | surface x 0.95 | 次级面板 |
| `--surface-3` | surface x 0.9 | 三级面板 |
| `--text` | 基色 | 主文本 |
| `--text-2` | text x 0.85 | 次级文本 |
| `--text-mute` | text x 0.6 | 弱化文本 |
| `--text-faint` | text x 0.4 | 最弱文本 |
| `--accent` | 基色 | 强调色 |
| `--accent-soft` | accent 半透明 | 柔和强调 |
| `--accent-glow` | accent 半透明 | 发光强调 |

**派生示例**（假设 4 基色为 `#1a1a2e` / `#16213e` / `#e0e0e0` / `#0f3460`）：

```css
:root {
  --shell: #1a1a2e;
  --surface: #16213e;
  --surface-2: color-mix(in srgb, #16213e 95%, white);
  --surface-3: color-mix(in srgb, #16213e 90%, white);
  --text: #e0e0e0;
  --text-2: color-mix(in srgb, #e0e0e0 85%, transparent);
  --text-mute: color-mix(in srgb, #e0e0e0 60%, transparent);
  --text-faint: color-mix(in srgb, #e0e0e0 40%, transparent);
  --accent: #0f3460;
  --accent-soft: color-mix(in srgb, #0f3460 50%, transparent);
  --accent-glow: color-mix(in srgb, #0f3460 30%, transparent);
}
```

### 4. Scaffold 项目

> **dry_run 模式**：如 plan.json 中 `dry_run: true`，跳过 scaffold.sh 执行和 npm install，仅输出将要创建的目录结构和文件清单。用于验证项目结构合理性。

调用 scaffold 脚本从模板创建项目：

```bash
bash skills/storyboard/scaffold.sh <workspace-dir> [theme-id]
```

脚本自动完成：

1. 从 `skills/storyboard/skeleton/` 复制项目骨架
2. 安装 npm 依赖
3. 解析 outline.md 提取章节结构
4. 为每章创建目录 + narrations.ts + Chapter.tsx(占位) + Chapter.css
5. 生成 chapters.ts 注册表
6. 注入 main.tsx 的 CSS imports

**不做手动文件创建。** 脚本失败时停下报告用户。

**scaffold 完成验证**：

```bash
# 确认目录结构完整
ls workspace/<id>/storyboard/src/chapters/
# 确认 chapters.ts 有注册
cat workspace/<id>/storyboard/src/chapters.ts
# 确认 TypeScript 编译通过
cd workspace/<id>/storyboard && npx tsc --noEmit
```

输出：`workspace/<id>/storyboard/` — 完整 Vite+React+TS 项目

**启动 Vite 开发服务器**：

```bash
cd workspace/<id>/storyboard && npx vite --host
```

**必须 `cd` 到 storyboard 目录再运行**。在 repo 根目录运行 `npx vite` 会启动其他项目的服务器，导致页面空白或内容错误。端口被占用时 Vite 会自动递增（5173 -> 5174...），注意检查实际输出的端口号。

### 4.5 生成图片资产（条件触发）

**触发条件**：outline.md 中包含 `<!-- img: 描述 -->` 标记时必须执行此步骤。无标记则跳过。

如 outline.md 中包含图片描述标记（`<!-- img: 描述 -->`），自动生成图片：

```bash
bash tools/generate-images.sh <workspace-dir>
```

脚本自动完成：

1. 扫描 `distill/outline.md` 中的 `<!-- img: 描述 -->` 标记
2. 输出图片清单到 stdout，等待确认
3. 调用图片生成工具生成每张图片
4. 输出到 `storyboard/public/img/<chapter>/<step>.jpg`

**降级处理**：

- 图片生成工具不可用 → 跳过图片生成，使用纯文本/卡片布局
- 单张图片失败 → 记录警告，继续生成其他图片
- 全部失败 → 警告用户，继续使用占位卡片

**配额耗尽降级**：

- 图片生成返回配额耗尽错误 → 立即停止生成，已生成的图片保留，未生成的使用占位卡片
- 提示用户剩余图片数量，建议次日重试或使用 `--dry-run` 规划配额分配
- BGM 生成配额耗尽 → 视频正常渲染，仅无背景音乐

**[Checkpoint: IMAGE_PREVIEW]** — 图片生成后，展示首张图片预览供用户确认质量。提供选项："确认通过" / "重新生成部分" / "跳过图片继续"。收到确认后继续。

### 5. Chapter 1 主线程锚点

**Chapter 1 必须在主线程完成，不可派发给 subagent。**

实现 Chapter 1 的完整代码：

**narrations.ts**（单一信源）：
```typescript
export const narrations = [
  "第一句口播文本",
  "第二句口播文本",
  "第三句口播文本",
];
// narrations.length 必须 === Chapter.tsx 中最大 step + 1
```

**narrations.ts 验证规则**：
- 数组元素必须为非空字符串
- 每个元素对应 script.md 中的一个节拍
- 数组长度必须与 outline.md 中该章步骤数一致
- 禁止使用模板占位符（如 "TODO"、"..."）

**Chapter.tsx**（纯函数 of step）：
```tsx
import { narrations } from './narrations';

interface ChapterProps {
  step: number;
}

export function Chapter01({ step }: ChapterProps) {
  // 每步独占整屏
  if (step === 0) return <div className="cd-stage">...</div>;
  if (step === 1) return <div className="cd-stage">...</div>;
  if (step === 2) return <div className="cd-stage">...</div>;
  return null;
}
```

**Chapter.tsx 组件约束**：
- 组件必须是纯函数，仅依赖 `step` prop
- 每个 `step === N` 分支返回一个完整的 1920x1080 舞台
- 最后必须有 `return null` 兜底（step 超出范围时）
- 禁止使用 `useState`、`useEffect` 等副作用 hook
- 禁止使用 `setTimeout`、`setInterval`
- 交互元素需要 `data-no-advance` 属性防止误触推进

**Chapter.css**（使用 token）：
```css
.cd-stage {
  width: 1920px;
  height: 1080px;
  background: var(--shell);
  color: var(--text);
  font-family: var(--font-display-cn);
  /* 80px 安全区 */
  padding: 80px;
}
```

**Chapter 1 自检清单**（14 项，完成后逐项确认）：

| # | 检查项 | 验证方式 |
|---|--------|---------|
| 1 | 有视觉演示元素（非纯文字） | 检查是否有 img/SVG/CSS 动画 |
| 2 | 动画类型有变化（非每步相同） | 对比各 step 的入场动画 |
| 3 | 文字够大（>=80px hero）+ 留白充足 | 检查 CSS font-size 和 padding |
| 4 | 列表项逐个揭示 | 检查 step 间的内容增量 |
| 5 | 屏幕信息密度 > 口播 | 对比视觉元素数与 narrations 字数 |
| 6 | 无 AI 视觉指纹 | 检查禁止列表（见原则 7） |
| 7 | 所有 token 正确使用 | grep 硬编码颜色/字体 |
| 8 | narrations.ts 存在且长度匹配 | `narrations.length === max(step) + 1` |
| 9 | 动画时长 <= 口播时长 | 对比 animation-duration 与 narration 时长 |
| 10 | `npx tsc --noEmit` 通过 | 运行命令确认 |
| 11 | 16:9 固定舞台 | 确认 1920x1080 |
| 12 | 全局 step 驱动（无定时器） | grep setTimeout/setInterval |
| 13 | 物理隔离（独立 CSS 前缀） | 确认前缀唯一 |
| 14 | 无硬编码颜色/字体 | grep hex/rgb/font-family |

**[Checkpoint: STORYBOARD_PREVIEW]** — 展示 Chapter 1 渲染预览 + 口播前 30 秒。展示预览截图或链接，提供选项："验收通过" / "修改风格" / "换视角" / "重新生成"。**必须收到用户明确确认才可继续 Chapter 2~N。**

### 6. Chapter 2~N 开发

按 `execution_mode` 执行：

| 模式 | 行为 |
|------|------|
| **A（默认）** | 每章完成后暂停，展示预览，等用户确认 |
| **B** | Chapter 1 验收后顺序做完，最后统一验收 |
| **C** | Chapter 1 验收后并行派发 subagent |

**Mode A 每章检查点**：每章完成后展示渲染预览，等待用户确认后继续下一章。

**Mode C 并行 subagent prompt 要求**：
- 当前章节的 outline 段落
- CHAPTER-CRAFT.md 的 10 原则（见下方 Step 7）
- 主题 theme.json 元数据
- Chapter 1 代码作为风格参考
- 硬规则：独立 CSS 前缀、不可修改 chapters.ts、完成后运行 `npx tsc --noEmit`

### 7. 每章实现规范（CHAPTER-CRAFT 10 原则）

**原则 1：这是视频，不是 PPT**
- 无页眉/页脚，舒适的颜色/字体/节奏，需要视觉冲击力

**原则 2：必须有视觉演示元素**

- 每章必须有 1-2 个视觉演示元素
- 优先级：生成图片 > CSS/SVG 动画 > 占位卡片
- 如有生成的图片（`public/img/`），优先使用 `<img>` 而非纯 CSS 占位
- 纯文字章节 = 不合格

**原则 3：渐进揭示，永不一次展示**
- 全局 step 驱动
- 列表项逐个揭示（第一、第二、第三 -> 每个 = 一步）
- 新项高亮，旧项变灰

**原则 4：内容精选，不逐字复制**
- 每步屏幕只展示 1-3 个最有冲击力的元素
- 屏幕信息密度 > 口播信息密度

**原则 5：双源**
- 节奏来自 script.md
- 视觉细节来自 article.md 的信息池

**原则 6：排版/色彩/动画/留白**
- Hero 文字 >=80px
- 四周留白 >=80px 安全区
- 颜色和字体**必须使用 theme token**
- 动画干净有力（设计驱动，非速度驱动）

**原则 7：避免 AI 视觉指纹**
禁止：
- 紫粉斜渐变
- 圆角卡片 + 彩色左边框
- 渐变按钮 + 药丸形状
- Emoji 做图标
- 假数据/假 logo/"X0K users"
- 所有步骤用相同入场动画
- 每步都用 ken burns/发光呼吸/持续闪烁
- 每屏都有角落徽章

**原则 8：框架基础设施（理解，不重写）**
- 16:9 固定舞台：1920x1080 + transform scale，无响应式断点
- 居中舞台 + 80px 安全区
- 隐藏进度条（hover 时显示在底部）
- 全局 step 驱动导航（点击空白 / 方向键，无定时器）

**原则 9：代码层约束**
- 颜色和字体**必须通过 CSS 自定义属性**访问：
  - `--shell`, `--surface`, `--surface-2`, `--surface-3`
  - `--text`, `--text-2`, `--text-mute`, `--text-faint`
  - `--accent`, `--accent-soft`, `--accent-glow`
  - `--font-display-cn`, `--font-display-en`, `--font-body`, `--font-mono`
- **禁止硬编码** hex/rgb/颜色名/字体名
- 字号、间距、动画时长、边框宽度、gap/grid 可硬编码
- 动画**必须用 CSS @keyframes**，禁止 `setTimeout`/`setInterval`
- 交互元素需要 `data-no-advance` 属性
- 每章物理隔离：独立文件夹 + 独立 CSS 前缀（如 `.cd-`、`.mg-`）
- 每章必须有 `narrations.ts`，数组长度 = 最大 step + 1

**原则 10：每章完成后必须自检**（14 项，同 Chapter 1 自检清单）

### 8. 写 chapters.ts

注册所有章节：

```typescript
import { Chapter01 } from './chapters/01-what/Chapter';
import { Chapter02 } from './chapters/02-how/Chapter';
import { Chapter03 } from './chapters/03-why/Chapter';

export const chapters = [
  { id: '01-what', Component: Chapter01, stepCount: 3 },
  { id: '02-how', Component: Chapter02, stepCount: 2 },
  { id: '03-why', Component: Chapter03, stepCount: 2 },
];
```

**chapters.ts 验证**：
- `stepCount` 必须等于对应 narrations.ts 的数组长度
- 每个 Chapter 组件必须已实现（非占位）
- import 路径必须与目录结构一致

### 9. 反模式检查 + 确定性检测

**视觉反模式**：

| 规则 | 检测 | 修复 |
|------|------|------|
| CH-001 | 模板化开场视觉（紫粉渐变/圆角彩色边框/emoji 当图标） | 用视角 Mental Models 重新设计 |
| CH-002 | 视觉结构词堆砌（每步相同入场动画/全场 fade） | 替换为非线性视觉叙事 |
| CH-003 | 信息密度无起伏（每步视觉元素数偏差 <10%） | 制造视觉节奏变化 |
| CH-004 | 总结式结尾画面（大号"谢谢"/进度条终点） | 用视角启发式设计结尾 |
| CH-005 | 视觉风格单一（全章同一种入场动画） | 注入视角的视觉多样性 |
| CH-006 | 套话过渡画面（"接下来"/分隔页/渐变条） | 删除，用内容逻辑隐性衔接 |

**确定性检测命令**：

```bash
python -m tools.audit <workspace-dir>
```

Agent 自检完成后，建议用户运行审计工具做二次验证。

## Output

- `workspace/<id>/storyboard/` — 完整 Vite+React+TS 项目
- `workspace/<id>/storyboard/src/chapters/<NN>-<id>/narrations.ts` — 单一信源
- `workspace/<id>/storyboard/src/chapters/<NN>-<id>/Chapter.tsx` — 章节组件
- `workspace/<id>/storyboard/src/chapters/<NN>-<id>/Chapter.css` — 章节样式
- `workspace/<id>/storyboard/src/theme.css` — 11 token 定义
- `workspace/<id>/storyboard/src/chapters.ts` — 章节注册表

## Resources

| 文件 | 用途 |
|------|------|
| `skills/storyboard/scaffold.sh` | 项目脚手架脚本 |
| `skills/storyboard/skeleton/` | Vite+React+TS 模板 |
| `skills/storyboard/test-prompts.json` | 测试用例 |
| `skills/perspectives/<name>/SKILL.md` | 视角 Mental Models |
| `distill/outline.md` | 章节大纲（输入） |
| `distill/script.md` | 口播脚本（输入） |
| `tools/generate-images.sh` | 图片生成脚本 |
| `tools/audit` | 反模式确定性检测 |

## Failure Modes

| 场景 | 回退 |
|------|------|
| plan.json 缺失必需字段 | 阻断，提示用户重新运行 using-recastory 生成 plan.json |
| outline.md 格式无法解析 | 尝试降级解析（按 `## ` 分割），仍失败则阻断要求修复格式 |
| outline.md 无章节 | 阻断，提示 outline.md 缺少章节目录 |
| scaffold.sh 不存在 | 阻断，报告："scaffold.sh 缺失，请检查 skills/storyboard/ 目录" |
| npm install 失败 | 检查网络和 package.json，重试一次；仍失败则阻断报告用户 |
| npm install 超时（>120s） | 检查网络，重试一次；仍超时则阻断 |
| 主题文件不存在 | 使用默认 token 集，警告用户 |
| theme-id 不在 23 个内置主题中 | 展示完整主题列表，让用户选择 |
| Vite scaffold 失败 | 手动创建目录结构，报告具体错误 |
| Vite 端口被占用 | Vite 自动递增端口，注意检查输出的端口号 |
| Chapter 1 用户不满意 | 修改后重新展示，直到验收 |
| `npx tsc --noEmit` 失败 | 修复类型错误后才可继续 |
| generate-images.sh 不存在 | 跳过图片生成，使用纯文本/卡片布局 |
| workspace 目录无写入权限 | 阻断，提示用户检查目录权限 |
| node_modules 损坏 | 删除 node_modules 后重新 npm install |

## dry_run 模式

当 `plan.json` 中 `dry_run: true` 时：

1. **跳过** scaffold.sh 执行和 npm install
2. **跳过** 图片生成
3. **输出** 将要创建的目录结构和文件清单
4. **输出** 章节列表及步骤数
5. **输出** 主题选择建议
6. **不启动** Vite 开发服务器

用于验证项目结构合理性和配额规划，不产生实际文件。

## Test Scenarios

基于 `test-prompts.json` 的典型执行验证：

| 场景 | 输入 | 预期输出 |
|------|------|---------|
| 基础生成 | outline.md 第一章 | Chapter.tsx + Chapter.css + narrations.ts，使用 CSS token，16:9 舞台，step 驱动 |
| 反模式检测 | 生成后的 Chapter.tsx | 无紫粉渐变/圆角彩色边框/emoji/全场 fade/套话过渡 |
| 主题应用 | midnight-press 主题 | 深色调、电影感、衬线斜体 hero |
| dry_run | plan.json dry_run:true | 仅输出文件清单，无实际创建 |
| 降级处理 | 无图片生成工具 | 纯文本/卡片布局，无报错 |
