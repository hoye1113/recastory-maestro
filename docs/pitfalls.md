# Recastory 踩坑记录

> 本文档记录开发过程中遇到的坑和解决方案，避免重复踩坑。

## 1. ffmpeg `force_style` 多参数在 Windows 上失效

**现象**: 字幕出现在屏幕中间（~50%），而不是底部。

**根因**: ffmpeg 的 `subtitles` filter 用 `:` 分隔选项，`, ` 分隔 filter chain。`force_style='FontSize=12,Alignment=2,MarginV=140'` 中的逗号被解析为 filter separator，导致 `force_style` 参数全部失效，字幕回退到默认居中位置。

**验证**:
- 单参数 `force_style='FontSize=12'` → 字幕在底部（94%）
- 多参数 `force_style='FontSize=12,Alignment=2'` → 字幕在中间（49%）

**解决方案**: 在 SRT 文本中用 ASS override tags 注入样式，`force_style` 只保留单参数：

```python
# split-srt.py 中注入 ASS 标签
out_blocks.append(f"{idx}\n{ms_to_srt(s)} --> {ms_to_srt(e)}\n" + "{\\an2}" + chunk)
```

```bash
# render-video.sh 中 force_style 只用单参数
-vf "subtitles=filename=${srt_file}:force_style='FontSize=12'"
```

## 2. ASS 对齐编号是键盘布局，不是直觉

**坑**: 以为 `\an8` = 底部居中，实际是**顶部居中**。

ASS 对齐编号对应键盘数字区：
```
7 8 9   ← 顶部（左/中/右）
4 5 6   ← 中部（左/中/右）
1 2 3   ← 底部（左/中/右）
```

**常用值**:
- `\an2` = 底部居中 ← 字幕用这个
- `\an8` = 顶部居中
- `\an5` = 正中央

## 3. 字幕烧录是破坏性操作

**现象**: 在已烧录字幕的视频上再次烧录，出现两层重叠字幕。

**解决方案**: 录制完成后，先备份干净视频：

```bash
mkdir -p render/clean
cp render/0*.mp4 render/clean/
```

烧录出错时从 `render/clean/` 恢复，无需重新录制。

## 4. Windows 路径冒号破坏 ffmpeg filter 解析

**现象**: `subtitles=filename=F:\path\file.srt:force_style=...` 中 `F:` 被解析为 option separator。

**验证**: 相对路径可用，但 `force_style` 多参数问题依然存在（见 #1）。

**最终方案**: 不依赖 `force_style`，用 ASS override tags 在 SRT 文本中控制样式。

## 5. CDP Screencast 录制注意事项

- **Chrome 未安装时自动回退到 Edge**，无需手动指定
- **静态页面帧率低**: CDP screencast 只在画面变化时推帧，纯静态页面可能只有 4fps
- **解决方案**: 给静态元素加 subtle CSS 动画驱动合成器持续推帧：
  ```css
  .stage {
    will-change: opacity;
    transform: translateZ(0);
    animation: breathe 5s ease-in-out infinite alternate;
  }
  @keyframes breathe {
    from { opacity: 0.88; }
    to   { opacity: 1.0; }
  }
  ```
- **像素格式**: CDP screencast 输出 yuvj420p（full-range），非 yuv420p，多章拼接时格式一致无问题

## 6. split-srt.py 拆行规则

- ≤20 字/行，按标点优先级拆句（。！？ > ；— > ，）
- 超长硬切优先在虚词后（的了以及但是而因为如果就能）
- 每条最少 1.5s，不足则合并回上一条
- 句末（。！？）加 0.4s 呼吸时间
- 按字数比例分配时间窗口

## 7. 字幕样式参数（最终版）

| 参数 | 值 | 说明 |
|------|-----|------|
| 对齐 | `\an2` | ASS override tag，底部居中 |
| FontSize | 12 | force_style 单参数 |
| 位置 | ~95% 从顶部 | 由 `\an2` + 默认 MarginV 控制 |
| 每行字数 | ≤20 | split-srt.py 拆分 |
| 最小显示 | 1.5s | 避免切换太快 |

## 8. audit 规则覆盖范围（v3.0.0）

**v3.0.0 的 `audit` skill 不是全量覆盖。** 当前 rules.py 只实现了部分规则：

| 规则集 | 状态 | 说明 |
|--------|------|------|
| RD (render) | ✅ 已实现 | 视频时长、分辨率、字幕同步、文件大小 |
| DS (distill-style) | ❌ 未实现 | 口语化检查，依赖 LLM critique 兜底 |
| CH (chapter visual) | ❌ 未实现 | 视觉反模式，依赖 LLM critique 兜底 |
| SB (storyboard design) | ❌ 未实现 | 分镜设计规则，依赖 LLM critique 兜底 |

**影响**: 运行 `audit` 时，design/storyboard 相关违规不会被确定性规则捕获，而是由 SKILL.md 中的 Agent 指令隐式检查。这意味着检查结果可能因 LLM 状态而异。

**v3.1.0 计划**: 实现 DS/CH/SB 规则引擎，使 audit 成为全量确定性质量门控。
