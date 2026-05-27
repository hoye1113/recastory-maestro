# references/voice/REFERENCE.md — TTS 合成参考

> voice SKILL.md 执行时加载本文件。提供 mmx-cli 命令模板、音色列表、SRT 格式规范。

---

## mmx-cli 命令参考

### 认证检查

```bash
mmx auth status
```

返回 JSON：`{"method": "api-key", "source": "config.json", "key": "sk-..."}`

### 音色列表

```bash
mmx speech voices
mmx speech voices --output json
```

返回中文音色 ID 列表（见下方音色表）。

### 语音合成

```bash
mmx speech synthesize --text "口播文本" --voice <voice-id> --out output.mp3 --subtitles
```

| 参数 | 必须 | 默认值 | 说明 |
|------|------|--------|------|
| `--text` | 是 | — | 待合成文本（≤10k 字符） |
| `--voice` | 否 | `English_expressive_narrator` | 音色 ID |
| `--out` | 否 | 自动生成 | 输出文件路径 |
| `--subtitles` | 否 | 不生成 | 生成 SRT 字幕 |
| `--speed` | 否 | 1.0 | 语速倍数 |
| `--model` | 否 | `speech-2.8-hd` | 模型 ID |
| `--format` | 否 | mp3 | 输出格式：mp3/pcm/flac/wav |
| `--language` | 否 | — | 语言增强 |

**输出**：
- MP3 文件：`--out` 指定的路径
- SRT 文件：同路径但扩展名改为 `.srt`（如 `output.srt`）

### 批量合成模板

```bash
# 第1章第1步
mmx speech synthesize --text "你有没有发现..." --voice female-shaonv --out workspace/rm-hello-world/voice/public/audio/01-what/01.mp3 --subtitles

# 第1章第2步
mmx speech synthesize --text "其实原因很简单..." --voice female-shaonv --out workspace/rm-hello-world/voice/public/audio/01-what/02.mp3 --subtitles
```

---

## 中文音色表

### 通用音色

| ID | 名称 | 风格 |
|----|------|------|
| `male-qn-qingse` | 青涩男声 | 年轻、清新 |
| `male-qn-jingying` | 精英男声 | 成熟、专业 |
| `male-qn-badao` | 霸道男声 | 强势、自信 |
| `male-qn-daxuesheng` | 大学男声 | 学生感、活力 |
| `female-shaonv` | 少女音 | 年轻、活泼 |
| `female-yujie` | 御姐音 | 成熟、知性 |
| `female-chengshu` | 成熟女声 | 稳重、温暖 |
| `female-tianmei` | 甜美女声 | 甜美、亲和 |

### 精品音色（-jingpin 后缀，质量更高）

| ID | 名称 |
|----|------|
| `male-qn-qingse-jingpin` | 精品·青涩男声 |
| `male-qn-jingying-jingpin` | 精品·精英男声 |
| `male-qn-badao-jingpin` | 精品·霸道男声 |
| `male-qn-daxuesheng-jingpin` | 精品·大学男声 |
| `female-shaonv-jingpin` | 精品·少女音 |
| `female-yujie-jingpin` | 精品·御姐音 |
| `female-chengshu-jingpin` | 精品·成熟女声 |
| `female-tianmei-jingpin` | 精品·甜美女声 |

### 角色音色

| ID | 名称 |
|----|------|
| `clever_boy` | 聪明男孩 |
| `cute_boy` | 可爱男孩 |
| `lovely_girl` | 可爱女孩 |
| `cartoon_pig` | 卡通猪 |
| `bingjiao_didi` | 冰娇弟弟 |
| `junlang_nanyou` | 俊朗男友 |
| `chunzhen_xuedi` | 纯真学弟 |
| `lengdan_xiongzhang` | 冷淡学长 |
| `badao_shaoye` | 霸道少爷 |
| `tianxin_xiaoling` | 甜心小玲 |
| `qiaopi_mengmei` | 俏皮萌妹 |
| `wumei_yujie` | 妩媚御姐 |
| `diadia_xuemei` | 嗲嗲雪梅 |
| `danya_xuejie` | 淡雅学姐 |

### 中文专业音色

