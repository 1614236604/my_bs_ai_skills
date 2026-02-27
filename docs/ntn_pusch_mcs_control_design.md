# PUSCH MCS 控制方案设计文档

## 1. 背景与问题分析

### 1.1 核心矛盾

gNB 通过 DCI 为 UE 指定 PUSCH 的 MCS。MCS 选择依赖上行信道质量反馈（SINR/BLER），但反馈存在固有时延：

```
DCI下发 → UE收到DCI → UE发送PUSCH → gNB解码 → 反馈生效
         |<---------- 反馈时延 ---------->|
```

| 场景 | 单程时延 | 反馈RTT | K-Offset (典型) | 影响DCI数 (10ms周期) |
|------|---------|---------|-----------------|---------------------|
| TN   | <1 ms   | ~1-4 ms | 0               | 0-1                 |
| LEO  | 4-20 ms | 8-40 ms | 20-40 slot      | 1-4                 |
| GEO  | 120-140 ms | 240-540 ms | 240-540 slot | 24-54            |

**核心问题**：从 gNB 发现 BLER 异常到 MCS 调整生效，中间存在一个"不可控窗口"，该窗口内已下发和将下发的 DCI 全部使用错误的 MCS。窗口越大（GEO），错误扩散越严重。

### 1.2 传统 OLLA 在 NTN 下的失效

传统外环链路自适应（OLLA）基于 ACK/NACK 调整 SINR 偏移量：

```
SINR_effective = SINR_measured + OLLA_offset
ACK:  offset += step_up    (典型 0.1 dB)
NACK: offset -= step_down  (典型 0.9 dB, 对应10% BLER目标)
```

在 NTN 下失效原因：

1. **反馈过时**：收到 NACK 时，对应的信道状态已是数百毫秒前的，校正方向可能已错误
2. **收敛过慢**：需 100-200 个样本收敛，GEO 下每秒仅数个样本，收敛需 10-20 秒
3. **错误扩散**：一次 NACK 触发下调，但下调生效前已有数十个 DCI 使用了过高的 MCS
4. **HARQ Mode B 下反馈滞后**：NTN 常用 HARQ Mode B（不等解码结果即调度重传），虽然解码结果最终可用，但 OLLA 的逐次反馈调整节奏被打乱

### 1.3 PUSCH 动态业务特性

与 PDSCH 不同，PUSCH 是按需调度的：

- UE 可能长时间无上行数据（无 BSR/SR），此时无 PUSCH 调度，无信道反馈
- 突发大量上行数据时，短时间内密集调度，需要快速且准确的 MCS
- 业务间歇期信道条件可能已发生显著变化（卫星移动、波束切换、大气条件）
- 不同 UE 的上行活跃度差异极大

这要求 MCS 控制方案能处理**非连续、非均匀**的调度模式。

## 2. 设计目标

| 编号 | 目标 | 描述 |
|------|------|------|
| G1 | 统一框架 | 同一算法适配 TN / NTN-LEO / NTN-GEO，通过参数化区分行为 |
| G2 | 快速冷启动 | 基于信道指标快速确定安全初始 MCS，避免盲目保守 |
| G3 | 稳态 BLER 收敛 | 稳定运行时 BLER 收敛到目标范围（默认 10%） |
| G4 | 错误扩散抑制 | 限制 MCS 误判影响的 DCI 数量 |
| G5 | 动态业务适配 | 正确处理 PUSCH 间歇性调度和突发流量 |
| G6 | 可观测性 | 提供足够的统计指标和日志支持调试与调优 |

## 3. 系统模型与假设

### 3.1 可用的上行信道指标

gNB 侧可获取以下上行信道质量信息：

| 指标 | 来源 | 时效性 | 可用性 | 说明 |
|------|------|--------|--------|------|
| SRS SINR | UE 发送的 SRS | 实时（无K-Offset延迟） | **可选** | 频域/空域信道估计，最可靠的信道质量来源 |
| PUSCH DMRS SINR | PUSCH 解调参考信号 | 实时（传输后测量） | 有PUSCH时可用 | 反映实际传输时的信道质量 |
| PHR | UE 功率余量报告 | 周期性/事件触发 | 可用 | 判断 UE 是否功率受限，约束 MCS 上限 |
| HARQ ACK/NACK | PUSCH 解码结果 | 实时（gNB本地） | 始终可用 | BLER 统计输入（解码在gNB侧完成） |

**关键认识**：SRS SINR 和 PUSCH DMRS SINR 均为 gNB 本地测量，**不受 K-Offset 延迟影响**。但 SRS 功能的稳定性在当前阶段未充分验证，因此方案必须在 SRS 不可用时仍能正常工作。

