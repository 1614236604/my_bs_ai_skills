# Binlog 系统架构

## 概述

Binlog 是 DU 层的高性能二进制日志系统，用于记录 MAC/RLC 层运行时事件。核心设计目标：

- **零堆分配**：所有缓冲区预分配，写入路径无 malloc/free，满足 TTI 线程实时约束
- **无锁写入**：每线程独立 Writer，通过 lock-free ring queue 传递事件
- **二进制序列化**：参数以二进制格式存储，避免格式化字符串开销

## 组件关系

```
调用点 (BINLOG 宏)
    │
    ▼
SessionWriter (线程本地)        ← 每线程一个，最多 64 个
    │  序列化参数到 RingBuffer
    │  推送 WriterEvent 到 RingQueue
    ▼
Session (全局单例)
    │  持有所有 channel、MetaDB、EventMasker
    │
    ▼
BinOutputStream                 ← 消费端
    │  遍历所有 channel，drain 事件
    │  构建 Source Block + Args Block
    ▼
BinOutputStreamFileIo           ← 文件写入
    │  滚动文件输出 (.00, .01, .02 ...)
    ▼
磁盘文件
```

## 核心组件

### Session（全局会话）

全局单例，系统入口。职责：

- 持有 MetaDB（元数据索引）
- 持有 EventMasker（事件过滤位向量）
- 管理所有线程的 channel（RingQueue 实例）
- 维护 severity 阈值
- 通过 `id(file, line)` 接口为每个调用点分配唯一 ID

### SessionWriter（线程本地写入器）

每个线程拥有独立实例，负责：

- 将变参列表序列化为二进制格式（Serializer）
- 将序列化数据写入预分配的 RingBuffer（65535 字节环形缓冲区）
- 将 WriterEvent 推入该线程的 RingQueue channel（容量 8192）

### MetaDB（元数据数据库）

从编译期生成的二进制元数据文件（`duapp.log.metadata`）加载：

- 文件名 → 行号 → 事件 ID 的映射
- 格式化字符串模板
- 参数类型信息

每个调用点首次执行时通过 `static int _binlog_id` 缓存 ID，后续调用零开销查找。

### BinOutputStream（输出流）

消费端组件，负责：

- 遍历所有线程 channel，弹出所有待处理事件
- 对新出现的事件 ID，生成 Source Block（含元数据）
- 对每个事件，生成 Args Block（含时间戳和序列化参数）
- 通过 BinOutputStreamFileIo 写入磁盘

## 数据流

### 写入路径

1. 调用点执行 `BINLOG(severity, eventId, fmt, args...)`
2. 宏检查：`static _binlog_id` 是否有效 → severity 是否 ≤ 阈值 → event mask 是否启用
3. 任一检查失败则跳过（零开销）
4. 调用 `SessionWriter::write()`：
   - 从 MetaDB 获取事件元数据
   - Serializer 按类型逐个序列化参数到 RingBuffer
   - 构造 WriterEvent（含时间戳、事件 ID、参数偏移/长度）
   - 推入线程 RingQueue

### 消费路径

1. `BinOutputStream::consume()` 被调用（由外部触发，如 flush）
2. 遍历所有已注册的 channel
3. 从每个 channel 的 RingQueue 弹出所有事件
4. 对每个事件：
   - 若该事件 ID 首次出现，写入 Source Block（元数据）
   - 写入 Args Block（时间戳 + 序列化参数）
5. BinOutputStreamFileIo 写入当前文件，必要时触发文件滚动

## 初始化流程

1. MAC OAM 初始化时调用 `initBinloggerSession(metadataPath, severity)`
2. 加载元数据文件到 MetaDB
3. 注册所有事件类型到 SessionEventMgr
4. 读取 `BINLOG_EVENTS` 环境变量，启用指定事件
5. 各工作线程（TTI、MPI、RLC、CTRL）首次写入时自动创建 SessionWriter

## 线程模型

| 线程 | 角色 | 初始化标记 |
|------|------|-----------|
| TTI 线程 | MAC 调度，写入 ULSCH/DLSCH/HARQ 等事件 | `binlog init TTI thread` |
| MPI 线程 | 消息处理，写入通用事件 | `binlog init MPI thread` |
| RLC 线程 | RLC 处理，写入 AM/UM/SRB 事件 | `binlog init RLC thread` |
| CTRL 线程 | 控制面，写入通用事件 | `binlog init CTRL thread` |

每个线程通过 `syscall(SYS_gettid)` 获取线程索引，映射到独立的 SessionWriter 和 channel。
