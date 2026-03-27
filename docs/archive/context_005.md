---
name: MAC TTI线程无堆分配约束与对象池模式
description: MAC TTI循环中禁止动态内存分配，必须使用预分配对象池、DLINK链表、TTI环形缓冲等固定大小数据结构
type: context
created: 2026-03-25T00:00:00+08:00
updated: 2026-03-25T00:00:00+08:00
---

# 项目背景

## 场景
在修改 MAC 调度器、HARQ、资源管理等 TTI 热路径代码时需要遵守的内存约束。任何从 MAC TTI 循环可达的代码路径都受此约束。

## 需求
MAC TTI 线程是实时调度路径，必须保证每个 TTI 周期内的执行时间可预测。动态内存分配（malloc/free/new/delete）的延迟不可预测，因此必须完全禁止。

## 关键约束

### 禁止的操作
- `malloc` / `free` / `new` / `delete`
- STL 容器的增长操作（如 `push_back` 导致的 `vector` 扩容）
- 任何隐式动态分配

### 替代模式

1. **Grant Pool 模式**：`std::vector` 在 `init()` 中一次性 `resize()`，运行时通过 `NrMacList<int>` 的 DLINK 链表做 O(1) 分配/释放，配合 `std::vector<bool>` 位图做去重
2. **DLINK Free List 模式**：固定大小 C 数组作为消息池，用 DLINK 宏实现侵入式链表管理 free/pending 状态，跨线程访问需要 mutex 保护
3. **TTI 环形缓冲模式**：按 TTI 索引的环形数组，用 `tti % windowSize` 访问对应 bucket

### 核心规则
- 所有 `std::vector` 必须在 `init()` 中完成 `resize()`，TTI 路径中绝不允许 `push_back()`
- 空闲列表使用 `NrMacList<int>`（基于 DLINK），保证 O(1) 分配/释放
- 位图使用预分配的 `std::vector<bool>` 做去重
- 小型有界集合使用固定大小 C 数组
- 侵入式链表使用 `DLINK` 宏（零分配）