### 3.2 信道信息模式

根据 SRS 可用性，定义两种信道信息模式：

| 模式 | SRS | SINR 来源 | MCS Ceiling 更新 |
|------|-----|-----------|-----------------|
| **模式A：SRS + PUSCH** | 可用 | SRS SINR（主）+ PUSCH DMRS SINR（辅） | SRS 驱动，持续更新 |
| **模式B：纯 PUSCH** | 不可用 | PUSCH DMRS SINR | 每次 PUSCH 解码后更新 |

**模式A（SRS + PUSCH）**：
- SRS 提供持续的、与业务调度无关的信道质量测量
- MCS Ceiling 可实时跟踪信道变化，即使 UE 无上行业务
- PUSCH DMRS SINR 作为校准和预警补充
- 这是信道信息最充分、MCS 控制最可靠的模式

**模式B（纯 PUSCH）**：
- 仅在有 PUSCH 传输时（业务调度或探测调度）获取 PUSCH DMRS SINR
- 无 PUSCH 传输期间信道信息不更新，MCS Ceiling 冻结在最后一次测量值
- 算法通过 `sinr_timestamp` 跟踪 SINR 的新鲜度，SINR 过时时自动采用更保守的策略
- gNB 可选择周期性调度探测 PUSCH（即使 UE 无上行数据）来提高信道跟踪频率，这是调度层面的策略选择，不影响 MCS 控制算法本身

**模式B 下的探测调度（可选）**：
- gNB 可周期性为 UE 调度小量 PUSCH 用于信道探测
- 探测周期建议值：TN 10ms / LEO 50ms / GEO 200ms
- 代价：占用少量上行资源；收益：保持 SINR 新鲜度，避免恢复调度时的保守惩罚
- 是否启用探测调度通过 OAM 配置，不影响 MCS 控制算法逻辑

**模式选择**：通过 OAM 配置 per cell 或 per UE。推荐 SRS 稳定后使用模式A。

### 3.3 假设

- **A1**：SRS 为可选功能，方案在两种信道信息模式下均可工作
- **A2**：PUSCH 解码在 gNB 本地完成，HARQ ACK/NACK 始终可用于 BLER 统计
- **A3**：HARQ 模式可能为 Mode A（等解码结果再重传）或 Mode B（不等解码结果即调度重传），但不影响 BLER 统计
- **A4**：每 UE 独立维护 MCS 控制状态
- **A5**：MCS 表遵循 3GPP TS 38.214 定义（qam64 / qam256 / qam64LowSE）
- **A6**：UE 侧无需任何改动

## 4. 信道指标与 MCS 映射

### 4.1 SINR-to-MCS 映射表

定义 SINR 到 MCS 的映射关系，作为冷启动初始值选择和运行态 MCS 上限的基础。

映射表基于 AWGN 信道下各 MCS 达到 10% BLER 所需的最低 SINR，并附加保守余量：

```
MCS_mapped = MCS_table_lookup(SINR_measured - margin)
```

其中 `SINR_measured` 的来源取决于信道信息模式：
- 模式A：SRS SINR（主），PUSCH DMRS SINR（辅助校准）
- 模式B：PUSCH DMRS SINR

`margin` 为保守余量，同时考虑场景延迟和信道信息模式：

| 场景 | 模式A (SRS) | 模式B (纯PUSCH) |
|------|------------|----------------|
| TN   | 1-2 dB     | 2-3 dB         |
| LEO  | 2-3 dB     | 3-5 dB         |
| GEO  | 3-5 dB     | 5-7 dB         |

模式B 余量更大，因为 SINR 信息可能已过时（无 PUSCH 期间无更新）。当模式B 配合周期探测调度使用时，SINR 保持新鲜，实际可适当减小余量。

映射表为静态配置，可按 MCS 表类型（qam64/qam256）分别定义。

### 4.2 PHR 约束

当 UE 功率受限时（PHR ≤ 阈值），即使 SINR 映射到较高 MCS，实际可用 MCS 也受限：

```
MCS_ceiling = min(MCS_sinr_mapped, MCS_phr_limit)
```

PHR 约束确保不会选择 UE 无法以足够功率发送的 MCS。

### 4.3 MCS Ceiling 的作用与更新

信道指标映射得到的 MCS 值在本方案中作为 **MCS 上限（ceiling）**：

- 冷启动阶段：映射值直接作为初始 MCS
- 稳定运行阶段：映射值作为 MCS 调整的上限，BLER 驱动的上调不得超过此值
- 信道指标突变时：上限随之下调，若当前 MCS 超过新上限则立即下调

