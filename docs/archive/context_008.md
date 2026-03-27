---
name: Binlog日志系统规范与TAG_TRACE共存规则
description: TTI热路径使用BINLOG_TRACE保证实时安全，异常路径必须有日志覆盖，TAG_TRACE与Binlog需共存时各有分工
type: context
created: 2026-03-25T00:00:00+08:00
updated: 2026-03-25T00:00:00+08:00
---

# 项目背景

## 场景
在为 MAC 模块添加日志、修改现有 trace 代码、或审查模块日志覆盖率时需要遵守的规范。

## 需求
Binlog 是专为 TTI 安全设计的高性能二进制日志系统，用于在不违反实时约束的前提下保留可观测性。

### API 分级
- 高频路径：使用 `BINLOG_TRACE(eventId, ...)` —— 事件门控的结构化追踪
- 低频控制路径异常：使用 `BINLOG_WARN` 或 `BINLOG_ERROR`
- 一般信息：使用 `BINLOG_DEBUG` / `BINLOG_INFO`

### TAG_TRACE 共存
- 热路径中 `TAG_TRACE` 和 `BINLOG_TRACE` 需要同时保留，各有分工
- `BINLOG_TRACE`：事件门控的结构化追踪
- `TAG_TRACE`：当 binlog 事件未启用时的轻量回退
- 删除 `TAG_TRACE` 时必须同步更新 `mac/export/macTrace.h` 中的 `MAC_UPT_xxxx` 条目

## 关键约束

### 异常覆盖规则
- 禁止在异常条件下静默 return，必须添加日志
- 日志需包含足够上下文：UE 身份、索引值、边界值、相关时间信息

### 格式规范
- 使用模块前缀如 `[mac-srs]`、`[mac-harq]`
- UE 标识使用 `ue=%d`（基于 CRNTI）
- 时间字段使用 `sfn=%d tti=%d`

### 模块日志覆盖检查清单
1. FAPI PDU 构建路径
2. PHY indication 接收路径
3. 事件分发路径
4. 事件消费/处理路径
5. 异常返回路径
6. 低频配置/资源转换路径