| ID | 名称 |
|----|------|
| `Chinese (Mandarin)_Reliable_Executive` | 可靠高管 |
| `Chinese (Mandarin)_News_Anchor` | 新闻主播 |
| `Chinese (Mandarin)_Mature_Woman` | 成熟女性 |
| `Chinese (Mandarin)_Unrestrained_Young_Man` | 洒脱青年 |
| `Chinese (Mandarin)_Kind-hearted_Antie` | 热心阿姨 |
| `Chinese (Mandarin)_HK_Flight_Attendant` | 港航空姐 |
| `Chinese (Mandarin)_Humorous_Elder` | 幽默长者 |
| `Chinese (Mandarin)_Gentleman` | 绅士 |
| `Chinese (Mandarin)_Warm_Bestie` | 温暖闺蜜 |
| `Chinese (Mandarin)_Male_Announcer` | 男播音员 |
| `Chinese (Mandarin)_Sweet_Lady` | 甜美女声 |
| `Chinese (Mandarin)_Southern_Young_Man` | 南方青年 |
| `Chinese (Mandarin)_Wise_Women` | 知性女性 |
| `Chinese (Mandarin)_Gentle_Youth` | 温柔少年 |
| `Chinese (Mandarin)_Warm_Girl` | 温暖女孩 |
| `Chinese (Mandarin)_Kind-hearted_Elder` | 慈祥长者 |
| `Chinese (Mandarin)_Cute_Spirit` | 可爱精灵 |
| `Chinese (Mandarin)_Radio_Host` | 电台主持 |
| `Chinese (Mandarin)_Lyrical_Voice` | 抒情之声 |
| `Chinese (Mandarin)_Straightforward_Boy` | 直爽男孩 |
| `Chinese (Mandarin)_Sincere_Adult` | 真诚成人 |
| `Chinese (Mandarin)_Gentle_Senior` | 温柔学长 |
| `Chinese (Mandarin)_Stubborn_Friend` | 固执朋友 |
| `Chinese (Mandarin)_Crisp_Girl` | 清脆女孩 |
| `Chinese (Mandarin)_Pure-hearted_Boy` | 纯真男孩 |
| `Chinese (Mandarin)_Soft_Girl` | 软萌女孩 |

---

## SRT 字幕格式

```
1
00:00:01,000 --> 00:00:04,000
第一句口播文本

2
00:00:05,000 --> 00:00:08,500
第二句口播文本
可能跨多行
```

- 时间格式：`HH:MM:SS,mmm`（逗号或句号均可）
- 块之间用空行分隔
- 序号从 1 开始连续编号

---

## 语速参考

| 场景 | 推荐语速 | --speed 值 |
|------|---------|-----------|
| 知识讲解（清晰优先） | 120-140 字/分 | 0.9-1.0 |
| 正常口播 | 150-170 字/分 | 1.0-1.1 |
| 快节奏/信息密集 | 170-190 字/分 | 1.1-1.3 |

**单句长度限制**：≤50 字（超过 TTS 易破音，需拆分）

---

## 语速控制详细指南

### 语速与内容类型匹配

| 内容类型 | 目标语速 | --speed 值 | 说明 |
|---------|---------|-----------|------|
| 知识讲解 | 120-140 字/分 | 0.9-1.0 | 清晰优先，给观众消化时间 |
| 正常口播 | 150-170 字/分 | 1.0-1.1 | 默认节奏 |
| 快节奏信息 | 170-190 字/分 | 1.1-1.3 | 信息密集，但不超过 190 |
| 情感表达 | 100-130 字/分 | 0.8-0.9 | 留白给情感呼吸 |
| 强调/悬念 | 变速 | 手动调整 | 关键信息前减速，过渡段加速 |

### 语速异常检测（VO-001）

TTS 合成后检查实际语速：
- 计算方式：字数 / 音频时长（秒）× 60
- 正常范围：120-180 字/分
- <120：可能 TTS 引擎断句不当，检查文本标点
- >180：可能文本过密，需要拆分或添加停顿

### 变速策略

