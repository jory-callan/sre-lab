{{- define "webhook2im.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "webhook2im.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "webhook2im.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "webhook2im.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webhook2im.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "webhook2im.fqdn" -}}
{{ .Release.Name }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end }}
