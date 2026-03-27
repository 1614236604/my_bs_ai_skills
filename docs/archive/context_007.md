---
name: TTI/SFN时间算术wrap处理与UE索引双轨制
description: ttiSfn是循环时间不能裸减法，必须做wrap处理；crntiIndex和ueIndex是两套UE标识系统，禁止混用
type: context
created: 2026-03-25T00:00:00+08:00
updated: 2026-03-25T00:00:00+08:00
---

# 项目背景

## 场景
在编写涉及时间比较、时间差计算、UE 状态查找和索引的 MAC 调度代码时需要遵守的规则。这是高频出错点。

## 需求

### 时间语义
MAC 调度代码使用三个相关的时间概念：
- `tti`：SFN 帧内的 slot 索引，范围 `0 .. TOTAL_CONFIG_TTIS - 1`
- `sfn`：系统帧号，范围 `0 .. 1023`
- `ttiSfn`：`sfn * slotsPerFrame + tti`，每个 SFN 周期循环

### UE 索引双轨制
MAC 代码中有两套 UE 标识符，语义完全不同：
- `crntiIndex`：稀疏全局索引，用于 `ueProfileCollection[]`，包含预留范围
- `ueIndex`：密集的 manager-local 索引，通过 `NrMacConnectedUeIndexMgr::ueIndex(crntiIndex)` 派生，用于 manager 内部向量索引

## 关键约束

### 时间算术规则
- **禁止裸减法**：不能直接用 `currentTtiSfn - lastTtiSfn` 计算经过时间，因为 ttiSfn 会在 SFN 周期边界回绕
- **禁止裸比较**：不能用 `if(currentTtiSfn <= lastTtiSfn) return;` 判断时间先后
- **正确做法**：手动计算 delta 并处理 wrap，当 current < last 时用 `(maxTtiSfn - last) + current`
- **防异常 delta**：当 delta 超过 `maxTtiSfn / 2` 时视为异常丢弃
- `NrMacSlotInd` 支持 `+offset` 和 `-offset` 运算，但不支持两个 `NrMacSlotInd` 相减得到整数 delta
- 内部单调时间戳推荐使用 `int64_t`

### UE 索引规则
- **禁止混用**：绝不能用 `crntiIndex` 直接索引 manager-local 的 vector
- **正确做法**：先通过 `NrMacConnectedUeIndexMgr::getInstancePtr()->ueIndex(crntiIndex)` 获取 ueIndex，检查有效性（`>= 0` 且 `< size()`），再用 ueIndex 索引
