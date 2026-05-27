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
