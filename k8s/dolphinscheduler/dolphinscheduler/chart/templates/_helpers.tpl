{{- define "ds.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ds.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{- define "ds.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "ds.componentLabels" -}}
{{- $root := .context -}}
app.kubernetes.io/name: {{ $root.Chart.Name }}-{{ .component }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/version: {{ $root.Chart.AppVersion | quote }}
helm.sh/chart: {{ $root.Chart.Name }}-{{ $root.Chart.Version }}
{{- end }}

{{- define "ds.componentSelector" -}}
{{- $root := .context -}}
app.kubernetes.io/name: {{ $root.Chart.Name }}-{{ .component }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
{{- end }}

{{- define "ds.fqdn" -}}
{{- .Release.Name }}.{{ .Release.Namespace }}.svc
{{- end }}
