{{- define "cloudops-go.name" -}}
{{- .Values.app.serviceName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cloudops-go.labels" -}}
app: {{ include "cloudops-go.name" . }}
env: {{ .Values.base.envName }}
app.kubernetes.io/name: {{ include "cloudops-go.name" . }}
app.kubernetes.io/part-of: cloudops
app.kubernetes.io/managed-by: argocd
{{- end -}}
