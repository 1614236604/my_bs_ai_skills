# Archive Index

## contexts
- [context_001.md](context_001.md) — FAPI TC 编码规则与分层职责：UL链路tc字段的两种语义（FAPI无符号 vs 有符号业务定义）及编码零点
- [context_003.md](context_003.md) — 远程构建服务器的连接信息和项目路径，所有 remote 服务器信息（IP、用户名、路径）均从此处获取，build-sync skill 依赖此配置
- [context_004.md](context_004.md) — nrMacTest 单元测试的运行环境、环境变量配置、执行命令，适用于远程构建服务器上的测试验证
- [context_005.md](context_005.md) — MAC TTI线程无堆分配约束与对象池模式：Grant Pool、DLINK Free List、TTI环形缓冲
- [context_006.md](context_006.md) — NrMacConfigExtender配置访问规范与Manager类设计模式：init()一次分配、继承NrMacChannelSchedulingNode
- [context_007.md](context_007.md) — TTI/SFN时间算术wrap处理与UE索引双轨制：ttiSfn禁止裸减法、crntiIndex与ueIndex禁止混用
- [context_008.md](context_008.md) — Binlog日志系统规范与TAG_TRACE共存规则：TTI安全日志、异常覆盖、格式规范
- [context_009.md](context_009.md) — ODI命令开发规范：OAM/TTI线程安全模型、one-shot模式、NrMacOdiMgr路由
- [context_010.md](context_010.md) — 代码删除完整性检查清单与简洁性审查规范
- [context_011.md](context_011.md) — 构建环境与同步安全规范：NMK构建体系、本地/远程分工、同步范围限制、make clean禁令、src/.config保护
- [context_012.md](context_012.md) — nrMacTest 作为 DU/MAC 集成测试沙箱的设计定位：真实 DU 内核配合可编排的 PHY/F1/UE 仿真闭环
- [context_013.md](context_013.md) — nrMacTest 中 UE attach 流程的完整消息序列（msg1→msg5→F1→reconfig→attached）与真实接入流程的主要差别

## user-feedbacks
- [user-feedback_002.md](user-feedback_002.md) — 通用编解码方法不应放在特定模块头文件中，避免迫使无关模块产生不必要的耦合
- [user-feedback_014.md](user-feedback_014.md) — nrmactest中的高频fan-in回调如handleRlcSduEvent和handleUlschEvent不应在每次进入时打印info级binlog，以免淹没真正的接入异常信号
