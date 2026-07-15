# MySQL Cluster — KubeBlocks 管理

基于 KubeBlocks 的 ApeCloud MySQL 集群，1 主节点 + 2 从节点。

## 版本

| 组件 | 版本 |
|------|------|
| ApeCloud MySQL | 8.0.30 |
| KubeBlocks | 1.0.0 |

## 前置条件

需要先安装 KubeBlocks operator：

```bash
cd ../../operators/kubeblocks && bash install.sh
```

## 部署

```bash
bash install.sh
```

## 卸载

```bash
bash uninstall.sh
```

## 连接

```bash
# 集群内连接（主节点）
mysql -h mysql-kb-mysql-0.mysql-kb-mysql.mysql.svc.cluster.local -u root -p'root@czw123'

# 通过 Service 连接（读写分离）
mysql -h mysql-kb.mysql.svc.cluster.local -u root -p'root@czw123'
```

## 架构说明

使用 ApeCloud MySQL 引擎，基于 RAFT 共识协议实现高可用，3 节点部署（1 主 + 2 从）。
默认密码：`root@czw123`，与现有 Percona 方案保持一致。

## 参考

- [KubeBlocks Addons - apecloud-mysql](https://github.com/apecloud/kubeblocks-addons/tree/main/addons/apecloud-mysql)
- [KubeBlocks 官方文档](https://kubeblocks.io/docs/)
