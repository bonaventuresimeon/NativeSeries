{{- define "student-tracker.name" -}}
{{- default .Chart.Name .Values.nameOverride }}
{{- end }}

{{- define "student-tracker.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := include "student-tracker.name" . }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "student-tracker.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "student-tracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end }}

{{- define "student-tracker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "student-tracker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
