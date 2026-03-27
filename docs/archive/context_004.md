---
name: nrMacTest 运行方式
description: nrMacTest 单元测试的运行环境、环境变量配置、执行命令，适用于远程构建服务器上的测试验证
type: context
created: 2026-03-24T17:20:00+08:00
updated: 2026-03-24T19:40:00+08:00
---

# 项目背景

## 场景
在远程构建服务器上运行 nrMacTest 单元测试时，需要正确配置运行环境。适用于验证 MAC 调度、HARQ、UE 接入等功能的测试用例。

## 需求
nrMacTest 是基于 UnitTest++ 的 MAC 层单元测试可执行文件，由 NMK 构建系统编译，目标定义在 `src/components/callp/nrmactest/Makefile`（`PROGRAMS := nrMacTest`）。编译产物位于 `src/components/rootfs/bts/bin/nrMacTest`，运行时依赖 `src/components/rootfs/bts/lib/` 下的动态库。

## 关键约束
- 必须在远程构建服务器上执行，不能在本地运行
  - 若不知道远程服务器连接信息，可从 docs/archive/index.md 检索获取
- 运行前需进入项目的 `src/` 目录
- 必须将 `components/rootfs/bts/bin` 加入 PATH 环境变量
- 必须将 `components/rootfs/bts/lib` 加入 LD_LIBRARY_PATH 环境变量
- 运行命令示例：
  ```bash
  cd /home/kunjie/ntn_bs_dev/src
  export PATH=$PWD/components/rootfs/bts/bin:$PATH
  export LD_LIBRARY_PATH=$PWD/components/rootfs/bts/lib:$LD_LIBRARY_PATH
  nrMacTest
  ```
- 直接运行 `nrMacTest` 会执行所有已注册的测试套件（如 EnvTestDemo、PucchSchedulingMgr 等），无需额外参数
- 运行 `nrMacTest list` 可列出当前所有已注册的测试用例名称，格式为 `[SuiteName]TestName`
- 运行 `nrMacTest demo` 可执行名为 `demo` 的单个测试用例
- 运行 `nrMacTest suite EnvTestDemo` 可执行 `EnvTestDemo` suite 下的所有测试用例

## BINLOG 与日志配置

运行时可通过环境变量启用 BINLOG 和控制日志输出：

```bash
cd /home/kunjie/ntn_bs_dev/src
export PATH=$PWD/components/rootfs/bts/bin:$PATH
export LD_LIBRARY_PATH=$PWD/components/rootfs/bts/lib:$LD_LIBRARY_PATH
mkdir -p components/rootfs/oam/log
# 按需启用特定事件：
BINLOG_PATH=$PWD/components/rootfs/oam/log BINLOG_EVENTS='mac-ulsch|mac-dlsch' LOGGER_LEVEL=7 nrMacTest demo
# 或启用所有事件：
BINLOG_PATH=$PWD/components/rootfs/oam/log BINLOG_EVENTS=all LOGGER_LEVEL=7 nrMacTest demo
```

- `BINLOG_PATH`：指定 BINLOG 二进制日志输出目录
- `BINLOG_EVENTS`：按需设置要启用的事件（管道符分隔），或设为 `all` 启用全部；不设置时仅记录 GENERAL 事件
  - 可用键名：`mac-uci`、`mac-ulsch`、`mac-ulsch-harq`、`mac-dlsch`、`mac-dlsch-harq`、`mac-dlsch-retx`、`mac-ta`、`mac-dlla`、`mac-ulla`、`rlc-srb`、`rlc-drbam`、`rlc-drbum`、`mac-csi`、`mac-srs`、`mac-dtx`
- `LOGGER_LEVEL`：控制屏幕打印的日志级别（7 为 DEBUG 级别，输出最详细）
- BINLOG 产物位于 `components/rootfs/oam/log/ttilog.0.00`（二进制格式）
- 将 `ttilog.0.00` 拉回本地后，使用本地工具 `binlog_parser.py` 还原为可读日志文本
