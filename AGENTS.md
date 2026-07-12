通用规则:
- 所有文件需初始化 Git，每次修改后按 type(scope): subject 格式提交
- 沟通风格要给出专业判断，不要一味迎合，依据独立分析判断，采取肯定或否定
- 永远先确认完整计划，等待用户明确 "start" 信号后再行动
- 用户喜欢简洁清晰的文档
- 每次功能完成后，需要校验确保无报错，整理相关文档需要更新就更新，不需要就直接结束

docker规则：
- 所有组件都必须走 net-shared 这个存在的网络，目的是为了所有组件的网络互通

k8s规则:
- 用户已经配置好了 kubectl 和 helm 可以直接使用
- 避免使用 *.local 域名，统一使用 *.czw-sre.internal 域名，此域名不是互联网域名，是内网域名，已经在路由器里解析过，可以直接用
- 每个组件最少提供 install.sh 和 uninstall.sh ，其余脚本看情况是否需要新增
- README 中保留原始远程资源地址说明，只讲怎么用，不列出文件树
- 多版本应用作为独立应用目录处理，应用名称使用小写字母，无空格，用数字表示版本（如 mysql5.7）
- 不要搞复杂统一入口，每个方案独立完整，简单直接
- 不同部署方式（manifests/helm/kustomize）通过文件夹区分
- 对于k8s内部应用的连接地址采用内部域名连接方式，不要走外部域名,例如 grafana 配置的连接源是k8s的就走内部 dns ，不要走 ingress 域名。
- 本地托管如下：helm 仓库： http://192.168.5.103:8081/repository/helm-hosted/  无密码
- 本地有私有化仓库：nexus3
Nexus 管理界面: http://192.168.5.103:8081  admin admin123
端口号分别代表
5000 = group(含5001),
5001 = docker-hosted,
5002 = docker.io,
5003 = registry.k8s.io,
5004 = quay.io,
5005 = ghcr.io,
5006 = gcr.io,
- k8s 资源限制，request 不要设置通过注释保留，只设置 limit 。
- 如果需要修改资源，不要尝试直接 patch/apply ，而是执行 install.sh 必须是幂等的。
- 需要debug等特殊情况允许直接 patch/apply 等直接操作。最终验证ok依旧需要修复相关文件和安装脚本