# Recastory Roadmap

## v3.0.0 (current)

Released 2026-05-30.

- CDP Screencast 录屏 + FFmpeg 编码
- SRT 字幕拆行（≤20字/行，底部对齐）
- TTS 多 Provider 降级链
- 完整文档体系
- 9/14 skills 有 test-prompts.json

## v3.1.0 (planned)

### 规则引擎实现

**目标**: audit skill 全量确定性质量门控。

| 规则集 | 当前状态 | v3.1.0 目标 |
|--------|---------|------------|
| RD (render) | ✅ 已实现 | 保持 |
| DS (distill-style) | ❌ 未实现 | 实现 6 条口语化规则 |
| CH (chapter visual) | ❌ 未实现 | 实现 6 条视觉规则 |
| SB (storyboard design) | ❌ 未实现 | 实现 5 条分镜规则 |

**参考**: ARCHITECTURE.md 中 DS-001~006、CH-001~006、SB-001~005 规则定义。

### 测试框架

**目标**: 每个 skill 有最小测试契约。

- 每个 skill 至少有 `test-prompts.json` + `expected-output.md`
- 核心 skill（render/voice/distill/storyboard）有 `test/` 目录
- 定义最小测试契约：输入 → 预期输出 → 自动验证

### VV_RULE_IDS 自动收集

**目标**: 消除手动维护规则 ID 列表的风险。

- AST 扫描或装饰器自动收集 rules.py 中的规则 ID
- 替代 VV_RULE_IDS 手动列表
