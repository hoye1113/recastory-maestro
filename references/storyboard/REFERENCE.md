# references/storyboard/REFERENCE.md — 分镜参考

> storyboard SKILL.md 执行时加载本文件。提供主题列表、CSS token、布局规范。

---

## 23 主题速查表

| id | 色调 | 性格标签 |
|---|---|---|
| `midnight-press` | 深 | 电影感编辑级，暖 espresso + 火热橙，衬线斜体 hero |
| `chalk-garden` | 深 | 深石板黑板，手写字体，粉笔黄，2px 虚线 rule |
| `terminal-green` | 深 | 80 年代磷光终端，JetBrains Mono，CRT 扫描线 |
| `blueprint` | 深 | 工程蓝图，深海军蓝 + 绘图青，60px 制图网格 |
| `dark-botanical` | 深 | 高级感暗底，时尚刊物/博物馆，柔光晕染 |
| `neon-cyber` | 深 | 赛博朋克，电光青 + 玫红双霓虹，发光网格 |
| `bold-signal` | 深 | hero pitch-deck，Archivo Black，对角线渐变 |
| `creative-voltage` | 深 | 复古朋克创意，饱和电光蓝底 + 霓虹黄，halftone 网点 |
| `paper-press` | 浅 | midnight-press 白天孪生，暖奶油纸纹，火热橙 |
| `warm-keynote` | 浅 | 现代 SaaS keynote，大圆角 glass slab，弹簧动效 |
| `newsroom` | 浅 | NYT 报刊，报纸奶油 + 墨黑衬线 + 旗红，0 圆角 |
| `bauhaus-bold` | 浅 | 现代主义宣言，米白 + 墨黑 + 原色蓝，4px 厚边 |
| `sunset-zine` | 浅 | 独立 risograph zine，暖桃 + 洋红，虚线剪贴线 |
| `monochrome-print` | 浅 | 安静印刷杂志，米白 + 墨黑衬线，1px 发丝 |
| `vintage-editorial` | 浅 | 俏皮编辑奶油底，Fraunces italic，细线几何叠层 |
| `pastel-dream` | 浅 | 友好柔光，柔粉蓝灰，大圆角 + 多色 pill 色条 |
| `split-canvas` | 浅 | 双拼画布，蜜桃 + 薰衣草 50/50 硬切分 |
| `electric-studio` | 浅 | 企业电光蓝，净白底 + 单一电光蓝，贴底 4px 蓝条 |
| `indigo-porcelain` | 浅 | 靛蓝瓷，靛蓝当墨 + 瓷白纸，学术/研究气质 |
| `forest-ink` | 浅 | 森林墨，森林绿当墨 + 象牙暖纸，文献感 |
| `kraft-paper` | 浅 | 牛皮纸，深棕当墨 + 牛皮米，粗暖纸纹 |
| `dune` | 浅 | 沙丘，炭褐当墨 + 沙底，极宽 padding，建筑手册感 |
| `swiss-ikb` | 浅 | 瑞士国际主义，极细 200w Inter，IKB 克莱因蓝 |

---

## CSS Token 契约

### 必填 token（主题必须定义）

| 类别 | token | 作用 |
|---|---|---|
| 表面色 | `--shell` | letterbox / 舞台外背景 |
| | `--surface` | 舞台主背景 |
| | `--surface-2` | 卡片、代码块、嵌入面板 |
| | `--surface-3` | 最里层嵌套 |
| 文字 | `--text` | 主文字 |
| | `--text-2` | 次文字（副标题、正文） |
| | `--text-mute` | 标签 / 元数据 |
| | `--text-faint` | 提示 / 禁用 |
| 线条 | `--rule` | 发丝分割线颜色 |
| Accent | `--accent` | 品牌强色（唯一饱和色） |
| | `--accent-soft` | 低透明度叠层 |
| | `--accent-glow` | 中透明度叠层 |
| 字型 | `--font-display-cn` | 中文显示家族 |
| | `--font-display-en` | 拉丁显示家族 |
| | `--font-body` | 正文/段落家族 |
| | `--font-mono` | 等宽家族 |

### 可选性格覆盖（base.css 有默认值，主题按性格重定义）

