明白了！你要的是一个**通用的 Helm Chart 生成 Skill**，不是针对某个具体应用的模板，而是抽象规则 + 通用参考，能适配任何应用场景。

---

## Skill: helm-chart-generator

### 描述
根据用户提供的应用信息，自动生成符合 Kubernetes 生产最佳实践的 Helm Chart，遵循极简原则，不照搬开源复杂模板。

---

### 触发条件
用户提及以下关键词时激活：
- "生成 Helm Chart"
- "帮我写 Chart"
- "Helm 打包"
- 或在对话中明确要求生成 Kubernetes 部署模板

---

### 核心原则

1. **极简优先**：_helpers.tpl 不超过 5 个函数，拒绝 fullname，拒绝嵌套调用
2. **生产就绪**：默认包含亲和性、资源限制、健康检查、安全上下文、滚动更新
3. **按需扩展**：所有高级特性（Ingress、ServiceMonitor、HPA、PDB 等）通过 values 开关控制，默认关闭
4. **用户聚焦**：用户只需关心镜像、资源、副本数，端口等细节内置固定值
5. **优先内置**：尽量使用 `.Release` 和 `.Chart` 内置字段，减少 values 冗余
6. **独立文件**：每个 Kind 独立文件，禁止 `---` 分隔多个资源

---

### 工作流程

#### 第一步：收集应用信息

向用户确认以下信息（缺失则使用默认值）：

| 信息项 | 是否必须 | 默认值 |
|---|---|---|
| 应用名称 | ✅ 必须 | - |
| 镜像仓库地址 | ✅ 必须 | - |
| 镜像标签 | ❌ 可选 | Chart.AppVersion |
| 镜像拉取策略 | ❌ 可选 | IfNotPresent |
| 镜像拉取密钥 | ❌ 可选 | [] |
| 副本数 | ❌ 可选 | 2 |
| 容器端口 | ❌ 可选 | 80 |
| 是否多组件 | ❌ 可选 | 否（单组件） |
| 组件列表及角色 | 多组件时需确认 | - |
| 是否需要 StatefulSet | ❌ 可选 | 否 |
| 是否需要持久化 | ❌ 可选 | 否 |
| 是否需要 Ingress | ❌ 可选 | 否 |
| 是否需要 ServiceMonitor | ❌ 可选 | 否 |
| 是否需要 HPA | ❌ 可选 | 否 |

#### 第二步：判断 Chart 类型

```
IF 多组件（用户明确或 values 包含多个组件顶层 key）:
    模式 = 多组件
ELSE:
    模式 = 单组件
```

#### 第三步：生成 _helpers.tpl

**单组件模式（4 个函数）：**
- `name`: 直接使用 `.Release.Name`
- `labels`: 标准 Kubernetes 标签 + selectorLabels
- `selectorLabels`: app.kubernetes.io/name + instance
- `fqdn`: 优先 values.ingress.host，否则自动生成

**多组件模式（5 个函数）：**
- 上述 4 个 + `componentLabels`: labels + component 标签

**禁止：**
- fullname 函数
- 任何嵌套调用
- 复杂的 if/else 逻辑
- 额外的辅助函数

#### 第四步：生成模板文件

**单组件模式目录结构：**
```
templates/
├── _helpers.tpl
├── NOTES.txt
├── deployment.yaml
├── service.yaml
├── service-nodeport.yaml   # 可选
├── service-headless.yaml   # 可选（仅 StatefulSet 时）
├── configmap.yaml          # 可选
├── secret.yaml             # 可选
├── pvc.yaml                # 可选
├── ingress.yaml            # 可选
├── hpa.yaml                # 可选
├── pdb.yaml                # 可选
├── serviceaccount.yaml     # 可选
├── servicemonitor.yaml     # 可选
└── networkpolicy.yaml      # 可选
```

**多组件模式目录结构：**
```
templates/
├── _helpers.tpl
├── NOTES.txt
├── deployment-{component}.yaml   # 每个组件一个
├── service-{component}.yaml      # 每个组件一个
├── statefulset-{component}.yaml  # 有状态组件用
├── service-nodeport.yaml         # 可选，包含所有组件
├── service-headless.yaml         # 可选，仅包含 StatefulSet 组件
└── ...（其他可选文件同上）
```

#### 第五步：生成 values.yaml

**单组件模式 values 结构：**

