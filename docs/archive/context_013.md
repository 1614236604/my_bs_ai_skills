---
name: nrMacTest 接入流程与实际流程的差异
description: nrMacTest 中 UE attach 流程的完整消息序列（msg1→msg5→F1→reconfig→attached）与真实接入流程的主要差别
type: context
created: 2026-03-25
updated: 2026-03-25
---

# 项目背景

## 场景
在编写或调试 nrMacTest 接入相关用例（RACH、SRB 建立、DRB 建立）时，需要理解测试沙箱中 attach 流程与实际网络接入流程的差异，避免将测试简化逻辑误认为真实协议行为。

## 需求
nrMacTest 的 attach 流程集中模拟了随机接入（msg1→msg5）和 F1 承载建立两个阶段，但相比实际流程做了以下简化和差异化处理：

### 完整消息序列

1. **msg1**：UE simulator 发送 preamble 发起随机接入
2. **msg2**：PHY simulator 回调 RAR 事件，UE 解析 temp C-RNTI 和 TA，建立 UE FAPI 事件订阅
3. **msg3**：UE 通过 ULSCH 携带 CCCH RLC SDU 发送 RRC Setup Request
4. **msg4**：DU 下发 DL-CCCH MAC SDU，标志 contention resolution 完成
5. **msg5**：msg4 处理完成后将 msg5 RRC SDU 入队到 SRB1 RLC AM（LCID=1），触发 UL 传输。msg5 是承载在 SRB1 上的 RLC AM 消息
6. **msg6（DL RLC SDU）**：DU 侧响应以 DL RLC SDU 形式下发，UE 收到第一个 DL RLC SDU 后触发 F1 UE Context Setup Request
7. **F1 UE Context Setup**：UE simulator 模拟 F1 接口发送 UE Context Setup Request，携带 SRB1/SRB2 和 DRB/cellGroupConfig 信息，一次性建立所有承载
8. **SRB1 重配消息**：DU 处理 UE Context Setup 后下发 RRC Reconfiguration（经 SRB1 RLC AM 传输），UE 接收后通过 RLC status PDU 回 ACK
9. **attached 判定**：SRB1 双向 RLC AM ACK 均完成（TX 侧和 RX 侧的 acknowledged SN 均大于 0）才认为 attach 流程结束

### 与实际流程的主要差异

- **msg5 自动入队**：msg4 处理回调中直接将 msg5 入队 SRB1，没有真实 RRC 层的消息构造和决策过程
- **F1 触发时机**：不是在 msg5 的 RLC ACK 返回后触发，而是在收到第一个 DL RLC SDU（msg6）后触发 UE Context Setup
- **无显式 msg6 建模**：没有独立的 msg6 消息类型，DU 侧响应复用 DL RLC SDU 事件通路
- **attach 完成条件**：基于 SRB1 RLC AM 序列号双向 ACK，而非真实的 RRC Connected 状态上报
- **承载建立集中在 F1 一步**：SRB2 和所有 DRB 在同一个 UE Context Setup Request 中一次性建立

## 关键约束

- UE Context Setup 只触发一次，由首个 DL RLC SDU 到达时的标志位控制
- msg5 RRC payload 是硬编码的字节流，不经过 ASN.1 编码
- attach 判定逻辑基于 SRB1（LCID=1）的 RLC AM 序列号双向确认
- 切换场景走不同分支：msg3 改用 C-RNTI MAC CE 并提前入队 msg5，但后续 attach 判定逻辑相同
