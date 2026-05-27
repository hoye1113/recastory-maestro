# SRT 合并脚本 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用确定性 bash 脚本替代 Agent 手动计算 cumulative_offset，将步骤级 SRT 合并为章节级 SRT。

**Architecture:** 单文件 bash 脚本 `tools/merge-srt.sh`，接受 workspace 目录作为参数，读取 `audio-segments.json` 获取章节结构，遍历每个章节目录下的步骤级 `.srt` 文件，计算 cumulative offset 并合并为章节级 `.srt`。纯确定性逻辑，无 LLM 参与。

**Tech Stack:** Bash, jq (JSON 解析), awk (时间戳算术)

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `tools/merge-srt.sh` | 主脚本：合并步骤级 SRT → 章节级 SRT |
| Create | `tools/merge-srt.test.sh` | 测试：验证合并逻辑正确性 |
| Modify | `skills/voice/SKILL.md` | 更新 Step 5：改为调用 merge-srt.sh |

---

### Task 1: 编写 merge-srt.sh

**Files:**
- Create: `tools/merge-srt.sh`
- Create: `tools/merge-srt.test.sh`

- [ ] **Step 1: 编写测试用例数据**

```bash
# tools/merge-srt.test.sh
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="/tmp/merge-srt-test-$$"
MERGE="$SCRIPT_DIR/merge-srt.sh"

cleanup() { rm -rf "$WORKSPACE"; }
trap cleanup EXIT

# Setup: 模拟 2 章 3 步的 workspace
mkdir -p "$WORKSPACE/voice/public/audio/ch1"
mkdir -p "$WORKSPACE/voice/public/audio/ch2"

# 步骤级 SRT（ch1: 2 步, ch2: 1 步）
cat > "$WORKSPACE/voice/public/audio/ch1/01.srt" << 'EOF'
1
00:00:00,000 --> 00:00:03,000
第一句
EOF

cat > "$WORKSPACE/voice/public/audio/ch1/02.srt" << 'EOF'
1
00:00:00,000 --> 00:00:02,500
第二句
EOF

cat > "$WORKSPACE/voice/public/audio/ch2/01.srt" << 'EOF'
1
00:00:00,000 --> 00:00:04,000
第三句
EOF

# audio-segments.json（声明章节结构）
cat > "$WORKSPACE/voice/audio-segments.json" << 'EOF'
{
  "segments": [
    { "id": "ch1-01", "chapter": "ch1", "chapterIndex": 1, "stepIndex": 1, "text": "第一句" },
    { "id": "ch1-02", "chapter": "ch1", "chapterIndex": 1, "stepIndex": 2, "text": "第二句" },
    { "id": "ch2-01", "chapter": "ch2", "chapterIndex": 2, "stepIndex": 1, "text": "第三句" }
  ]
}
EOF

# Run
bash "$MERGE" "$WORKSPACE" 2>&1

# Assert: 章节级 SRT 存在
[ -f "$WORKSPACE/voice/public/audio/ch1.srt" ] || { echo "FAIL: ch1.srt not found"; exit 1; }
[ -f "$WORKSPACE/voice/public/audio/ch2.srt" ] || { echo "FAIL: ch2.srt not found"; exit 1; }

# Assert: ch1.srt 内容正确（cumulative offset）
CH1=$(cat "$WORKSPACE/voice/public/audio/ch1.srt")
echo "$CH1" | grep -q "00:00:00,000 --> 00:00:03,000" || { echo "FAIL: ch1 step1 timestamp"; exit 1; }
echo "$CH1" | grep -q "00:00:03,000 --> 00:00:05,500" || { echo "FAIL: ch1 step2 offset (expected 3000+2500=5500)"; exit 1; }
echo "$CH1" | grep -q "^第一句$" || { echo "FAIL: ch1 step1 text"; exit 1; }
echo "$CH1" | grep -q "^第二句$" || { echo "FAIL: ch1 step2 text"; exit 1; }

# Assert: ch2.srt 重新从 0 开始
CH2=$(cat "$WORKSPACE/voice/public/audio/ch2.srt")
echo "$CH2" | grep -q "00:00:00,000 --> 00:00:04,000" || { echo "FAIL: ch2 step1 timestamp"; exit 1; }

# Assert: 条目编号连续
CH1_COUNT=$(echo "$CH1" | grep -c "^[0-9]\+$")
[ "$CH1_COUNT" -eq 2 ] || { echo "FAIL: ch1 expected 2 entries, got $CH1_COUNT"; exit 1; }

echo "ALL TESTS PASSED"
```

