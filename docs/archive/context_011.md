---
name: 构建环境与同步安全规范
description: NMK构建体系、本地/远程分工、同步范围限制、make clean禁令、src/.config保护等构建环境全貌
type: context
created: 2026-03-25T00:00:00+08:00
updated: 2026-03-25T00:00:00+08:00
---

# 项目背景

## 场景
在进行代码同步、远程编译、修改构建配置或添加源文件时，需要了解构建体系的全貌和安全红线。

## 需求

### 本地与远程分工
- **本地机器**仅用于编辑和 IDE 索引。项目根目录的 `CMakeLists.txt` 纯粹为 IDE（如 CLion/VS Code）提供代码导航和自动补全支持，不参与实际编译。
- **远程构建服务器**负责编译和测试执行。连接信息见 `context_003.md`。
- 本地与远程之间通过 `build-sync` skill 的 rsync + ssh 完成同步。

### 构建体系
- 使用 NMK/Makefile 体系，不使用 CMake 构建。
- 各模块的编译单元在 `src/components/callp/<module>/Makefile` 中注册。
- `src/.config` 由构建系统自动生成，记录当前编译配置，禁止手动编辑。

### 语言与测试
- 源码语言标准：C99 和 C++11。
- 测试框架：UnitTest++，通过 `nrmactest-runner` skill 在远程服务器执行。

## 关键约束

### 同步范围限制
- **允许同步的范围**：`src/duapp/` 和 `src/components/callp/*/Makefile`。
- **禁止**同步整个 `src/` 目录树 — 因为其中包含不属于本项目管辖的模块代码，全量同步会覆盖他人工作。
- **禁止**使用 `rsync --delete` — 会删除远程服务器上本地不存在的文件，导致他人或 CI 的产物被误删。

### make clean 禁令
- **禁止**执行 `make clean`、`make clean_<mod>` 或任何 clean 变体 — clean 操作会清除所有编译产物（包括非本项目模块），重新编译耗时极长，且可能影响共享构建环境上其他开发者的构建缓存。

### src/.config 保护
- `src/.config` 是构建系统根据目标平台和功能开关自动生成的配置文件。手动修改会与构建系统的期望状态不一致，导致编译异常或运行时行为不可预测。
