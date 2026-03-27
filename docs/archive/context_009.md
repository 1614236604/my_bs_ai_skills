---
name: ODI命令开发规范：线程安全模型与实现模式
description: ODI命令通过NrMacOdiMgr中转OAM线程与TTI线程的数据交换，per-UE状态值使用one-shot模式，配置值可持久覆盖
type: context
created: 2026-03-25T00:00:00+08:00
updated: 2026-03-25T00:00:00+08:00
---

# 项目背景

## 场景
在为 MAC 层添加新的 ODI（OAM Debug Interface）调试命令时需要遵守的架构和线程安全规范。ODI 命令用于运行时调试、参数覆盖和注入测试条件。

## 需求

### 命令流架构
`OAM CLI → ODS Handler → macMdfHandler::handler() → NrMacOdiMgr (共享状态) → TTI 线程读取`

### 线程安全模型

**配置值**（如 maxRssi、targetSinr）：
- OAM 线程直接写入，TTI 线程读取，无需同步
- 属于持久覆盖模式，写入后每个 TTI 都直接使用

**Per-UE 状态值**（如 TPC override）：
- 使用 one-shot 模式保证线程安全
- OAM 线程写入 `NrMacOdiMgr::UeCtrlInfo` 中的 override 字段
- TTI 线程读取、应用、然后清除该 override
- 通过消费者清除值来避免竞态条件和重复应用

### 数据结构
- Cell 级别控制：`CellCtrlInfo`，存储在 `NrMacOdiMgr::m_cellCtrlInfo`
- Per-UE 控制：`UeCtrlInfo`，存储在 `NrMacOdiMgr::m_ueCtrlInfos[ueIndex]`

### 实现四步骤
1. 在 `nrMacOdiCtrlMessageTypes.h` 中添加数据字段（用 sentinel 值表示"无覆盖"）
2. 在 `nrMacOdiMgr.h/.cc` 中添加 accessor 方法（set/get/clear），并在 reset 函数中初始化
3. 在 `macMdfHandler.h/.cc` 中注册命令和实现 handler，包含参数解析、UE 验证、写入 OdiMgr、binlog 记录
4. 在 TTI 线程消费函数中读取 override、应用、清除（one-shot 模式）

## 关键约束

### 禁止的做法
- 禁止从 ODI handler 直接修改 power controller 状态
- 禁止从 OAM 线程直接访问 power controller 获取状态值
- 禁止在 OAM 和 TTI 线程之间使用阻塞同步
- 禁止在访问 per-UE 数据前不验证 UE 是否存在

### 必须的做法
- 所有共享状态通过 NrMacOdiMgr 路由
- per-UE 状态覆盖使用 one-shot 模式
- 每个 ODI 命令必须包含 `BINLOG_WARN("[mac-odi]<command>: <params>")` 日志
- 访问 per-UE 数据前必须通过 `getUeProfile(crnti)` 验证 UE 存在性
