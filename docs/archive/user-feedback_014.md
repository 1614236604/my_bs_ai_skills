---
name: 高频fan-in回调不应逐次打印常规binlog
description: nrmactest中的高频fan-in回调如handleRlcSduEvent和handleUlschEvent不应在每次进入时打印info级binlog，以免淹没真正的接入异常信号
type: user-feedback
created: 2026-03-25T17:05:00+08:00
updated: 2026-03-25T17:05:00+08:00
---

# 用户主动纠错

## 场景

在为 `nrMacTest` attach 流程补 `mac-ut` binlog 时，初始方案在 `handleRlcSduEvent()` 和 `handleUlschEvent()` 这类 fan-in 回调入口添加了常规 `INFO` 日志。用户指出，这两个接口会接收所有下行 RLC SDU 和所有 ULSCH 事件，请求去掉逐次进入日志，避免 binlog 过于频繁。

## 用户预期

对于高频 callback 或 fan-in 入口，不应因为“能看到流程经过”就默认增加每次进入都打印的普通日志。真正有价值的日志应该聚焦在异常分支、丢弃原因、路由不匹配、一次性状态跃迁和关键控制节点，而不是把每次正常流经都记录下来。

## 需求

在设计调试日志时，要先判断调用点是否是高频聚合入口。如果该入口会承接大量正常流量，则默认禁止逐次 `INFO` 打印，只保留异常、拒绝、超时、错配、失败和一次性状态变化日志，确保最终 binlog 对定位问题仍然有信噪比。
