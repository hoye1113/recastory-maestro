# brand/REGISTER.md — 品牌/产品注册表

> 用户配置文件。定义内容的注册表类型和品牌偏好。所有涉及设计决策的命令最后加载本文件。

---

## 注册表类型

```yaml
type: product  # "brand" 或 "product"
```

- **brand**（品牌）：营销视频、品牌宣传片、产品发布、创意短片 — 设计就是产品本身
- **product**（产品）：教程、课程、技术讲解、数据报告 — 设计服务于内容

## 品牌配置（可选）

```yaml
brand:
  name: "可乐米花园"
  primary_color: "#2563EB"
  accent_color: "#F59E0B"
  font_heading: "Inter"
  font_body: "Noto Sans SC"
  tone: "专业但不枯燥，偶尔幽默"
```

## 内容偏好

```yaml
preferences:
  default_style: tech           # tech / science / explainer / business / casual
  default_format: short-video   # short-video / course / podcast / keynote
  default_voice: "zh-CN-001"   # TTS 音色 ID
  default_perspective: feynman  # 默认视角
  language: zh                  # zh / en
```

## 反模式豁免

```yaml
anti_patterns:
  disabled: []                  # 禁用的规则 ID（如 ["SL-006"] 表示允许显性过渡句）
  custom_rules: []              # 用户自定义规则
```

---

## 使用说明

1. 复制本文件到你的项目目录
2. 修改 `type` 字段为 `brand` 或 `product`
3. 按需填写品牌配置和内容偏好
4. Agent 执行命令时会自动加载本文件，覆盖默认值
