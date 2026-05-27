# Recastory 视角引擎（Perspective Engine）

> 通过提取特定人物的**认知操作系统**注入创造力，非角色扮演。Maestro 主入口见 [AGENT.md](AGENT.md)。

---

## 什么是视角引擎

视角引擎不是"用鲁迅风格写"这种表层模仿，而是提取某个人的**思维模型、决策启发式、表达 DNA**。每个视角定义了 HOW someone thinks，而非 WHAT they said。

---

## 内置视角库

> **MVP 仅实现 Feynman + MrBeast**，其余 6 个标记为 `contributions welcome`。

### MVP 视角（已实现）

| 视角 | 核心思维模型 | 适用内容类型 | 表达特征 |
|------|------------|-------------|---------|
| **Feynman** | 反自欺、cargo cult 检测 | 科普、原理解释 | 口语化、从具体到抽象、自嘲式幽默 |
| **MrBeast** | CTR×AVD 方程、零无聊时刻、阶梯升级 | 短视频、娱乐内容 | 极度具体、零铺垫、每句制造悬念 |

### 未来视角（contributions welcome）

| 视角 | 核心思维模型 | 适用内容类型 | 表达特征 |
|------|------------|-------------|---------|
| **Musk** | 渐近极限思维、五步算法 | 科技解读、产品分析 | 宣言式、数字先行、实时成本拆解 |
| **Munger** | 多元思维模型格栅、反向思考 | 商业分析、投资洞察 | 跨学科类比、反直觉切入 |
| **Naval** | 欲望即痛苦契约、特定知识 | 哲学思考、创业心法 | 箴言式、极简、格言体 |
| **Jobs** | 现实扭曲力场、体验至上 | 产品发布、设计理念 | 戏剧化、极简主义、情感共鸣 |
| **Graham** | 黑天鹅式创业、做不可扩展的事 | 创业方法论 | 随笔式、举例论证、朴素直接 |
| **Karpathy** | 神经直觉、从零实现 | AI/ML 技术解读 | 代码先行、可视化、渐进复杂度 |

---

## 视角 Skill 结构

```
perspective/
├── SKILL.md              # 视角定义（YAML frontmatter + 完整规范）
├── references/
│   ├── 01-writings.md    # 原始著作/演讲
│   ├── 02-interviews.md  # 访谈记录
│   ├── 03-decisions.md   # 关键决策案例
│   ├── 04-critics.md     # 他人评价
│   ├── 05-patterns.md    # 行为模式提取
│   └── 06-timeline.md    # 人生时间线
```

---

## 视角在流水线中的注入点

| 阶段 | 注入方式 | 效果 |
|------|---------|------|
| `/recastory distill` | 选择视角的 Expression DNA 生成口播稿 | 脚本风格差异化 |
| `/recastory storyboard` | 选择视角的 Mental Models 决定叙事结构 | 故事架构差异化 |
| `/recastory critique` | 用视角的 Decision Heuristics 审查内容 | 审查维度差异化 |
| `/recastory research` | 用视角的研究维度指导深度分析 | 研究角度差异化 |

---

## 使用示例

```bash
/recastory craft video.mp4 --perspective feynman
# → 用费曼的认知操作系统重铸内容：从具体例子出发、口语化、反 cargo cult

/recastory distill article.md --perspective mrbeast
# → 用 MrBeast 的注意力工程框架重写脚本：零无聊、阶梯升级、前置极端元素

/recastory critique output/ --perspective munger
# → 用芒格的多元思维模型审查：反向思考、激励分析、跨学科类比
```

---

## 注册表与视角的关系

注册表（Brand/Product）和视角（Perspective）是两个独立维度，可以自由组合：

| 组合 | 效果 |
|------|------|
| `--register brand --perspective mrbeast` | 品牌宣传 + MrBeast 的注意力工程 = 高冲击力营销视频 |
| `--register product --perspective feynman` | 教程 + 费曼的反自欺 = 清晰易懂的技术讲解 |
| `--register brand --perspective jobs` | 品牌 + 乔布斯的戏剧化 = 产品发布会风格 |
| `--register product --perspective karpathy` | 教程 + Karpathy 的代码先行 = 深度技术教程 |

**优先级规则**：当注册表和视角在某个设计决策上冲突时，视角优先（因为视角更具体），但注册表的约束（如 Brand 允许大胆配色、Product 要求克制）仍然生效。
