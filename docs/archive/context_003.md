---
name: 构建服务器配置
description: 远程构建服务器的连接信息和项目路径，所有 remote 服务器信息（IP、用户名、路径）均从此处获取，build-sync skill 依赖此配置
type: context
created: 2026-03-24
updated: 2026-03-24
---

# 项目背景

## 场景

执行 build-sync skill 的 push/pull/build/test 操作时，需要知道远程构建服务器的连接方式和项目路径。

## 需求

通过 rsync + ssh 在本地与远程构建服务器之间同步代码并执行编译和测试。

## 关键约束

- Build Server IP: 192.168.0.223
- User: kunjie
- Remote project: /home/kunjie/ntn_bs_dev
- Local project: /home/kunjiey/ntn_bs_dev
