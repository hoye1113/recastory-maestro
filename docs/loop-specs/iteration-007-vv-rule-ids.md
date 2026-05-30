# VV_RULE_IDS Auto-Collection Spec

## Metadata

- Iteration: 7
- Track: v3.1.0 VV_RULE_IDS
- Created: 2026-05-30

## Context

当前 VV_RULE_IDS 在 tools/audit/rules.py 中手动维护列表。新增规则时需手动更新，容易遗漏。

## 方案

用装饰器自动收集：

```python
# rules.py 顶部
_RULE_REGISTRY = {}

def rule(rule_id, severity="warning", file_types=None):
    def decorator(cls):
        _RULE_REGISTRY[rule_id] = {
            "class": cls,
            "severity": severity,
            "file_types": file_types or [],
        }
        return cls
    return decorator

# 使用
@rule("VV-001", severity="critical", file_types=["*.png", "*.jpg"])
class VV001Rule(BaseRule):
    ...

# 自动导出
VV_RULE_IDS = [k for k in _RULE_REGISTRY if k.startswith("VV-")]
ALL_RULE_IDS = list(_RULE_REGISTRY.keys())
```

## File Changes

- `tools/audit/rules.py` — 添加 @rule 装饰器，重构现有规则
- `tools/audit/__init__.py` — 从 registry 读取规则列表

## Acceptance Criteria

- [ ] VV_RULE_IDS 自动从装饰器收集
- [ ] 新增规则只需加 @rule 装饰器，无需手动更新列表
- [ ] `python -m tools.audit --list-rules` 输出所有注册规则