MCS Ceiling 的更新频率取决于信道信息模式：

| 模式 | 更新触发 | 更新频率 |
|------|---------|---------|
| 模式A | 每次 SRS 接收 | SRS 周期（通常 10-40ms） |
| 模式B | 每次 PUSCH 解码（业务或探测） | 取决于 PUSCH 调度频率 |

模式B 下若无 PUSCH 传输，MCS Ceiling 冻结在最后一次测量值。配合周期探测调度可保持 ceiling 持续更新。恢复调度时需要检查 SINR 新鲜度（见第 7.4 节和第 8 节）。

## 5. 两阶段状态机

### 5.1 状态定义

```
                    ┌─────────────┐
          ┌────────>│  COLD_START  │<────────┐
          │         └──────┬──────┘         │
          │                │                │
          │         稳定窗口达标            │
          │                │           回落触发
          │                v                │
          │         ┌──────┴──────┐         │
          └─────────│   STEADY    ├─────────┘
           异常回退  └─────────────┘
```

### 5.2 每 UE 状态变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `phase` | enum | COLD_START / STEADY |
| `ch_mode` | enum | MODE_A / MODE_B（信道信息模式） |
| `mcs_current` | int | 当前使用的 MCS |
| `mcs_ceiling` | int | 信道指标映射的 MCS 上限 |
| `mcs_safe` | int | 最近确认稳定的 MCS |
| `sinr_last` | float | 最近一次 SINR 测量值（SRS 或 PUSCH DMRS） |
| `sinr_timestamp` | int | sinr_last 的测量时间（TTI） |
| `bler_window` | 固定数组 | 最近 N 次 HARQ 结果（ACK=0/NACK=1） |
| `bler_estimate` | float | 当前 BLER 估计值 |
| `idle_counter` | int | 无 PUSCH 调度的连续 TTI 计数 |
| `probe_state` | struct | 试探状态（方向、剩余窗口、分配比例） |
| `lock_timer` | int | 回退后锁定上调的剩余 TTI |
| `consec_nack` | int | 连续 NACK 计数 |

## 6. 冷启动阶段

### 6.1 触发条件

以下任一条件触发进入冷启动阶段：

- UE 首次建立上行连接（初始接入）
- 从稳定阶段回落（见第 8 节）
- UE 重配置导致信道条件重置（如波束切换、BWP 切换）

### 6.2 初始 MCS 选择

初始 MCS 的选择取决于信道信息模式：

**模式A（SRS 可用）**：
```
mcs_initial = SINR_to_MCS(srs_sinr - margin_coldstart)
mcs_ceiling = SINR_to_MCS(srs_sinr - margin_ceiling)
mcs_current = min(mcs_initial, mcs_ceiling)
mcs_safe    = mcs_current
```

**模式B（纯 PUSCH）**：
```
首次 PUSCH 调度前（无任何 SINR 信息）：
  mcs_current = MCS_conservative_default  // 预配置的保守初始值（如 MCS 2-4）
  mcs_safe    = mcs_current

首次 PUSCH 解码后：
  mcs_ceiling = SINR_to_MCS(pusch_dmrs_sinr - margin_coldstart)
  若 mcs_ceiling > mcs_current：
    // 信道比预期好，但不立即跳升，留给冷启动上探
    不调整 mcs_current
  若 mcs_ceiling < mcs_current：
    mcs_current = mcs_ceiling
    mcs_safe = mcs_current
```

模式B 的首次调度必须使用保守 MCS，因为此时没有任何信道质量信息。`MCS_conservative_default` 通过 OAM 配置，建议值：TN MCS 4 / LEO MCS 2 / GEO MCS 0-2。

### 6.3 冷启动上探

冷启动阶段的目标是快速找到可用的 MCS 工作点，策略为**逐步上探 + 窗口确认**：

```
每个探测周期（T_ramp TTI）：
  1. 若 mcs_current < mcs_ceiling 且 bler_estimate ≤ target_bler：
     → mcs_current += 1（试探上调）
     → 等待一个反馈窗口（feedback_delay）收集 BLER
  2. 若窗口内 bler_estimate ≤ target_bler + hysteresis：
     → 接受该 MCS，更新 mcs_safe = mcs_current
     → 继续下一轮上探
  3. 若窗口内 bler_estimate > target_bler + hysteresis 或 consec_nack ≥ N_fallback：
     → 回退：mcs_current = mcs_safe
     → 停止上探，准备进入稳定阶段
```

### 6.4 退出条件

满足以下条件时退出冷启动，进入稳定阶段：

