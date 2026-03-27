---
name: FAPI TC 编码规则与分层职责
description: UL链路tc字段的uint32_t编码规范、零点定义、编码职责归属及常见错误
type: context
created: 2026-03-24
updated: 2026-03-24
---

# 项目背景

## 场景

修改 nrMacTest 中任何 UL 链路（UL-SCH、UCI/SR/HARQ/CSI、SRS）的 tc 值传递逻辑时，需要理解 tc 的编码规则和分层边界。

## TC 值的两种语义

该系统中 tc 存在两种语义：

- **FAPI 接口层**: 使用 `uint32_t` 类型定义，以 `0x80000000` 为零点来表示有符号的 timing advance。`0x80000000` 本身对应 tc=0（物理时刻 0），正值加、负值减。
- **业务/仿真逻辑层**: 使用正常的有符号 `int` 类型定义，表达直观的正负时刻偏移。

在进行 tc 值相关操作时，需根据当前代码层级和语义正确处理两种定义，避免混淆。例如：仿真侧产生和消费 tc 时通常用有符号定义；跨 FAPI 接口传递时使用无符号编码；MAC 层通过 `convertTc2Ta()` 还原有符号 TA。

## 关键约束

1. **编码零点**: `0x80000000` 表示 tc=0。绝不可将有符号整数 0 直接赋给 FAPI tc 字段。
2. **ReqConfig 中 tc 类型为 uint32_t**: 从 OutputValue 到 ReqConfig 到 FAPI 结构体，全链路使用 FAPI 的无符号类型。
3. **TA 可由 tc + SCS 推导**: MAC 层已有 `convertTc2Ta(tc, numerology)` 完成此推导，nrMacTest 侧不需要重复传递冗余的 ta 值（UL-SCH 的 ta 字段除外，那是给 pTbInfo 结构体直接使用的）。