```yaml
# 用户必配
image:
  repository: ""            # 必须填写
  tag: ""                   # 空则用 Chart.AppVersion
  pullPolicy: IfNotPresent
  pullSecrets: []

# 用户可调
replicaCount: 2

resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"

probes:
  enabled: true
  livenessProbe:
    path: /health
    port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
  readinessProbe:
    path: /ready
    port: 8080
    initialDelaySeconds: 5
    periodSeconds: 5

# 以下为可选特性，默认关闭
nodePort:
  enabled: false

headless:
  enabled: false            # 仅 StatefulSet 时使用

ingress:
  enabled: false
  host: ""
  annotations: {}
  tls: []

serviceMonitor:
  enabled: false
  path: /metrics
  interval: 30s

persistence:
  enabled: false
  storageClass: ""
  size: 10Gi

hpa:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

pdb:
  enabled: false
  minAvailable: 1

serviceAccount:
  create: false

affinity:
  enabled: true             # 软反亲和，默认开启

terminationGracePeriodSeconds: 10
```

**多组件模式 values 结构：**

```yaml
# 全局配置
image:
  pullPolicy: IfNotPresent
  pullSecrets: []

affinity:
  enabled: true

terminationGracePeriodSeconds: 10

# 可选特性（全局）
nodePort:
  enabled: false

ingress:
  enabled: false

serviceMonitor:
  enabled: false

# 每个组件独立配置
{component}:
  replicaCount: 1
  image:
    repository: ""           # 每个组件独立镜像
    tag: ""
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
  probes:
    enabled: true
    livenessProbe:
      path: /health
      port: 8080
    readinessProbe:
      path: /ready
      port: 8080
  service:
    port: 8080              # 组件端口
  persistence:               # 仅 StatefulSet 组件需要
    enabled: false
    size: 10Gi
```

#### 第六步：生成 NOTES.txt

根据启用的特性动态生成：

```text
{{- if .Values.ingress.enabled }}
访问地址：http{{ if .Values.ingress.tls }}s{{ end }}://{{ (index .Values.ingress.hosts 0).host }}
{{- else if .Values.nodePort.enabled }}
NodePort 访问：<任意节点IP>:{{ .Values.nodePort.port }}
{{- else }}
内部访问：{{ include "name" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.service.port | default 80 }}
{{- end }}

查看 Pod 状态：
  kubectl get pods -n {{ .Release.Namespace }} -l {{ include "selectorLabels" . }}

查看日志：
  kubectl logs -f -n {{ .Release.Namespace }} -l {{ include "selectorLabels" . }}

{{- if .Values.hpa.enabled }}
HPA 状态：
  kubectl get hpa -n {{ .Release.Namespace }} {{ include "name" . }}
{{- end }}
```

---

### 模板文件生成规则

#### deployment.yaml 通用规则

| 字段 | 来源 | 说明 |
|---|---|---|
| `metadata.name` | `{{ include "name" . }}` | 单组件；多组件加 `-{component}` |
| `replicas` | `values.replicaCount` | 单组件；多组件从组件配置读取 |
| `image` | `values.image.repository:tag` | tag 空则用 `Chart.AppVersion` |
| `ports.containerPort` | `values.probes.port` 或 `values.service.port` 或默认 80 | 优先使用 probes 端口 |
| `livenessProbe` | `values.probes.livenessProbe` | 支持 httpGet 和 exec 两种方式 |
| `readinessProbe` | `values.probes.readinessProbe` | 同上 |
| `resources` | `values.resources` | 完全自定义 |
| `affinity` | `values.affinity.enabled` | 默认开启软反亲和 |
| `securityContext` | 内置 | runAsNonRoot: true，drop ALL |
| `terminationGracePeriodSeconds` | `values.terminationGracePeriodSeconds` | 默认 10 |

#### service.yaml 通用规则

| 字段 | 规则 |
|---|---|
| `type` | 固定 ClusterIP |
| `port` | 单组件用 `values.service.port` 或默认 80；多组件从组件配置读取 |
| `targetPort` | 同 port |
| `selector` | 单组件用 selectorLabels；多组件用 componentSelector |

#### service-nodeport.yaml 生成条件

```
IF values.nodePort.enabled == true:
    生成 service-nodeport.yaml
    单组件：生成一个 NodePort Service
    多组件：为每个组件生成一个 NodePort Service（用硬编码列表）
```

#### service-headless.yaml 生成条件

```
IF values.headless.enabled == true AND 存在 StatefulSet 组件:
    生成 service-headless.yaml
    仅为 StatefulSet 组件生成（用硬编码列表）
```

#### statefulset.yaml 生成条件

```
IF 组件配置中包含 persistence 字段:
    使用 StatefulSet 替代 Deployment
    自动生成 volumeClaimTemplates
```

---

### 生产特性检查清单