- 连续 `N_stable_windows` 个反馈窗口内 BLER 均在目标范围内（`target_bler ± hysteresis`）
- 或上探被回退终止（以当前 `mcs_safe` 进入稳定阶段）

| 参数 | TN | LEO | GEO |
|------|-----|-----|-----|
| `T_ramp` (探测间隔) | 2 TTI | 10 TTI | 20 TTI |
| `margin_coldstart` | 2 dB | 4 dB | 6 dB |
| `N_stable_windows` | 2 | 3 | 3 |

## 7. 稳定阶段

### 7.1 概述

稳定阶段的核心原则：**慢升快降，试探确认**。

- 上调：保守试探，多窗口确认后才正式提升
- 下调：并行探测多个候选 MCS，快速定位安全工作点
- 所有调整受 `mcs_ceiling`（信道指标映射上限）约束

### 7.2 上调策略（慢升试探）

当 BLER 持续低于目标，说明当前 MCS 可能过于保守，可尝试上调：

**触发条件**：
- `bler_estimate < target_bler - hysteresis`（BLER 显著低于目标）
- `lock_timer == 0`（未处于回退锁定期）
- `mcs_current < mcs_ceiling`（未达到信道指标上限）

**试探过程**：

```
阶段1 — 试探窗口（1个反馈窗口）：
  在该窗口的调度中，按比例分配：
  - 80% 的 PUSCH 调度使用 mcs_current（保底）
  - 20% 的 PUSCH 调度使用 mcs_current + 1（试探）
  分别统计两个 MCS 的 BLER

阶段2 — 确认窗口（1-2个反馈窗口）：
  若试探 MCS 的 BLER ≤ target_bler + hysteresis：
  → 提升试探比例到 50%，继续观察
  若确认窗口 BLER 仍满足条件：
  → 正式提升：mcs_current += 1，更新 mcs_safe

  若任一窗口 BLER 超标：
  → 取消试探，维持 mcs_current 不变
  → 设置短暂冷却期（T_cooldown），避免频繁试探
```

**设计意图**：
- 比例分配而非全量切换，确保试探失败时大部分调度仍使用安全 MCS
- 多窗口确认避免因信道瞬时波动导致的误升
- 20%→50% 的渐进比例让系统逐步建立对新 MCS 的信心

### 7.3 下调策略（并行探测）

当 BLER 超标，需要快速找到安全的更低 MCS：

**触发条件**：
- `bler_estimate > target_bler + hysteresis`（BLER 显著高于目标）
- 或 `consec_nack ≥ N_fallback`（连续 NACK 达到阈值）

**并行探测过程**：

```
探测窗口（1个反馈窗口）：
  将该窗口内的 PUSCH 调度按比例分配到多个候选 MCS：
  - 40% 使用 mcs_current - 1
  - 30% 使用 mcs_current - 2
  - 30% 使用 mcs_current - 3
  分别统计各候选 MCS 的 BLER

判定逻辑：
  从高到低检查候选 MCS：
  1. 若 MCS-1 的 BLER ≤ target_bler：
     → mcs_current = mcs_current - 1（最小下调）
  2. 若 MCS-1 超标但 MCS-2 满足：
     → mcs_current = mcs_current - 2
  3. 若 MCS-2 也超标：
     → mcs_current = mcs_current - 3（最大下调）
  4. 若所有候选均超标：
     → mcs_current = mcs_current - 3，并触发回退到冷启动

  更新 mcs_safe = mcs_current
  设置 lock_timer = T_lock（锁定上调一段时间）
```

**设计意图**：
- 并行探测一个窗口即可定位安全 MCS，比逐步下调快 2-3 个窗口
- 在 GEO 场景下，每个窗口代表数百毫秒，节省的时间直接减少错误扩散
- 比例分配确保即使最保守的 MCS-3 也有足够样本做判定

### 7.4 MCS Ceiling 动态响应

`mcs_ceiling` 的更新逻辑因信道信息模式而异：

**模式A（SRS 可用）**：
```
每次 SRS SINR 更新时：
  mcs_ceiling_new = SINR_to_MCS(srs_sinr - margin_ceiling)
  // SRS 持续可用，ceiling 实时跟踪信道
```

**模式B（纯 PUSCH）**：
```
每次 PUSCH 解码后（业务调度或探测调度均可）：
  mcs_ceiling_new = SINR_to_MCS(pusch_dmrs_sinr - margin_ceiling)
  sinr_last = pusch_dmrs_sinr
  sinr_timestamp = current_tti
```

