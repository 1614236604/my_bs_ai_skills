---
name: ntn-du-dev
description: "NTN 5G-NR DU layer development guide for MAC/RLC/L2App modules. Use when writing or modifying C/C++ code in src/duapp/ — covers TTI thread no-malloc constraint, object pool patterns, NTN feature development (K-offset, extended HARQ, ephemeris), MAC manager class patterns, RLC mode implementations, MAC-RLC interface, binlog binary logging system, and code conventions. Triggers on: writing MAC scheduler code, adding NTN features, creating new manager classes, modifying HARQ/grant/resource allocation, RLC AM/UM/TM changes, adding binlog trace points."
---

# NTN DU Development Guide

## Critical: TTI Thread No-Malloc Constraint

All code paths reachable from MAC TTI processing loop MUST NOT allocate/free heap memory.

**Prohibited in TTI thread:**
- `malloc`/`free`/`new`/`delete`
- `std::vector::push_back` (may realloc), `std::map::insert`, `std::string` construction
- Any STL container operation that may allocate

**Required patterns:**
- Pre-allocated fixed-size arrays
- Object pools with DLINK free lists
- Bitmap-based tracking for O(1) lookup
- All containers sized in `init()`, never resized during TTI

For detailed pool patterns, see [references/object-pool-patterns.md](references/object-pool-patterns.md).

## MAC Manager Class Pattern

```cpp
// Header: mac/src/nrMac<Name>Mgr.h (or mac/export/ if public)
class NrMac<Name>Mgr {
public:
    void init(NrMacConfigExtender* config, int maxUes);
    void reset();
private:
    std::vector<T> m_pool;      // Sized once in init(), never resized
    NrMacList<int> m_freeList;  // Free index tracking
};
```

- Scheduling managers inherit from `NrMacChannelSchedulingNode`
- Config access via `NrMacConfigExtender*`
- Guard NTN code with `#ifdef CONFIG_NTN`

## NTN Config Access

Key NTN parameters via `NrMacConfigExtender`:
```cpp
configExtender->getKCellOffset();              // K-offset (propagation delay)
configExtender->kOffset_slots();               // K-offset in slots
configExtender->getNumberOfHarqProcessExtend(); // Extended HARQ processes
configExtender->getUlHarqModeV17();            // UL HARQ mode bitmap
configExtender->getDlHarqFeedbackDisableV17(); // DL HARQ feedback disable
configExtender->maxNumberOfRecordTtiUl();      // Max TTI recording window
```

OAM config via `ConfigDataT` struct: `kCellOffset`, `nrOfHarqProcessExt`, `ulHarqMode[]`, `dlHarqFeedbackDisable[]`.

## Binlog Binary Logging

高性能二进制日志系统，零堆分配，满足 TTI 线程实时约束。源码位于 `src/duapp/binlog/`。

**调用宏**（头文件 `binlog/binlogger.h`）：
```cpp
BINLOG_DEBUG(fmt, ...)                    // 通用调试
BINLOG_INFO(fmt, ...)                     // 通用信息
BINLOG_WARN(fmt, ...)                     // 通用警告
BINLOG_ERROR(fmt, ...)                    // 通用错误
BINLOG_TRACE(eventId, fmt, ...)           // 特定事件追踪
```

**事件类型**（用于 `BINLOG_TRACE` 的第一个参数）：
- `SESSION_EVENT_MAC_UCI` / `MAC_ULSCH` / `MAC_ULSCH_HARQ` / `MAC_ULSCH_RETX`
- `SESSION_EVENT_MAC_DLSCH` / `MAC_DLSCH_HARQ` / `MAC_DLSCH_RETX`
- `SESSION_EVENT_MAC_TA` / `MAC_DLLA`
- `SESSION_EVENT_MAC_CSI` / `MAC_SRS`
- `SESSION_EVENT_RLC_AM_SRB` / `RLC_AM_DRB` / `RLC_UM_DRB`

