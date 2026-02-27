# Binlog 二进制存储格式

## 文件组织

### 滚动文件

输出文件采用滚动编号：`<basepath>.00`, `<basepath>.01`, `<basepath>.02` ...

- 单文件大小超限时自动切换到下一个文件
- 文件数量达到上限时回绕覆盖最早的文件
- 每个新文件开头重新写入文件头和当前已知的 Source 元数据

### 元数据文件

`duapp.log.metadata` — 编译期生成的二进制文件，包含所有调用点的元数据（文件名、行号、格式化字符串、参数类型）。运行时由 MetaDB 加载并索引。

## 文件格式

```
┌─────────────────────────────────┐
│         StreamFileHdr           │  12 bytes
├─────────────────────────────────┤
│  StreamBlockHdr (SOURCE)        │  8 bytes
│  StreamSourcePdu × N            │  变长
├─────────────────────────────────┤
│  StreamBlockHdr (ARGS)          │  8 bytes
│  StreamArgsPdu × M              │  变长
├─────────────────────────────────┤
│  StreamBlockHdr (SOURCE)        │  （新事件 ID 首次出现时）
│  StreamSourcePdu × ...          │
├─────────────────────────────────┤
│  StreamBlockHdr (ARGS)          │
│  StreamArgsPdu × ...            │
├─────────────────────────────────┤
│           ...                   │
└─────────────────────────────────┘
```

## 数据结构

### StreamFileHdr（文件头）

```
偏移  大小    字段          值
0     4B     fileType      0xA0A0A0A0
4     4B     magicCode     0x1A2B3C4D
8     1B     major         1
9     1B     minor         0
10    2B     reserved      0
```

用于文件识别和版本校验。

### StreamBlockHdr（块头）

```
偏移  大小    字段          说明
0     4B     size          块总大小（含头）
4     1B     blockType     0=SOURCE, 1=ARGS
5     1B     reserved      0
6     2B     numOfEvents   本块包含的事件/元数据条目数
```

每个块包含同一类型的多条记录。

### StreamSourcePdu（事件元数据）

```
偏移  大小    字段          说明
0     4B     id            事件 ID
4     4B     severity      严重级别
8     4B     fmtStrSize    格式化字符串长度
12    4B     fileStrSize   源文件名长度
16    4B     line          源代码行号
20    4B     numOfParas    参数个数
24    var    fmtStr        格式化字符串（如 "ue=%d harqId=%d"）
var   var    fileStr       源文件路径
var   var    paramTypes    参数类型数组（每个 1 byte）
```

每个事件 ID 在文件中只写入一次 Source 记录。文件滚动时，所有已知事件的 Source 记录会重新写入新文件头部。

### StreamArgsPdu（事件参数）

```
偏移  大小    字段          说明
0     8B     clock         纳秒级时间戳（CLOCK_REALTIME）
8     4B     id            事件 ID（关联到 SourcePdu）
12    4B     size          参数载荷大小
16    var    payload       序列化的参数数据
```

### 参数序列化

参数按调用顺序逐个序列化，每个参数前置 1 字节类型标记：

| 类型标记 | 类型 | 大小 |
|---------|------|------|
| 0 | bool | 1B |
| 1 | char | 1B |
| 2 | int8 | 1B |
| 3 | uint8 | 1B |
| 4 | int16 | 2B |
| 5 | uint16 | 2B |
| 6 | int32 | 4B |
| 7 | uint32 | 4B |
| 8 | float | 4B |
| 9 | double | 8B |
| 10 | int64 | 8B |
| 11 | uint64 | 8B |
| 12 | pointer | 8B |
| 13 | string | 变长（含长度前缀） |

单条事件参数载荷上限 1024 字节。

## 解码流程

要还原可读日志，解码器需要：

1. 读取文件头，校验 magicCode
2. 逐块读取：
   - SOURCE 块：建立 eventId → (格式化字符串, 文件名, 行号, 参数类型) 的映射
   - ARGS 块：对每条 ArgsPdu：
     a. 用 eventId 查找对应的 Source 元数据
     b. 按参数类型列表反序列化 payload
     c. 将参数填入格式化字符串
     d. 输出：`[timestamp] [severity] [file:line] formatted_message`

## 性能特征

| 指标 | 值 |
|------|---|
| 每线程 RingBuffer | 65535 字节，预分配 |
| 每线程 RingQueue | 8192 条事件，预分配 |
| 最大线程数 | 64 |
| 单事件参数上限 | 1024 字节 |
| 时间戳精度 | 纳秒（CLOCK_REALTIME） |
| 写入路径锁 | 无（lock-free ring queue） |
| 堆分配 | 无（写入路径零 malloc） |
