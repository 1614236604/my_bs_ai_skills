---
name: nrMacTest 设计目标与实现原理
description: nrMacTest 作为 DU/MAC 集成测试沙箱的设计定位：真实 DU 内核配合可编排的 PHY/F1/UE 仿真闭环
type: context
created: 2026-03-25T15:19:42+08:00
updated: 2026-03-25T15:19:42+08:00
---

# 项目背景

## 场景
在分析或扩展 nrMacTest 用例、UE simulator、PHY simulator、FAPI builder，或者判断某段逻辑应放在生产代码还是测试假体时，需要先理解 nrMacTest 的设计目标和分层边界。

## 需求
nrMacTest 的目标不是做射频级 PHY 仿真，也不是只对单个 MAC 函数做纯 mock 单元测试，而是在单进程内搭建一个可控的 DU 集成测试沙箱。它保留真实的 DU/MAC/RLC/L2Cell 内核和主要协议边界，用测试假体替代外部 PHY、UE、F1/CU，通过 slot 驱动和事件回调形成接入、调度、上下行反馈的完整闭环。其核心设计意图包括：

- 用真实 DU 内部对象验证 MAC 调度、接入状态机、RLC/F1 衔接等跨模块行为，而不是只验证局部函数输入输出。
- 用语义化测试输入描述 UE 行为，例如 RACH、ULSCH、UCI、SRS 请求，而不是让测试直接操纵底层二进制报文。
- 以 slot 作为统一时间轴，按时序接收 DU 下发的 DL 请求，再延迟构造对应的 UL indication，以覆盖调度相关逻辑对时间推进的依赖。
- 在保持生产逻辑可复用的前提下，把不可控的外部依赖隔离为测试假体，降低构造复杂场景的成本。
- 内建日志和 binlog 观测能力，使同一套测试既可做断言，也可做行为分析和问题定位。

## 关键约束
- nrMacTest 的测试粒度是“组件级集成测试”，不是端到端系统联调；外部 PHY 和 F1/CU 是可控替身，不应把它误解为真实网络环境。
- 真实 DU 内核应尽量保留原有分层和消息边界；新增测试能力时，优先通过 simulator、builder、fixture 扩展，而不是把测试捷径侵入生产调度路径。
- UE simulator 负责生成对 MAC 有意义的反馈语义，例如 HARQ、SR、CSI、CRC、TA、TC、SINR；它不负责做物理层精确解调建模。
- PHY simulator 是全局时钟和事件分发中心；涉及调度时序的问题，优先沿 slot 推进、request/indication 回环和 event hook 链路分析。
- F1 builder 和相关假接口的职责是复现控制面消息边界，不应把控制面配置硬塞进 UE 或 MAC 内部对象，避免破坏测试与真实协议分层的一致性。
