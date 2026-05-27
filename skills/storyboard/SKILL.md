---
name: storyboard
version: 1.0.0
description: 从 outline.md 生成 Vite+React+TS 幻灯片项目，含 narrations.ts 单一信源、23 主题、逐章开发。触发条件：/recastory storyboard 或被 using-recastory 调度。
---

# Skill: storyboard

## IRON LAW

**narrations.ts 是步骤数和口播文本的唯一信源。Chapter.tsx 中最大 `step === N` + 1 必须等于 `narrations.length`。5 个位置必须同步：script / outline / chapter code / chapters.ts / audio 文件。**

## Purpose

将 outline.md 转化为可运行的 Vite+React+TS 幻灯片项目，每步独占整屏，点击推进节拍。

## Preconditions

- `plan.json` 已存在
- `distill/outline.md` 已存在
- `distill/script.md` 已存在（用于 narrations.ts 口播文本）
- 如指定 `--perspective`，对应视角 SKILL.md 可用

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

### 2. 视角注入（如 plan.json 指定 perspective）

调用 `Skill` 工具加载 `perspectives/<name>`。

从 SKILL.md 提取 **Mental Models**，用于指导视觉设计：
- 命名≠理解 → 用图示替代术语定义（不用文字解释概念，用视觉隐喻）
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

选定主题后，生成 **11 CSS token 集**（从 4 个基色派生）：

| Token | 来源 | 用途 |
|-------|------|------|
| `--shell` | 基色 | 最外层背景 |
| `--surface` | 基色 | 卡片/面板背景 |
| `--surface-2` | surface × 0.95 | 次级面板 |
| `--surface-3` | surface × 0.9 | 三级面板 |
| `--text` | 基色 | 主文本 |
| `--text-2` | text × 0.85 | 次级文本 |
| `--text-mute` | text × 0.6 | 弱化文本 |
| `--text-faint` | text × 0.4 | 最弱文本 |
| `--accent` | 基色 | 强调色 |
| `--accent-soft` | accent 半透明 | 柔和强调 |
| `--accent-glow` | accent 半透明 | 发光强调 |

### 4. Scaffold 项目

创建 Vite+React+TS 项目结构：

```
workspace/<id>/storyboard/
├── index.html
├── package.json
├── tsconfig.json
├── vite.config.ts
├── src/
│   ├── App.tsx            ← 主入口，管理全局 step
│   ├── App.css
│   ├── chapters.ts        ← 章节注册表
│   ├── chapters/
│   │   ├── 01-<id>/
│   │   │   ├── Chapter.tsx
│   │   │   ├── Chapter.css
│   │   │   └── narrations.ts
│   │   └── 02-<id>/
│   │       ├── Chapter.tsx
│   │       ├── Chapter.css
│   │       └── narrations.ts
│   └── theme.css          ← 11 token 定义
└── public/
    └── audio/             ← voice 输出目录（如有）
```

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

**[Checkpoint: STORYBOARD_PREVIEW]** — 展示 Chapter 1 渲染预览 + 口播前 30 秒，等待用户验收。

### 6. Chapter 2~N 开发

按 `execution_mode` 执行：

| 模式 | 行为 |
|------|------|
| **A（默认）** | 每章完成后暂停，展示预览，等用户确认 |
| **B** | Chapter 1 验收后顺序做完，最后统一验收 |
| **C** | Chapter 1 验收后并行派发 subagent |

**Mode C 并行 subagent prompt 要求**：
- 当前章节的 outline 段落
- CHAPTER-CRAFT.md 的 10 原则
- 主题 theme.json 元数据
- Chapter 1 代码作为风格参考
- 硬规则：独立 CSS 前缀、不可修改 chapters.ts、完成后运行 `npx tsc --noEmit`

### 7. 每章实现规范（CHAPTER-CRAFT 10 原则）

**原则 1：这是视频，不是 PPT**
- 无页眉/页脚，舒适的颜色/字体/节奏，需要视觉冲击力

**原则 2：必须有视觉演示元素**
- 每章必须有 1-2 个动画/演示元素
- 纯文字章节 = 不合格

**原则 3：渐进揭示，永不一次展示**
- 全局 step 驱动
- 列表项逐个揭示（第一、第二、第三 → 每个 = 一步）
- 新项高亮，旧项变灰