| 场景 | 处理方式 |
|------|---------|
| 开场 Hook | 正常偏快（160-170），制造紧迫感 |
| 核心概念 | 减速（120-140），给理解时间 |
| 数据/列表 | 匀速（150），节奏稳定 |
| 转折/悬念 | 前句减速，后句恢复正常 |
| 结尾 CTA | 正常偏快（160），干净利落 |

---

## 停顿标记规范

### 停顿类型

| 类型 | 时长 | 标记方式 | 使用场景 |
|------|------|---------|---------|
| 句间停顿 | 0.3-0.5s | 句号/问号/感叹号 | 自然断句 |
| 段落停顿 | 0.8-1.2s | 空行或 `\n\n` | 章节切换 |
| 强调停顿 | 0.5-0.8s | 逗号 + 前后短句 | 关键信息前 |
| 呼吸停顿 | 0.3-0.5s | 逗号 | 长句中间（每 15-20 字） |
| 悬念停顿 | 1.0-1.5s | 省略号或破折号 | 制造期待 |

### 停顿插入规则（VO-004 修复）

1. **单句 ≤25 字**：不需要额外停顿
2. **单句 26-40 字**：在自然断点插入 1 个逗号
3. **单句 41-50 字**：拆分为 2 句，或插入 2 个逗号
4. **单句 >50 字**：必须拆分（VO-002 触发）

### 标点与停顿映射

| 标点 | TTS 引擎行为 | 预期停顿 |
|------|------------|---------|
| ， | 短暂停顿 | 0.2-0.3s |
| 。 | 正常停顿 | 0.3-0.5s |
| ？ | 疑问语调 + 停顿 | 0.4-0.6s |
| ！ | 感叹语调 + 停顿 | 0.3-0.5s |
| …… | 延长停顿 | 0.8-1.2s |
| —— | 转折停顿 | 0.5-0.8s |
| 、 | 最短停顿 | 0.1-0.2s |

---

## 情感标记规范

### 情感标记方式

mmx-cli 不支持 SSML 情感标签。情感控制通过**文本措辞**和**标点**实现：

| 情感 | 文本策略 | 标点策略 | 示例 |
|------|---------|---------|------|
| 惊讶 | 短句 + 反问 | 感叹号/问号 | "这不可能！" |
| 悬念 | 省略 + 未完成句 | 省略号 | "结果嘛……" |
| 强调 | 重复关键词 | 感叹号 | "重要的事情说三遍：快！快！快！" |
| 温和 | 长句 + 软化词 | 逗号多 | "其实吧，也没那么严重" |
| 严肃 | 短句 + 直接陈述 | 句号 | "这是事实。不可回避。" |
| 幽默 | 反转 + 夸张 | 问号+感叹号 | "你以为完了？不，这才刚开始！" |

### 情感曲线设计

口播稿的情感应有起伏，不能全程一个调：

```
开场：中性偏兴奋（Hook）
↓
铺垫：平稳（建立背景）
↓
转折：惊讶/悬念（核心信息前）
↓
高潮：强调/兴奋（核心信息）
↓
收尾：温和/坚定（CTA）
```

### 注册表对情感的影响

| 注册表 | 情感策略 |
|--------|---------|
| Brand | 情感起伏大，允许戏剧化 |
| Product | 情感中性偏温和，信息优先 |

---

## 多音字处理

### 常见多音字标注

TTS 引擎对多音字可能误读。在文本中用括号标注拼音：

| 多音字 | 正确读音 | 错误读音 | 标注方式 |
|--------|---------|---------|---------|
| 行 | háng（行业）/ xíng（行动） | — | 行(háng)业 |
| 长 | cháng（长度）/ zhǎng（成长） | — | 长(cháng)度 |
| 重 | zhòng（重要）/ chóng（重复） | — | 重(zhòng)要 |
| 数 | shù（数据）/ shǔ（数数） | — | 数(shù)据 |
| 率 | lǜ（效率）/ shuài（率领） | — | 效率(lǜ) |
| 角 | jiǎo（角度）/ jué（角色） | — | 角(jiǎo)度 |
| 处 | chù（处理）/ chǔ（相处） | — | 处(chǔ)理 |
| 了 | le（好了）/ liǎo（了解） | — | 了(liǎo)解 |
| 得 | de（得到）/ dé（得分）/ děi（得去） | — | 得(dé)分 |
| 还 | hái（还是）/ huán（归还） | — | 还(hái)是 |