**Ceiling 变化时的通用响应逻辑**（两种模式共用）：
```
若 mcs_ceiling_new < mcs_current：
  → 立即下调：mcs_current = mcs_ceiling_new
  → 更新 mcs_safe = min(mcs_safe, mcs_ceiling_new)
  → 这是唯一不需要等待反馈窗口的下调路径

若 mcs_ceiling_new > mcs_ceiling：
  → 仅更新上限，不主动上调 mcs_current
  → 上调仍需通过 7.2 的试探流程

mcs_ceiling = mcs_ceiling_new
```

**模式B 的 SINR 新鲜度处理**：
模式B 下无 PUSCH 传输时 ceiling 冻结，恢复调度时需检查 SINR 的新鲜度：
```
恢复调度时：
  sinr_age = current_tti - sinr_timestamp
  若 sinr_age > T_sinr_stale：
    // SINR 信息已过时，ceiling 不可信
    // 使用保守策略
    mcs_current = max(mcs_safe - 1, MCS_MIN)
    // 首次 PUSCH 解码后立即更新 ceiling
```

| 参数 | TN | LEO | GEO |
|------|-----|-----|-----|
| `T_sinr_stale` (SINR 过时阈值) | 200 ms | 1 s | 5 s |

**设计意图**：信道指标是实时的（不受 K-Offset 延迟），当信道急剧恶化时可立即响应，不必等待滞后的 BLER 反馈。模式A 下 ceiling 持续更新，是最有效的错误扩散抑制手段；模式B 下 ceiling 的时效性取决于 PUSCH 调度频率，配合周期探测调度可接近模式A 的效果，否则通过 SINR 新鲜度机制自动采用更保守的策略。

### 7.5 稳定阶段参数

| 参数 | TN | LEO | GEO |
|------|-----|-----|-----|
| `target_bler` | 10% | 10% | 10% |
| `hysteresis` | 2% | 3% | 5% |
| `margin_ceiling` | 1 dB | 2 dB | 4 dB |
| `N` (BLER窗口大小) | 20 | max(20, 2×feedback_delay_TTI) | max(50, 2×feedback_delay_TTI) |
| `T_cooldown` (试探冷却) | 5 TTI | 20 TTI | 50 TTI |
| `T_lock` (回退锁定) | 10 TTI | 50 TTI | 200 TTI |
| `N_fallback` (连续NACK阈值) | 5 | 3 | 3 |

## 8. PUSCH 动态业务适配

### 8.1 问题

PUSCH 是按需调度的，UE 的上行活跃度不可预测：

- **间歇性调度**：UE 可能每隔数秒才有一次 PUSCH，BLER 窗口填充极慢
- **突发流量**：UE 突然发送大量数据，短时间内密集调度
- **长时间空闲**：UE 数十秒甚至数分钟无上行，信道条件可能已完全改变

### 8.2 空闲计时与状态老化

每个 UE 维护 `idle_counter`，记录无 PUSCH 调度的连续 TTI 计数：

```
每 TTI：
  若该 UE 本 TTI 无 PUSCH 调度（业务或探测均无）：
    idle_counter += 1
  否则：
    idle_counter = 0
```

空闲时间影响 MCS 控制行为，且因信道信息模式而异：

**模式A（有 SRS 持续输入）**：

| 空闲时长 | 行为 |
|---------|------|
| < T_idle_short | 无影响，正常运行 |
| T_idle_short ≤ x < T_idle_long | BLER 窗口标记为"过时"，恢复调度时重新填充窗口后再做调整决策 |
| ≥ T_idle_long | 回落到冷启动阶段（见 8.4） |

模式A 下即使 UE 无 PUSCH，SRS 仍在持续更新 MCS Ceiling，信道跟踪不中断。

**模式B（无 SRS）**：

空闲期间是否有信道信息取决于是否配置了探测调度。算法不区分这两种情况，统一通过 SINR 新鲜度（`sinr_timestamp`）判断：

| 空闲时长 | 行为 |
|---------|------|
| < T_idle_short | 无影响（但若 SINR 已过时，ceiling 不可信） |
| T_idle_short ≤ x < T_idle_long | BLER 窗口过时，恢复时检查 SINR 新鲜度决定恢复策略（见 8.3） |
| ≥ T_idle_long | 回落到冷启动阶段（见 8.4） |

模式B 的空闲阈值比模式A 更短，因为无 SRS 时信道信息缺失风险更高：

| 参数 | TN | LEO | GEO |
|------|-----|-----|-----|
| `T_idle_short` (模式A) | 100 ms | 500 ms | 2 s |
| `T_idle_long` (模式A) | 1 s | 5 s | 20 s |
| `T_idle_short` (模式B) | 50 ms | 200 ms | 1 s |
| `T_idle_long` (模式B) | 500 ms | 2 s | 10 s |