**Binlog 与 TAG_TRACE 共存策略**：

高频路径（TTI级别）同时保留 BINLOG_TRACE 和 TAG_TRACE，两者互补：
- BINLOG_TRACE：事件开启时提供精细过滤和二进制高效记录
- TAG_TRACE：事件未开启时仍可用于初步排查流程走向

```cpp
// 正确做法：binlog 在前，trace 在后，共存
BINLOG_TRACE(binlog::SESSION_EVENT_MAC_SRS,
    "[mac-srs]handleSrsInfo: ue=%d histSnr=%d phySnr=%d",
    ueProfile->crnti, (int)srs_data->widebandSnr, phyUlSrs->widebandSnr);

TAG_TRACE_C3(TT_GENERAL_INFO_MASK, MAC_UPT_3275,
    "srsDebug handleSrsInfo: ue=%u, srs_data->widebandSnr=%d, phyUlSrs->widebandSnr=%d\n",
    ueProfile->crnti, (int)srs_data->widebandSnr, phyUlSrs->widebandSnr);
```

**TAG_TRACE 日志ID管理规则**（定义在 `mac/export/macTrace.h`）：
- 不要随意删除已有的 TAG_TRACE，它们在 binlog 事件未开启时仍有排查价值
- 如需移除某个 TAG_TRACE，必须将对应 `MAC_UPT_xxxx` 注释恢复为 `// not used`
- 如需新增 TAG_TRACE，先在 macTrace.h 中找标记为 `// not used` 的空闲ID使用，并更新注释为实际用途
- 如果没有空闲ID，在枚举末尾追加新ID

低频路径（控制面操作如 UE 接入/释放）直接使用 `BINLOG_INFO`，无需配合 TAG_TRACE。

**异常路径日志覆盖（强制规则）**：

任何异常检测返回**禁止静默返回**，必须有日志输出。根据调用频率选择级别：

| 路径频率 | 日志方式 | 说明 |
|---------|---------|------|
| 低频（控制面、配置、接入/释放等） | `BINLOG_WARN` 或 `BINLOG_ERROR` | 直接输出，无需事件过滤 |
| 高频（TTI 级别、调度、HARQ 等） | `BINLOG_TRACE(binlog::SESSION_EVENT_xxx, ...)` | 使用已有事件或新增事件输出，避免日志风暴 |

- `BINLOG_ERROR`：不可恢复的异常（空指针、越界、无效状态等 "should never go here" 路径）
- `BINLOG_WARN`：可恢复但需关注的异常（超时、资源不足、重试等）
- 高频路径的异常如果没有合适的已有事件，需要新增 `SESSION_EVENT_xxx` 事件来承载
- 格式：包含关键上下文（UE ID、索引值、边界值等），便于定位根因

```cpp
// 异常路径示例：越界检查
if(ue_idx >= static_cast<int>(this->m_ueRsrcInfos.size()))
{
    BINLOG_ERROR("[mac-srs]registerBWP: ue=%d ueIdx=%d out of range(%d)",
        ueProfile->crnti, ue_idx, (int)this->m_ueRsrcInfos.size());
    return;
}
```

**使用模式**：
```cpp
// MAC HARQ 追踪
BINLOG_TRACE(binlog::SESSION_EVENT_MAC_ULSCH_HARQ,
    ue=%d harqId=%d ndi=%d rv=%d, ueId, harqId, ndi, rv);

// RLC 吞吐统计
BINLOG_INFO(ue=%d lcid=%d AM_DL total/in/drop: %u/%u/%u,
    ue, lcid, total, in, drop);
```

**关键约束**：
- 写入路径无锁、无堆分配（每线程独立 SessionWriter + lock-free RingQueue）
- 支持 14 种参数类型，单事件参数上限 1024 字节
- 事件通过环境变量 `BINLOG_EVENTS` 控制启用（如 `mac-ulsch|mac-dlsch|all`）
- 详细设计文档：`docs/binlog_architecture.md`、`docs/binlog_event_and_config.md`、`docs/binlog_binary_format.md`