### 标注规则

1. 仅在可能误读时标注（不影响阅读的前提下）
2. 标注格式：`字(拼音)`，如 `行(háng)业`
3. TTS 合成后试听，确认读音正确
4. 如果引擎支持 SSML phoneme 标签，优先使用 SSML

### VO-003 检测

反模式规则 VO-003 检测多音字是否标注：
- 扫描文本中的常见多音字
- 检查是否在可能误读的上下文中缺少拼音标注
- 标记为 warning（不阻断，但建议标注）

---

## TTS 破音规避

### 破音原因

TTS 引擎在以下情况容易产生破音、卡顿或不自然：

| 原因 | 表现 | 解决方案 |
|------|------|---------|
| 单句过长（>50字） | 中途断气、语调塌陷 | 拆分为 ≤25 字的短句 |
| 标点缺失 | 连读无停顿，像机器人 | 每 15-20 字插入逗号 |
| 特殊符号 | 引擎不认识，跳过或乱读 | 避免使用 @#$%^& 等 |
| 英文混排 | 中英切换不自然 | 英文用中文描述替代，或单独合成 |
| 数字连续 | "1234567890"读成"一二三四五六七八九零" | 用中文写："一百二十三亿" |
| 重复字 | "哈哈哈"可能只读一个 | 用文字描述："大笑" |
| 括号内容 | 可能被跳过或读出"左括号" | 用逗号或破折号替代 |

### 单句长度优化（VO-002 修复）

将长句拆分为短句的原则：

```
❌ "咖啡里有两拨东西，一拨负责苦，一拨负责香，热的时候香的那拨很活跃，你的鼻子在帮你骗舌头。"
✅ "咖啡里有两拨东西。一拨负责苦，一拨负责香。热的时候，香的那拨很活跃。你的鼻子在帮你骗舌头。"
```

拆分原则：
1. 每个独立意群拆为一句
2. 每句 ≤25 字
3. 句间用句号，不用逗号（TTS 对句号的停顿更明显）
4. 保留口语感——拆分后读出来要像说话

### 英文混排处理

| 场景 | 处理方式 |
|------|---------|
| 品牌名 | 首次出现用中文描述，后续可用英文："MiniMax（一家AI公司）" |
| 技术术语 | 用中文替代："人工智能"而非"AI" |
| 专有名词 | 保留英文，但前后加中文解释 |
| 缩写 | 展开为中文："每分钟字数"而非"CPM" |

### 数字处理

| 场景 | 处理方式 | 示例 |
|------|---------|------|
| 小数字（1-99） | 用中文 | "二十五" |
| 大数字（≥100） | 用阿拉伯数字 + 逗号分隔 | "1,234" |
| 百分比 | 用中文 | "百分之六十七" |
| 时间 | 用中文 | "三分钟" |
| 金额 | 中文 + 数字 | "一百万美元" |

---

## 音色选择指南

### 按内容类型选音色

| 内容类型 | 推荐音色 | 理由 |
|---------|---------|------|
| 知识讲解 | `male-qn-jingying` 或 `female-yujie` | 专业、可信 |
| 轻松科普 | `male-qn-qingse` 或 `female-shaonv` | 年轻、亲切 |
| 商业分析 | `Chinese (Mandarin)_Reliable_Executive` | 权威感 |
| 新闻播报 | `Chinese (Mandarin)_News_Anchor` | 标准、清晰 |
| 故事叙述 | `male-qn-daxuesheng` 或 `female-chengshu` | 温暖、有代入感 |
| 儿童内容 | `clever_boy` 或 `lovely_girl` | 活泼、可爱 |

### 按注册表选音色

| 注册表 | 音色倾向 |
|--------|---------|
| Brand | 角色音色（有个性、有辨识度） |
| Product | 通用/专业音色（清晰、中性） |

### 音色试听流程

1. 选择 2-3 个候选音色
2. 用同一段文本（50-100 字）分别合成
3. 试听对比：清晰度、自然度、情感表达
4. 选定后在 plan.json 中记录音色 ID
