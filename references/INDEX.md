# references/INDEX.md — 参考文件注册表

> Progressive Loading 的注册表。Agent 执行命令时按本索引加载对应参考文件。

---

## 全局加载（所有命令都加载）

| 文件 | 用途 | 必须 |
|------|------|------|
| `transcription/REFERENCE.md` | 标点规范、说话人标注、时间戳格式 | ✅ |
| `content-distillation/REFERENCE.md` | 大纲结构、信息密度、叙事弧线 | ✅ |

## 按命令加载

| 命令 | 触发加载 | 可选加载 |
|------|---------|---------|
| `/recastory craft` | `storyboard/REFERENCE.md`, `voice/REFERENCE.md`, `render/REFERENCE.md` | `storyboard/themes/`, `skills/web-video-presentation/SKILL.md`, `skills/perspectives/<name>/SKILL.md`（视角解析时，不存在时回退 `skills/nuwa-skill/examples/<name>-perspective/SKILL.md`） |
| `/recastory storyboard` | `storyboard/REFERENCE.md` | `storyboard/themes/`, `skills/web-video-presentation/SKILL.md`, `skills/perspectives/<name>/SKILL.md`（视角解析时，不存在时回退 `skills/nuwa-skill/examples/<name>-perspective/SKILL.md`） |
| `/recastory voice` | `voice/REFERENCE.md` | — |
| `/recastory render` | `render/REFERENCE.md` | — |
| `/recastory transcribe` | —（全局已覆盖）| — |
| `/recastory distill` | —（全局已覆盖）| `skills/humanizer-zh/SKILL.md`（深度去 AI 味）, `skills/perspectives/<name>/SKILL.md`（视角解析时，不存在时回退 `skills/nuwa-skill/examples/<name>-perspective/SKILL.md`） |
| `/recastory research` | `research/REFERENCE.md` | — |
| `/recastory audit` | —（使用 anti-patterns.ts）| — |
| `/recastory critique` | —（LLM 审查，无需参考文件）| — |

## 品牌覆盖（最后加载）

| 文件 | 用途 | 触发条件 |
|------|------|---------|
| `brand/REGISTER.md` | 用户品牌/产品配置，覆盖默认值 | 所有涉及设计决策的命令 |

## 加载顺序

```
1. 全局参考文件（transcription/ + content-distillation/）
2. 命令对应的领域参考文件
3. 视角 Expression DNA（如指定 --perspective）
4. 品牌注册表（brand/REGISTER.md，最后加载）
```

## 文件大小约束

- 单个 REFERENCE.md 不超过 3000 tokens
- 如超过，使用摘要版本（`REFERENCE-SUMMARY.md`），完整版按需加载