生成 Chart 时，必须包含以下生产特性（默认值合理，用户可通过 values 调整）：

- [x] 软反亲和性（podAntiAffinity）
- [x] 资源请求与限制（CPU/内存）
- [x] 存活探针 + 就绪探针（支持 httpGet 和 exec）
- [x] 优雅终止（terminationGracePeriodSeconds）
- [x] 滚动更新策略（maxSurge / maxUnavailable）
- [x] 安全上下文（runAsNonRoot: true）
- [x] ClusterIP Service（默认）
- [x] NodePort Service（可选）
- [x] Headless Service（可选，StatefulSet）
- [x] ConfigMap / Secret 支持
- [x] PVC 持久化（可选）
- [x] ServiceAccount（可选）
- [x] PodDisruptionBudget（可选）
- [x] HPA（可选）
- [x] ServiceMonitor（可选）
- [x] Ingress（可选）
- [x] NetworkPolicy（可选）

---

### 禁止事项

1. ❌ 禁止生成 `fullname` 函数
2. ❌ 禁止在 `_helpers.tpl` 中编写复杂嵌套逻辑
3. ❌ 禁止在一个文件中用 `---` 分隔多个资源
4. ❌ 禁止照搬开源 Chart 的复杂模板
5. ❌ 禁止使用 range 循环遍历 values 生成组件（多组件用硬编码列表逐个生成）
6. ❌ 禁止让用户关注端口号（内置默认值）
7. ❌ 禁止依赖外部 Chart 或子 Chart

---

### 输出格式

1. 先输出 `Chart.yaml`
2. 再输出 `values.yaml`
3. 然后按目录结构输出所有 `templates/*.yaml`
4. 最后简要说明如何使用

每个文件用代码块包裹，标注文件路径：

```yaml
# Chart.yaml
...
```

```yaml
# values.yaml
...
```

```yaml
# templates/_helpers.tpl
...
```

---

### 示例交互

**用户输入：**
> 生成一个 nginx 的 Helm Chart

**Skill 输出：**
1. 确认信息（镜像、端口、副本数）
2. 生成 Chart.yaml、values.yaml
3. 生成 _helpers.tpl、deployment.yaml、service.yaml
4. 生成 NOTES.txt
5. 简要说明

---

**用户输入：**
> 生成 dolphinscheduler 的 Helm Chart，组件有 master、worker、api、alert，zookeeper 和 pgsql 需要 StatefulSet 持久化

**Skill 输出：**
1. 识别为多组件模式
2. 生成 5 个函数的 _helpers.tpl
3. 为每个组件生成 deployment/service 独立文件
4. zookeeper 和 pgsql 用 StatefulSet
5. 生成可选文件（service-nodeport、service-headless、ingress 等，默认关闭）
6. 生成 NOTES.txt
7. 简要说明

---

1. **组件列表硬编码**：多组件的 NodePort/Headless 文件中，组件列表用硬编码数组，不用 range 遍历 values
2. **端口默认值**：单组件默认 80，多组件每个组件可配置不同端口
3. **探针类型**：支持 `httpGet` 和 `exec` 两种方式，根据组件类型自动选择
4. **标签一致性**：所有资源的标签必须一致，确保 Service 能正确选择 Pod
5. **Chart.yaml 版本**：始终使用 apiVersion: v2（Helm 3+）

---
其他规则补充
Kubernetes 最佳实践最低标签（Labels）
我的推荐：5 个标签是底线，6 个是完整(多组件)
标签	是否必须	说明
app.kubernetes.io/name	✅ 必须	Chart 名称
app.kubernetes.io/instance	✅ 必须	Release 名称，区分不同部署
app.kubernetes.io/version	✅ 必须	Chart 版本，方便版本追溯
app.kubernetes.io/managed-by	✅ 必须	固定 Helm，标识管理工具
helm.sh/chart	✅ 必须	Chart 名称+版本，Helm 标准标签
app.kubernetes.io/component	⚠️ 多组件必须	组件角色（master/worker/api）### 注意事项

_helpers.tpl规则：
单组件时：只用前 3 个 + fqdn , 简单够用即可。
多组件时：新增 componentSelectorLabels +  componentLabels。
```template
# _helpers.tpl（最多 5 个函数）
{{- define "mychart.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "mychart.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- include "mychart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "mychart.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "mychart.componentLabels" -}}
{{- include "mychart.labels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "mychart.componentSelectorLabels" -}}
{{- include "mychart.labels" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "mychart.fqdn" -}}
{{- .Values.ingress.host | default (printf "%s.%s" (include "mychart.name" .) .Values.ingress.domainSuffix) }}
{{- end }}
```