{{- define "cloudops-ui.name" -}}
{{- .Values.app.serviceName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cloudops-ui.labels" -}}
app: {{ include "cloudops-ui.name" . }}
env: {{ .Values.base.envName }}
app.kubernetes.io/name: {{ include "cloudops-ui.name" . }}
app.kubernetes.io/part-of: cloudops
app.kubernetes.io/managed-by: argocd
{{- end -}}