| token | base 默认 | 作用 |
|---|---|---|
| `--r-card` | `--r-md` | 卡片圆角 (0/4/16/32) |
| `--r-stage` | `0` | 舞台圆角 |
| `--rule-w` | `1px` | rule 粗细 |
| `--rule-style` | `solid` | rule 样式 (solid/dashed/dotted) |
| `--hero-num-font` | `--font-display-en` | hero 数字字体 |
| `--hero-num-style` | `italic` | italic / normal |
| `--hero-num-weight` | `400` | 400/500/900 |
| `--stage-pad-x` | `96px` | 舞台横向内边距 |
| `--stage-pad-y` | `80px` | 舞台纵向内边距 |
| `--card-shadow` | none | 卡片阴影 |
| `--shadow-stage` | dark drop | 舞台阴影 |
| `--surface-pattern` | none | 舞台背景图案 |
| `--surface-vignette` | none | vignette 渐变 |
| `--text-shadow` | none | 文字特效 |

---

## 布局规范

- 固定 **1920 x 1080**，外层 transform scale 缩放，letterbox 留黑
- **无响应式断点**，不做移动端适配
- 安全区：四边 >= **80px** 留白（精炼主题 140x100，密集主题 80x60）
- 舞台居中，外围纯黑/纯色 letterbox

---

## CHAPTER-CRAFT 10 原则

| # | 原则 | 一句话摘要 |
|---|---|---|
| 1 | 视频不是 PPT | 不像翻页幻灯，无页眉页脚，突出主视觉 |
| 2 | 必须有视觉演示 | 每章 >= 1~2 处 CSS/SVG/Canvas/JS 动态元素 |
| 3 | 逐步揭示 | 1 项 = 1 step，清单逐个亮起，禁止一次 stagger 全部 |
| 4 | 内容抓重点 | 每 step 只放 1~3 个最值得放大的东西 |
| 5 | 双源对照 | 节奏跟 script.md，细节回 article.md 抽 |
| 6 | 字号大留白多 | hero >= 80px，配色用 token，动画干净利落 |
| 7 | 避免 AI 味 | 无紫粉渐变/圆角彩色边框/emoji/假数据 |
| 8 | 代码最小约束 | 颜色+字体必须用 token，字号/间距/时长自由 |
| 9 | 章节物理隔离 | 独立文件夹、独立 CSS 类前缀，不跨章 import |
| 10 | 完工自检 | 必须逐项核查后才能汇报完成 |

---

## 动画约束 + 无障碍

- 每页动画种类 <= **3 种**
- 动画仅用 **CSS keyframes**，禁用 setTimeout/setInterval
- 动画时长 <= 该 step 口播时长（口播字数 / 4 = 秒数）
- 文字与背景对比度 >= **4.5:1**（96px+ 标题可放宽至 3:1）
- 交互元素加 `data-no-advance` 防误触推进 step
- 主题 `mood` 约束节奏气质（慢主题别写 200ms 快动画）

---

## 反模式速查

### 分镜反模式 (SB)

| ID | 反模式 |
|---|---|
| SB-001 | 单页文字 >80 字 |
| SB-002 | 使用默认主题（未匹配内容类型） |
| SB-003 | 配色对比度 <4.5:1 |
| SB-004 | 动画效果 >3 种/页 |
| SB-005 | 图片与文字无关（占位图未替换） |

### 章节层 (CHAPTER-CRAFT.md)

| ID | 反模式 |
|---|---|
| CH-001 | 整章纯文字无视觉演示 |
| CH-002 | 清单/列表一个 step 全部 stagger 上来 |
| CH-003 | 紫粉渐变 / 圆角彩色边框 / emoji 当图标 |
| CH-004 | 假数据 / 假 logo / 假"X 万用户" |
| CH-005 | 全章同一种入场动画（全场 fade / 全场 blur） |
| CH-006 | 每步都挂 ken burns / 光晕呼吸 / 持续闪烁 |

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
| ------ | ------ |
| 章节过渡（2-3s） | 适合 |
| 场景插图（配合口播） | 适合 |
| 片头/片尾动效 | 适合 |
| 完整叙事视频 | 不适合（时长限制） |
| 替代录屏 | 不适合 |

#### 视频降级策略

| 场景 | 处理 |
|------|------|
| mmx-cli 未安装 | 跳过视频生成 |
| mmx auth 失败 | 跳过视频生成 |
| 生成超时（>5min） | 记录警告，继续 |
| 单个视频失败 | 记录警告，继续 |
