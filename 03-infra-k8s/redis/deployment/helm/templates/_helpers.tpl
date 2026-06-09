{{/*
SPDX-License-Identifier: Apache-2.0

通用有状态应用 Helm Chart — Helper 模板
*/}}

{{/*
名称解析：优先使用 global.nameOverride，其次 release name
*/}}
{{- define "app.name" -}}
{{- default .Release.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
命名空间：优先使用 global.namespaceOverride，其次 release namespace
*/}}
{{- define "app.namespace" -}}
{{- default .Release.Namespace .Values.global.namespaceOverride }}
{{- end -}}

{{/*
通用标签
*/}}
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
选择器标签（用于 Service / 部署匹配）
*/}}
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
全名（用于资源命名）
*/}}
{{- define "app.fullname" -}}
{{ include "app.name" . }}
{{- end -}}