**日志级别选择规范**：
- `BINLOG_TRACE(binlog::SESSION_EVENT_xxx, ...)` — 正常处理路径的关键节点（调度、FAPI 构建、indication 接收、事件处理等），用于流程追踪；高频异常路径也使用此级别通过事件输出
- `BINLOG_INFO(...)` — 低频控制面操作（UE 接入/释放、配置变更、资源分配/释放等）
- `BINLOG_ERROR(...)` — 不可恢复的异常（空指针、越界、无效状态等 "should never go here" 路径），低频场景直接输出
- `BINLOG_WARN(...)` — 可恢复但需关注的异常（超时、资源不足等），低频场景直接输出

**日志格式一致性规范**：
- 模块前缀统一：`[mac-srs]`、`[mac-csi]`、`[mac-harq]` 等，与 binlog 事件注册名一致
- UE 标识统一使用 `ue=%d`（值为 crnti），禁止使用 `ueId=`、`ueID=`、`crnti=` 等变体
- 当 ue_profile 不可用时（如异常路径），可使用原始字段名如 `crntiIndex=%d`
- 关键字段命名统一：`sfn=%d tti=%d`（时间）、`bwp=%d`（BWP ID）、`peri=%d offset=%d`（周期性）
- 异常日志包含足够上下文：索引值、边界值、无效参数值，便于定位根因

**新增 binlog 覆盖的检查清单**：
为某个模块增加 binlog 覆盖时，确保以下环节都有日志：
1. FAPI PDU 构建（发送侧）— BINLOG_TRACE，记录关键 PDU 参数
2. PHY Indication 接收（接收侧）— BINLOG_TRACE，记录测量结果
3. 事件通知/分发 — BINLOG_TRACE，记录 UE 和时间信息
4. 事件处理/消费 — BINLOG_TRACE，记录处理结果
5. 所有异常返回路径 — BINLOG_ERROR，记录异常原因和上下文
6. 配置/资源变更 — BINLOG_INFO，记录变更前后状态

### 解析 Binlog 日志文件

使用 `tools/binlog_parser.py` 解析二进制日志文件（如 `ttilog.0.00`），无外部依赖：

```bash
# 查看前 20 条日志
python3 tools/binlog_parser.py <logfile> -n 20

# 查看最后 10 条
python3 tools/binlog_parser.py <logfile> --tail 10

# 按严重级别过滤（EMERG/ALERT/CRIT/ERROR/WARN/NOTICE/INFO/DEBUG）
python3 tools/binlog_parser.py <logfile> -s WARN

# 按消息内容过滤
python3 tools/binlog_parser.py <logfile> -g harqId

# 按源文件过滤
python3 tools/binlog_parser.py <logfile> --file-filter rach.cc

# 统计各调用点事件数量
python3 tools/binlog_parser.py <logfile> --stats
```

日志文件位于 `src/components/rootfs/oam/log/`，文件名格式 `ttilog.<cell>.<seq>`。

## MAC-RLC Interface

Virtual interface pattern in `macRlcIntf.h`. Communication via `MacRlcMsgQ` (pre-allocated message queue with DLINK free list, `pthread_mutex_t` for thread safety).

## Build Rules

- 编译验证统一使用 `make -j8 do_strip=1`
- **禁止**使用 `make clean`、`make clean_<mod>` 或任何 clean 相关命令

## Code Conventions

- C99/C++11, headers `.h`, implementations `.cc`
- Export headers: `<module>/export/`, internal: `<module>/src/`
- Build rules: `src/components/callp/<module>/Makefile`
- Types: `Uint32`, `Uint16`, `Uint8` (project typedefs), `NrMacSlotInd` for slot timing
- NTN PUSCH MCS control algorithm: see `docs/ntn_pusch_mcs_control_design.md`