- [ ] **Step 2: 运行测试确认失败**

```bash
chmod +x tools/merge-srt.test.sh
bash tools/merge-srt.test.sh
```

Expected: `merge-srt.sh: No such file or directory` — 测试失败。

- [ ] **Step 3: 实现 merge-srt.sh**

```bash
#!/bin/bash
# tools/merge-srt.sh
# 合并步骤级 SRT → 章节级 SRT
# Usage: bash tools/merge-srt.sh <workspace-dir>
# 读取 voice/audio-segments.json 获取章节结构，
# 遍历 voice/public/audio/<chapter>/*.srt，
# 计算 cumulative offset，输出 voice/public/audio/<chapter>.srt

set -euo pipefail

WORKSPACE="${1:?Usage: merge-srt.sh <workspace-dir>}"
VOICE_DIR="$WORKSPACE/voice"
SEGMENTS_FILE="$VOICE_DIR/audio-segments.json"
AUDIO_DIR="$VOICE_DIR/public/audio"

if [ ! -f "$SEGMENTS_FILE" ]; then
  echo "ERROR: $SEGMENTS_FILE not found" >&2
  exit 1
fi

# 提取不重复的 chapter 列表（按 chapterIndex 排序）
CHAPTERS=$(jq -r '[.segments | group_by(.chapter) | .[] | {chapter: .[0].chapter, index: .[0].chapterIndex}] | sort_by(.index) | .[].chapter' "$SEGMENTS_FILE")

SRT_TO_MS() {
  # "00:00:03,000" → 3000
  local ts="$1"
  local h m s ms
  h=$(echo "$ts" | cut -d: -f1 | sed 's/^0//')
  m=$(echo "$ts" | cut -d: -f2 | sed 's/^0//')
  s=$(echo "$ts" | cut -d: -f3 | cut -d, -f1 | sed 's/^0//')
  ms=$(echo "$ts" | cut -d, -f2 | sed 's/^0//')
  echo $(( ${h:-0} * 3600000 + ${m:-0} * 60000 + ${s:-0} * 1000 + ${ms:-0} ))
}

MS_TO_SRT() {
  # 3000 → "00:00:03,000"
  local ms="$1"
  local h=$(( ms / 3600000 ))
  local rem=$(( ms % 3600000 ))
  local m=$(( rem / 60000 ))
  rem=$(( rem % 60000 ))
  local s=$(( rem / 1000 ))
  local ms_part=$(( rem % 1000 ))
  printf "%02d:%02d:%02d,%03d" "$h" "$m" "$s" "$ms_part"
}

for chapter in $CHAPTERS; do
  CHAPTER_DIR="$AUDIO_DIR/$chapter"
  OUTPUT="$AUDIO_DIR/${chapter}.srt"

  if [ ! -d "$CHAPTER_DIR" ]; then
    echo "WARN: $CHAPTER_DIR not found, skipping" >&2
    continue
  fi

  # 收集该章节的步骤级 SRT（按 stepIndex 排序）
  STEP_SRTS=$(jq -r --arg ch "$chapter" '
    [.segments[] | select(.chapter == $ch)] | sort_by(.stepIndex) | .[] |
    "\(.stepIndex) \(.chapter)"
  ' "$SEGMENTS_FILE" | while read -r idx ch; do
    printf "%s/%02d.srt\n" "$CHAPTER_DIR" "$idx"
  done)

  cumulative_ms=0
  entry_num=1
  > "$OUTPUT"  # 清空输出

  for srt_file in $STEP_SRTS; do
    if [ ! -f "$srt_file" ]; then
      echo "WARN: $srt_file not found, skipping" >&2
      continue
    fi

    # 读取 SRT 内容（跳过空行和序号行，提取时间戳和文本）
    while IFS= read -r line; do
      # 跳过空行
      [ -z "$line" ] && continue

      # 时间戳行
      if echo "$line" | grep -qE '^[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3} -->'; then
        start_ts=$(echo "$line" | awk '{print $1}')
        end_ts=$(echo "$line" | awk '{print $3}')

        start_ms=$(SRT_TO_MS "$start_ts")
        end_ms=$(SRT_TO_MS "$end_ts")

        new_start_ms=$(( cumulative_ms + start_ms ))
        new_end_ms=$(( cumulative_ms + end_ms ))

        new_start=$(MS_TO_SRT "$new_start_ms")
        new_end=$(MS_TO_SRT "$new_end_ms")

        # 写入序号和时间戳
        echo "$entry_num" >> "$OUTPUT"
        echo "$new_start --> $new_end" >> "$OUTPUT"
        entry_num=$(( entry_num + 1 ))
      elif echo "$line" | grep -qE '^[0-9]+$'; then
        # 序号行，跳过
        continue
      else
        # 文本行
        echo "$line" >> "$OUTPUT"
      fi
    done < "$srt_file"

    # 更新 cumulative: 该步骤最后一条的 end 时间
    last_end=$(grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3} --> [0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}' "$srt_file" | tail -1 | awk '{print $3}')
    cumulative_ms=$(( cumulative_ms + $(SRT_TO_MS "$last_end") ))

    # 块之间加空行
    echo "" >> "$OUTPUT"
  done

  echo "  ✅ $OUTPUT ($(( entry_num - 1 )) entries)"
done
```

