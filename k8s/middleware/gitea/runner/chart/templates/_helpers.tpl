{{- define "runner.fullname" -}}
{{- .Values.name | default "gitea-runner" | trunc 63 | trimSuffix "-" }}
{{- end }}
