{{- define "redis-operator.name" -}}{{ default "redis-operator" .Values.nameOverride | trunc 63 | trimSuffix "-" }}{{- end }}
{{- define "redis-operator.namespace" -}}{{ .Values.namespace }}{{- end }}
{{- define "redis-operator.labels" -}}
app.kubernetes.io/name: {{ include "redis-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
control-plane: {{ include "redis-operator.name" . }}
{{- end }}
