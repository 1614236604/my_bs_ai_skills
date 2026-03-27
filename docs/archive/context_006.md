---
name: NrMacConfigExtender配置访问规范与Manager类设计模式
description: MAC层配置必须通过NrMacConfigExtender访问，Manager类必须遵循init()-一次分配、继承NrMacChannelSchedulingNode的设计模式
type: context
created: 2026-03-25T00:00:00+08:00
updated: 2026-03-25T00:00:00+08:00
---

# 项目背景

## 场景
在添加或修改 MAC 调度管理器类、访问 NTN 相关配置参数时需要遵守的设计规范。

## 需求

### 配置访问
MAC 层的配置参数不能直接读取 `MacConfigDataPtr` 或 `MacConfiguratorPtr`，必须通过 `NrMacConfigExtender` 统一访问。此设计保证配置访问的封装性和 NTN 特性的条件编译隔离。

- 当需要访问新配置字段时，在 `nrMacConfigExtender.h` 中添加新的 accessor 方法
- NTN 特有行为使用 `#ifdef CONFIG_NTN` 进行条件编译保护
- 常用 accessor 包括：`getKCellOffset()`、`kOffset_slots()`、`getNumberOfHarqProcessExtend()`、`getUlHarqModeV17()`、`getDlHarqFeedbackDisableV17()`、`maxNumberOfRecordTtiUl()`

### Manager类设计
调度管理器类继承自 `NrMacChannelSchedulingNode`，遵循以下模式：
- 在 `init()` 中一次性完成所有内存池的分配（`resize()`）
- 提供 `reset()` 方法用于状态重置
- 保持状态最小化：每个存储字段必须有真实的读取者影响调度决策
- 优先选择满足当前需求的最简单算法，只有在有证据证明需要时才增加复杂度

## 关键约束
- 禁止在 manager 逻辑内直接读取底层配置指针
- 资源池在 `init()` 中一次性分配，TTI 路径中不得调整大小
- 状态转换应从一个明确的位置控制
- 一次性操作应有防重复执行的守卫
- 配置旋钮限制在面向运营商的真实需求范围内
