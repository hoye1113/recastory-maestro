#!/usr/bin/env py
# tools/split-srt.py
# Split long SRT subtitle lines into short ones (≤20 chars), one line at a time.
# Usage: py tools/split-srt.py <input.srt> <output.srt> [--max-len 20]

import re
from datetime import datetime, timedelta
import sys


def ms_to_srt(ms):
    td = timedelta(milliseconds=ms)
    t = (datetime.min + td).time()
    return f"{t.strftime('%H:%M:%S')},{ms % 1000:03d}"


def srt_to_ms(ts):
    h, m, s, ms = re.match(r'(\d+):(\d+):(\d+),(\d+)', ts).groups()
    return int(h) * 3600000 + int(m) * 60000 + int(s) * 1000 + int(ms)


def split_text(text, max_len=20):
    """按标点拆句，超长时优先在虚词后切断"""
    text = text.strip()
    if len(text) <= max_len:
        return [text]

    # 优先级：句号/问号/叹号 > 分号/破折号 > 逗号
    delimiters = r'([。！？；—–,])'
    parts = re.split(delimiters, text)
    chunks = []
    current = ""
    for i, part in enumerate(parts):
        if i % 2 == 0:  # 文字
            current = part
        else:  # 标点
            current += part
            if len(current) >= max_len * 0.5:
                chunks.append(current.strip())
                current = ""
    if current:
        chunks.append(current.strip())

    # 二次检查：仍有超长则硬切，优先虚词后
    result = []
    for c in chunks:
        while len(c) > max_len:
            cut = max_len
            for i in range(max_len - 1, max_len // 2, -1):
                if c[i] in '的了以及但是而因为如果就能':
                    cut = i + 1
                    break
            result.append(c[:cut].strip())
            c = c[cut:].strip()
        if c:
            result.append(c)
    return result


SENTENCE_END_PUNCT = set('。！？')


def allocate_time(start_ms, end_ms, chunks):
    """按字数比例分配时间，句末加 0.4s 呼吸时间，每条最少 1.5s"""
    total_len = sum(len(c) for c in chunks)
    total_dur = end_ms - start_ms
    min_dur = 1500  # 1.5s 保护
    breath_dur = 400  # 句末呼吸时间

    # 计算句末呼吸时间总量
    breath_total = 0
    for c in chunks:
        if c and c[-1] in SENTENCE_END_PUNCT:
            breath_total += breath_dur

    # 可分配的口播时间 = 总时长 - 句末呼吸
    speech_dur = max(total_dur - breath_total, min_dur * len(chunks))

    # 按字数比例分配口播时间
    raw = []
    for c in chunks:
        base = len(c) / total_len * speech_dur if total_len > 0 else speech_dur / len(chunks)
        extra = breath_dur if (c and c[-1] in SENTENCE_END_PUNCT) else 0
        raw.append(max(min_dur, base + extra))

    # 如果超出总时长，压缩（保持最小 1.5s）
    if sum(raw) > total_dur:
        scale = (total_dur - min_dur * len(chunks)) / max(sum(raw) - min_dur * len(chunks), 1)
        if scale > 0:
            raw = [min_dur + (r - min_dur) * scale for r in raw]

    times = []
    cur = start_ms
    for d in raw:
        times.append((cur, min(cur + int(d), end_ms)))
        cur = times[-1][1]
    # 最后一条吸到 end_ms
    if times:
        times[-1] = (times[-1][0], end_ms)
    return times


def merge_short_chunks(chunks, times, min_dur=1500):
    """合并显示时长不足 1.5s 的条目回上一条"""
    if len(chunks) <= 1:
        return chunks, times

    merged_chunks = [chunks[0]]
    merged_times = [times[0]]

    for i in range(1, len(chunks)):
        s, e = times[i]
        if (e - s) < min_dur:
            # 合并到上一条
            merged_chunks[-1] = merged_chunks[-1] + chunks[i]
            merged_times[-1] = (merged_times[-1][0], e)
        else:
            merged_chunks.append(chunks[i])
            merged_times.append(times[i])

    return merged_chunks, merged_times


def process_srt(input_path, output_path, max_len=20):
    with open(input_path, 'r', encoding='utf-8') as f:
        content = f.read()

    blocks = re.split(r'\n\s*\n', content.strip())
    out_blocks = []
    idx = 1

    for block in blocks:
        lines = block.strip().split('\n')
        if len(lines) < 3:
            continue
        time_line = lines[1]
        text = '\n'.join(lines[2:])

        m = re.match(r'(\d+:\d+:\d+,\d+) --> (\d+:\d+:\d+,\d+)', time_line)
        if not m:
            continue
        start, end = srt_to_ms(m.group(1)), srt_to_ms(m.group(2))

        chunks = split_text(text, max_len)
        times = allocate_time(start, end, chunks)
        chunks, times = merge_short_chunks(chunks, times)

        for chunk, (s, e) in zip(chunks, times):
            out_blocks.append(f"{idx}\n{ms_to_srt(s)} --> {ms_to_srt(e)}\n{chunk}")
            idx += 1

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n\n'.join(out_blocks) + '\n')

    print(f"Split: {len(blocks)} entries → {idx - 1} entries (max {max_len} chars/line)")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: py tools/split-srt.py <input.srt> <output.srt> [--max-len N]")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    max_len = 20
    if '--max-len' in sys.argv:
        idx = sys.argv.index('--max-len')
        max_len = int(sys.argv[idx + 1])

    process_srt(input_path, output_path, max_len)
