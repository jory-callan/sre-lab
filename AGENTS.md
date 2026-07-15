通用规则:
- 所有文件需初始化 Git，每次修改后按 type(scope): subject 格式提交
- 沟通风格要给出专业判断，不要一味迎合，依据独立分析判断，采取肯定或否定
- 永远先确认完整计划，等待用户明确 "start" 信号后再行动
- 用户喜欢简洁清晰的文档
- 每次功能完成后，需要校验确保无报错，整理相关文档需要更新就更新，不需要就直接结束

docker规则：
- 所有组件都必须走 net-shared 这个存在的网络，目的是为了所有组件的网络互通

k8s规则:
- 资源限制去掉 cpu 的限制只做内存限制
- 用户已经配置好了 kubectl 和 helm 可以直接使用
- 避免使用 *.local 域名，统一使用 *.czw-sre.internal 域名，此域名不是互联网域名，是内网域名，已经在路由器里解析过，可以直接用
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
- 资源应用命名统一采用类型-名称。例如 mysql-xxx redis-xxx pg-xxx app-xxx
- operator 管理的组件（如 Alertmanager CRD 由 Prometheus Operator 调谐）helm upgrade 时不要加 --wait，operator 异步调谐会导致 --wait 卡住超时，配置写入 Secret 即算成功
- helm-chart-*.tgz → 不忽略，进 git
- 官方 chart 存 tgz，自写 chart 存源码
- tgz 命名 helm-chart-<name>-<version>.tgz


helm 编写规则：
- 应用优先生成 Helm Chart，以下是建议：你需要充分考虑到单组件和多组件的差异：
- "组件" = 一个应用内有多个不同角色的进程，如 dolphinscheduler 的 master、worker、api
- _helpers.tpl 只保留极简的必要函数：例如单组件：name、labels、selectorLabels，多组件：（增加 componentLabels、componentSelector）。禁止嵌套调用、禁止额外辅助函数，显示声明是第一优先
- 必须包含 NOTES.txt，内容为部署后用户需执行的后续操作指引
- templates/ 下按 Kind-组件 拆分文件，禁止在一个文件中用 --- 分隔多个资源
- 默认开启必备特性例如软反亲和性（podAntiAffinity），用 values 中的 affinity.enabled 控制开关，默认 true
- 服务端口固定写在 values 中，默认 clusterIP 类型；如需 NodePort，额外生成 templates/service-nodeport.yaml，通过 values 中的 service.nodePort.enabled 控制，且该 Service 通过标签选择器关联同一 Pod
- 如果 Pod 暴露了 metrics 端口，增加 serviceMonitor 配置，通过 values 中的 serviceMonitor.enabled 控制，默认 false
- 如果应用需要对外暴露 HTTP/S 路由，增加 ingress 配置，通过 values 中的 ingress.enabled 控制，默认 false
- values.yaml 结构扁平化，最多两层嵌套，所有开关集中在根级或 service 层级下


生成 Helm Chart，优先参考以下规则：
一、组件概念的定义
- "组件" = 一个应用内有多个不同角色的进程，如 dolphinscheduler 的 master、worker、api
- 每个组件有自己的部署方案，组件间通过标签 app.kubernetes.io/component: <组件名> 区分
- 如果应用只有一个进程/组件/镜像（如 nginx、redis），不属于多组件
二、_helpers.tpl 函数数量按场景决定
- 单组件应用：只定义 4 个函数（name、labels、selectorLabels、fqdn）
- 多组件应用：定义 6 个函数（增加 componentLabels、componentSelector）
- componentLabels/componentSelector 的唯一用途：区分不同组件的标签选择器
- 如果只有 1 个组件，绝对不要定义 componentLabels 和 componentSelector
- 删除 fullname，永远不用
三、模板组织方式
- templates/ 下按 Kind-组件(按需) 拆文件（deployment.yaml、service.yaml...）
- service-headless.yaml servoce-nodeport.yaml
四、Kubernetes 生产必备特性（所有特性配 values 开关）
- 软反亲和性（podAntiAffinity）：默认开启，用于 Pod 分散调度
- 资源请求与限制（resources）：完全自定义
- 健康检查（readinessProbe + livenessProbe）：完全自定义
- 优雅终止（terminationGracePeriodSeconds）：默认 10 秒
- 滚动更新策略（rollingUpdate）：maxSurge 25%，maxUnavailable 25%
- 安全上下文（securityContext）：默认 runAsNonRoot: true
- 服务：默认 ClusterIP，NodePort 可选（通过 service.nodePort.enabled 控制）
- ConfigMap / Secret：支持环境变量或文件挂载
- PVC 持久化：按需开启
- ServiceAccount + RBAC：按需开启
- PodDisruptionBudget：按需开启
- HPA（CPU/内存自动伸缩）：按需开启
- ServiceMonitor / PodMonitor：如果应用暴露 metrics 则支持，默认关闭
- Ingress：按需开启
- NetworkPolicy：按需开启
五、values.yaml 规则
- image 的镜像源，tag，拉取方式等统一在顶层 image: 配置
- 单组件：扁平结构，所有配置在根级
- 多组件：顶层按照组件名。然后就是各种特性平铺即可。
- 优先使用 .Release.* 内置字段，减少 values 定义
六、NOTES.txt
- 必须包含
- 展示访问方式（Ingress/NodePort/ClusterIP）
- 展示常用 kubectl 命令
- 展示下一步
七、禁止事项
- 禁止在一个文件中用 --- 分隔多个资源
- 禁止 fullname
- 禁止无意义的嵌套函数
- 禁止照搬开源 Chart 的复杂 _helpers
八 conf目录
- 按需启用 conf 目录
以上作为参考，实际情况实际处理。