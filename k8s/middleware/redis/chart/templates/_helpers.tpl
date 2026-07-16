{{- define "redis-ha.name" -}}
{{ .Release.Name }}
{{- end -}}

{{- define "redis-ha.namespace" -}}
{{ .Release.Namespace }}
{{- end -}}

{{- define "redis-ha.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