### 8.3 突发流量处理

当 UE 从空闲恢复到活跃调度时，处理方式因信道信息模式而异：

**模式A（SRS 持续更新 ceiling）**：
```
若 idle_counter 处于 [T_idle_short, T_idle_long) 范围：
  1. 使用 mcs_safe 作为恢复 MCS（而非 mcs_current，因为 mcs_current 可能是试探值）
  2. 清空 bler_window，重新开始 BLER 统计
  3. mcs_ceiling 已是最新的（SRS 持续更新）
  4. 若 mcs_safe > mcs_ceiling：mcs_current = mcs_ceiling
     否则：mcs_current = mcs_safe
  5. 保持在稳定阶段，但暂停试探直到新的 BLER 窗口填满
```

**模式B（检查 SINR 新鲜度）**：
```
若 idle_counter 处于 [T_idle_short, T_idle_long) 范围：
  1. 清空 bler_window
  2. 检查 SINR 新鲜度：sinr_age = current_tti - sinr_timestamp
  3. 若 sinr_age ≤ T_sinr_stale：
     // SINR 仍新鲜（如配置了探测调度），处理同模式A
     mcs_current = min(mcs_safe, mcs_ceiling)
  4. 若 sinr_age > T_sinr_stale：
     // SINR 已过时，ceiling 不可信，额外保守
     mcs_current = max(mcs_safe - 1, MCS_MIN)
     // 首次 PUSCH 解码后立即更新 ceiling
  5. 保持在稳定阶段，暂停试探直到 BLER 窗口填满且 ceiling 已更新
```

### 8.4 稳定→冷启动回落条件

以下任一条件触发从稳定阶段回落到冷启动：

1. **长时间空闲**：`idle_counter ≥ T_idle_long`（模式A/B 各自的阈值）
2. **信道指标剧变**：`|sinr_current - sinr_at_mcs_safe| > sinr_drop_threshold`（模式A 可实时检测；模式B 仅在有 PUSCH 时检测）
3. **连续下调失败**：在稳定阶段连续触发 N 次下调且每次都到 MCS-3 级别
4. **BLER 持续超标**：连续 M 个窗口 BLER 均超过 `target_bler + 2×hysteresis`

回落时的行为：
```
phase = COLD_START
mcs_current = SINR_to_MCS(sinr_measured - margin_coldstart)  // 重新映射
mcs_safe = mcs_current
清空 bler_window
重置 probe_state, lock_timer, consec_nack
```

| 参数 | TN | LEO | GEO |
|------|-----|-----|-----|
| `sinr_drop_threshold` | 6 dB | 6 dB | 6 dB |
| 连续下调失败次数 N | 3 | 3 | 2 |
| 连续超标窗口数 M | 5 | 3 | 2 |

## 9. BLER 统计机制

### 9.1 HARQ 可用时

标准 BLER 统计，基于 HARQ ACK/NACK 的滑动窗口：

```
bler_window: 固定大小 N 的环形缓冲区
每收到一个 HARQ 反馈：
  bler_window[write_idx] = (NACK ? 1 : 0)
  write_idx = (write_idx + 1) % N
  nack_count 更新
  bler_estimate = nack_count / min(sample_count, N)
```

指数平滑（可选，用于减少波动）：
```
bler_smooth = α × bler_estimate + (1 - α) × bler_smooth_prev
```

### 9.2 HARQ Mode B 下的 BLER 统计补充

HARQ Mode B 下 gNB 不等解码结果即调度重传，但解码结果最终仍会返回。此时需注意：

- 解码结果到达时间不确定，BLER 窗口的填充节奏不均匀
- 同一 HARQ process 可能已发起重传后才收到初传的解码结果
- BLER 统计应仅基于**初传**的解码结果（排除重传），以反映 MCS 选择的准确性

```
每收到 PUSCH 解码结果：
  若为初传（非重传）：
    记入 bler_window
  若为重传：
    不计入 BLER 统计（重传成功率反映的是 HARQ 合并增益，非 MCS 适配性）
```

### 9.3 PUSCH DMRS SINR 辅助判断

PUSCH DMRS SINR 在不同模式下承担不同角色：

- **模式A**：辅助预警。SRS SINR 是主要信道信息来源，PUSCH DMRS SINR 用于校验 SRS 估计的准确性，并在 SRS 与实际传输质量偏差较大时提前预警。
- **模式B**：主要信道信息来源。PUSCH DMRS SINR 是 MCS Ceiling 计算的唯一输入，同时更新 `sinr_last` 和 `sinr_timestamp`。