**原则 4：内容精选，不逐字复制**
- 每步屏幕只展示 1-3 个最有冲击力的元素
- 屏幕信息密度 > 口播信息密度

**原则 5：双源**
- 节奏来自 script.md
- 视觉细节来自 article.md 的信息池

**原则 6：排版/色彩/动画/留白**
- Hero 文字 ≥80px
- 四周留白 ≥80px 安全区
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
- 16:9 固定舞台：1920×1080 + transform scale，无响应式断点
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

**原则 10：每章完成后必须自检**（14 项）
1. 有视觉演示元素（非纯文字）
2. 动画类型有变化（非每步相同）
3. 文字够大（≥80px hero）+ 留白充足
4. 列表项逐个揭示
5. 屏幕信息密度 > 口播
6. 无 AI 视觉指纹
7. 所有 token 正确使用
8. narrations.ts 存在且长度匹配
9. 动画时长 ≤ 口播时长
10. `npx tsc --noEmit` 通过
11. 16:9 固定舞台
12. 全局 step 驱动（无定时器）
13. 物理隔离（独立 CSS 前缀）
14. 无硬编码颜色/字体

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

### 9. 反模式检查

**分镜反模式**：

| 规则 | 检测 | 修复 |
|------|------|------|
| SB-001 | narrations.ts 与 outline 步骤数不一致 | 对齐步骤数 |
| SB-002 | Chapter.tsx 硬编码口播文本 | 改为从 narrations.ts 导入 |
| SB-003 | 单页动画 >3 种 | 精简为 1-2 种 |
| SB-004 | 非 16:9 舞台 | 强制 1920×1080 |
| SB-005 | 缺少全局步骤计数器 | 添加 step 驱动逻辑 |

**AI Slop 反模式**：

| 规则 | 检测 | 修复 |
|------|------|------|
| SL-001 | 模板化开场视觉（紫粉渐变/圆角彩色边框/emoji 当图标） | 用视角 Mental Models 重新设计 |
| SL-002 | 视觉结构词堆砌（每步相同入场动画/全场 fade） | 替换为非线性视觉叙事 |
| SL-003 | 信息密度无起伏（每步视觉元素数偏差 <10%） | 制造视觉节奏变化 |
| SL-004 | 总结式结尾画面（大号"谢谢"/进度条终点） | 用视角启发式设计结尾 |
| SL-005 | 视觉风格单一（全章同一种入场动画） | 注入视角的视觉多样性 |
| SL-006 | 套话过渡画面（"接下来"/分隔页/渐变条） | 删除，用内容逻辑隐性衔接 |

## Output

- `workspace/<id>/storyboard/` — 完整 Vite+React+TS 项目
- `workspace/<id>/storyboard/src/chapters/<NN>-<id>/narrations.ts` — 单一信源
- `workspace/<id>/storyboard/src/chapters/<NN>-<id>/Chapter.tsx` — 章节组件
- `workspace/<id>/storyboard/src/chapters/<NN>-<id>/Chapter.css` — 章节样式
- `workspace/<id>/storyboard/src/theme.css` — 11 token 定义
- `workspace/<id>/storyboard/src/chapters.ts` — 章节注册表

## Anti-Patterns

| ID | 名称 | 检测 | 严重度 |
|----|------|------|--------|
| SB-001 | 步骤数不一致 | narrations.length ≠ outline 步骤数 | critical |
| SB-002 | 硬编码口播 | Chapter.tsx 内联文字而非导入 narrations | critical |
| SB-003 | 动画过载 | 单页 >3 种动画 | warning |
| SB-004 | 舞台错误 | 非 1920×1080 | critical |
| SB-005 | 无 step 驱动 | 使用 setTimeout/setInterval | critical |

## Failure Modes

| 场景 | 回退 |
|------|------|
| outline.md 格式无法解析 | 阻断，要求修复格式 |
| 主题文件不存在 | 使用默认 token 集，警告用户 |
| Vite scaffold 失败 | 手动创建目录结构 |
| Chapter 1 用户不满意 | 修改后重新展示，直到验收 |
| `npx tsc --noEmit` 失败 | 修复类型错误后才可继续 |