- [ ] **Step 4: 运行测试确认通过**

```bash
chmod +x tools/merge-srt.sh
bash tools/merge-srt.test.sh
```

Expected: `ALL TESTS PASSED`

- [ ] **Step 5: 用真实数据验证**

```bash
bash tools/merge-srt.sh workspace/rm-test-002
diff workspace/rm-test-002/voice/public/audio/01-what.srt <(cat)  # 对比手算结果
```

Expected: 输出与之前 Agent 手动合并的结果一致。

- [ ] **Step 6: Commit**

```bash
git add tools/merge-srt.sh tools/merge-srt.test.sh
git commit -m "feat(tools): add merge-srt.sh for deterministic SRT merging"
```

---

### Task 2: 更新 voice SKILL.md 使用脚本

**Files:**
- Modify: `skills/voice/SKILL.md:120-140`（Step 5 合并 SRT 部分）

- [ ] **Step 1: 替换 Step 5 内容**

将 `skills/voice/SKILL.md` 的 Step 5 从手动 cumulative_offset 描述替换为：

```markdown
### 5. [正常路径] 合并 SRT

调用确定性脚本合并章节级 SRT：

```bash
bash tools/merge-srt.sh <workspace-dir>
```

脚本自动完成：
1. 读取 `audio-segments.json` 获取章节结构
2. 遍历每章的步骤级 SRT
3. 计算 cumulative offset
4. 输出章节级 `<chapter>.srt`

**不做手动计算。** 脚本失败时停下报告用户。
```

- [ ] **Step 2: 运行 voice SKILL.md 的反模式检查**

确认修改后 SKILL.md 仍满足：
- IRON LAW 不变
- 步骤编号连续
- 产出路径不变

- [ ] **Step 3: Commit**

```bash
git add skills/voice/SKILL.md
git commit -m "docs(voice): update Step 5 to use merge-srt.sh script"
```

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| merge-srt.sh 单元测试 | `bash tools/merge-srt.test.sh` → ALL TESTS PASSED |
| 真实数据一致性 | 对比 rm-test-002 的手算 SRT 与脚本输出 |
| voice SKILL.md 步骤完整性 | 人工审查 Step 1-8 连续性 |
| Agent 调用方式 | 下次 voice 阶段验证 Agent 是否调用脚本而非手动计算 |