```
每次 PUSCH 解码后：
  sinr_post = PUSCH DMRS SINR（实测值）
  sinr_required = MCS_to_SINR(mcs_current)  // 当前MCS所需的最低SINR

  若 sinr_post < sinr_required：
    → 即使本次解码成功，也预示信道余量不足
    → 模式A：提前预警，可触发 MCS Ceiling 下调
    → 模式B：直接更新 MCS Ceiling
```

### 9.4 反馈对齐

BLER 窗口中的每个样本需要与产生该样本的 MCS 关联：

```
每个 BLER 样本记录：{harq_result, mcs_used, timestamp}

BLER 统计时仅计算 mcs_used == mcs_current 的样本
试探期间分别统计不同 MCS 的 BLER
```

这确保 MCS 变更后，旧 MCS 的反馈不会污染新 MCS 的 BLER 估计。

## 10. DCI 错误扩散抑制

### 10.1 问题量化

从 gNB 检测到 BLER 异常到 MCS 调整生效，中间的 DCI 数量：

```
affected_dci = scheduling_rate × (detection_delay + adjustment_delay)
```

- TN: 1-2 个 DCI（几乎无影响）
- LEO: 5-20 个 DCI
- GEO: 50-200 个 DCI

### 10.2 抑制机制

**机制1：MCS Ceiling 即时响应**（见 7.4）
- 信道指标恶化时立即下调，不等待 BLER 反馈
- 这是最有效的抑制手段，因为 SINR 测量是实时的

**机制2：回退后锁定**
- 触发下调/回退后，设置 `lock_timer = T_lock`
- 锁定期间禁止上调试探，避免反复震荡
- 锁定期间仅允许进一步下调（如果 BLER 仍超标）

**机制3：试探 MCS 阻断**
- 试探失败的 MCS 值记录到阻断列表，阻断时间 `T_block`
- 阻断期间不再试探该 MCS，避免重复踩坑
- `T_block` 应大于信道相干时间（TN: 50 TTI, LEO: 200 TTI, GEO: 500 TTI）

**机制4：单步限幅**
- 任何单次上调不超过 1 级 MCS
- 单次下调不超过 3 级 MCS（并行探测的最大范围）
- 防止极端跳变

## 11. TN / LEO / GEO 行为差异

同一算法框架下，三种场景的行为差异通过参数化实现：

### 11.1 TN 场景简化

TN 场景下反馈延迟极小（1-4ms），方案自然退化为接近传统 OLLA 的行为：
- 冷启动快速完成（2-3 个窗口即可）
- 试探窗口短，确认快
- 并行探测下调在 TN 下也有效，但收益不如 NTN 显著
- 模式A/B 差异不大，因为反馈足够快，BLER 驱动即可满足需求
- 模式B 在 TN 下完全可用，因为业务调度频率通常足够高，SINR 保持新鲜

### 11.2 LEO 场景

- 中等延迟，冷启动需要 3-5 个窗口
- MCS Ceiling 作为重要的即时响应手段
- 并行探测下调显著减少错误扩散
- 推荐模式A（SRS 可用时）；模式B 可用，建议配合探测调度保持信道跟踪

### 11.3 GEO 场景

- 长延迟，冷启动可能需要 5-10 个窗口
- MCS Ceiling 是主要的 MCS 决策依据，BLER 反馈为辅助校准
- 并行探测下调是关键机制（节省 2-3 个窗口 = 节省 1-3 秒的错误扩散）
- 更大的保守余量和更长的锁定时间
- GEO 通常使用 HARQ Mode B，BLER 统计需注意仅计初传结果
- PUSCH DMRS SINR 辅助预警机制在 GEO 下尤为重要（提前于 BLER 反馈发现信道恶化）
- 强烈推荐模式A；模式B 下强烈建议配合探测调度，否则长空闲期间信道可能剧变而无法感知

## 12. 完整参数汇总

### 12.1 通用参数

