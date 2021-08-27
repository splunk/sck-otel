{{/*
Expand the name of the chart.
*/}}
{{- define "splunk-otel-collector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "splunk-otel-collector.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "splunk-otel-collector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Get Splunk ingest URL
*/}}
{{- define "splunk-otel-collector.ingestUrl" -}}
{{- $_ := required "splunkRealm or ingestUrl must be provided" (or .Values.splunkObservability.ingestUrl .Values.splunkObservability.realm) }}
{{- .Values.ingestUrl | default (printf "https://ingest.%s.signalfx.com" .Values.splunkObservability.realm) }}
{{- end -}}

{{/*
Get splunkAccessToken.
*/}}
{{- define "splunk-otel-collector.accessToken" -}}
{{- required "splunkObservability.splunkAccessToken value must be provided" .Values.splunkObservability.accessToken -}}
{{- end -}}

{{/*
Get splunkHecToken.
*/}}
{{- define "splunk-otel-collector.hecToken" -}}
{{- required "splunkPlatform.token value must be provided" .Values.splunkPlatform.token -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "splunk-otel-collector.labels" -}}
helm.sh/chart: {{ include "splunk-otel-collector.chart" . }}
{{ include "splunk-otel-collector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "splunk-otel-collector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "splunk-otel-collector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "splunk-otel-collector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "splunk-otel-collector.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "splunk-otel-collector.secret" -}}
{{- if .Values.secret.name -}}
{{- printf "%s" .Values.secret.name -}}
{{- else -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}