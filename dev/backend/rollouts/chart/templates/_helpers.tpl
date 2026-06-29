{{- define "istio-rollout.name" -}}
{{- .Values.app.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "istio-rollout.namespace" -}}
{{- .Values.app.namespace -}}
{{- end -}}

{{- define "istio-rollout.labels" -}}
app: {{ include "istio-rollout.name" . }}
env: {{ .Values.app.env }}
app.kubernetes.io/name: {{ include "istio-rollout.name" . }}
app.kubernetes.io/part-of: cloudops
app.kubernetes.io/managed-by: argocd
{{- end -}}

{{- define "istio-rollout.stableService" -}}
{{ include "istio-rollout.name" . }}-stable
{{- end -}}

{{- define "istio-rollout.canaryService" -}}
{{ include "istio-rollout.name" . }}-canary
{{- end -}}

{{- define "istio-rollout.analysisTemplateName" -}}
{{- if .Values.analysis.templateName -}}
{{- .Values.analysis.templateName -}}
{{- else -}}
{{ include "istio-rollout.name" . }}-prometheus
{{- end -}}
{{- end -}}
