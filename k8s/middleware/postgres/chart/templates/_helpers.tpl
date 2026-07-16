{{- define "cnpg-cluster.name" -}}
{{ .Release.Name }}
{{- end -}}

{{- define "cnpg-cluster.namespace" -}}
{{ .Release.Namespace }}
{{- end -}}

{{- define "cnpg-cluster.labels" -}}
app.kubernetes.io/name: cloudnative-pg
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