| 参数 | 说明 | TN | LEO | GEO |
|------|------|-----|-----|-----|
| `target_bler` | 目标 BLER | 10% | 10% | 10% |
| `hysteresis` | BLER 迟滞阈值 | 2% | 3% | 5% |
| `N` | BLER 窗口大小 | 20 | max(20, 2×fd) | max(50, 2×fd) |
| `α` | BLER 指数平滑系数 | 0.3 | 0.2 | 0.1 |
| `T_ramp` | 冷启动探测间隔 | 2 TTI | 10 TTI | 20 TTI |
| `N_stable_windows` | 冷启动退出所需稳定窗口数 | 2 | 3 | 3 |
| `N_fallback` | 连续 NACK 回退阈值 | 5 | 3 | 3 |
| `T_cooldown` | 上调试探冷却期 | 5 TTI | 20 TTI | 50 TTI |
| `T_lock` | 回退后上调锁定时间 | 10 TTI | 50 TTI | 200 TTI |
| `T_block` | 失败 MCS 阻断时间 | 50 TTI | 200 TTI | 500 TTI |
| `sinr_drop_threshold` | SINR 剧变阈值 | 6 dB | 6 dB | 6 dB |
| `MCS_conservative_default` | 无 SINR 时的保守初始 MCS | 4 | 2 | 0-2 |
| 上调试探比例（阶段1） | 试探 MCS 的调度占比 | 20% | 20% | 20% |
| 上调试探比例（阶段2） | 确认阶段的调度占比 | 50% | 50% | 50% |
| 下调并行比例 | MCS-1 / MCS-2 / MCS-3 | 40/30/30 | 40/30/30 | 40/30/30 |

*fd = feedback_delay_in_TTI*

### 12.2 SINR 余量参数（按信道信息模式）

| 参数 | 场景 | 模式A (SRS) | 模式B (纯PUSCH) |
|------|------|------------|----------------|
| `margin_coldstart` | TN | 2 dB | 3 dB |
| | LEO | 4 dB | 5 dB |
| | GEO | 6 dB | 7 dB |
| `margin_ceiling` | TN | 1 dB | 2 dB |
| | LEO | 2 dB | 3 dB |
| | GEO | 4 dB | 5 dB |

模式B 配合周期探测调度时，SINR 保持新鲜，实际可适当减小余量（接近模式A 的值）。

### 12.3 空闲与老化参数（按信道信息模式）

| 参数 | TN | LEO | GEO |
|------|-----|-----|-----|
| `T_idle_short` (模式A) | 100 ms | 500 ms | 2 s |
| `T_idle_long` (模式A) | 1 s | 5 s | 20 s |
| `T_idle_short` (模式B) | 50 ms | 200 ms | 1 s |
| `T_idle_long` (模式B) | 500 ms | 2 s | 10 s |
| `T_sinr_stale` (模式B SINR过时阈值) | 200 ms | 1 s | 5 s |
| `T_probe` (模式B 探测周期，可选) | 10 ms | 50 ms | 200 ms |

## 13. 观测与统计指标

### 13.1 实时指标（per UE）

- `phase`: 当前阶段（COLD_START / STEADY）
- `ch_mode`: 信道信息模式（MODE_A / MODE_B / MODE_C）
- `mcs_current`: 当前 MCS
- `mcs_ceiling`: 信道指标映射上限
- `mcs_safe`: 最近稳定 MCS
- `bler_estimate`: 当前 BLER 估计
- `sinr_last`: 最近一次 SINR 测量值
- `sinr_timestamp`: SINR 测量时间（用于判断过时）
- `idle_counter`: 空闲计数

### 13.2 统计指标（per UE，周期性上报）

- 冷启动次数与平均收敛窗口数
- 上调试探次数 / 成功次数 / 失败次数
- 下调触发次数 / 并行探测结果分布
- 回退次数与原因分布
- MCS 分布直方图
- 平均 BLER 与 BLER 超标时间占比

## 14. 边界情况处理

| 场景 | 处理方式 |
|------|---------|
| SRS 不可用 | 使用模式B（纯 PUSCH），基于 PUSCH DMRS SINR |
| 首次调度无任何 SINR | 使用 MCS_conservative_default 进入冷启动 |
| HARQ Mode B 反馈延迟 | 仅统计初传解码结果，重传结果不计入 BLER（见 9.2） |
| UE 功率受限（PHR 低） | PHR 约束 MCS 上限（见 4.2） |
| 长时间无上行后突发（模式A） | 恢复到 mcs_safe，清空窗口重新统计（见 8.3） |
| 长时间无上行后突发（模式B） | 检查 SINR 新鲜度，过时则额外保守，首次解码后更新 ceiling（见 8.3） |
| 信道指标突降 | MCS Ceiling 即时下调（见 7.4） |
| 模式B 下 SINR 过时 | 恢复调度时额外保守，首次解码后更新 ceiling（见 7.4） |
| 连续下调仍超标 | 回落冷启动（见 8.4） |
| 波束切换/BWP 切换 | 触发冷启动（见 6.1） |
| MCS 已是最低值仍 NACK | 维持最低 MCS，上报告警 |
| 试探期间信道突变 | MCS Ceiling 即时响应，取消进行中的试探 |
| 模式B 探测调度与业务调度冲突 | 业务调度优先，探测调度可跳过本周期 |

