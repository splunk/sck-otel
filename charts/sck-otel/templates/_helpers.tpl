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
{{- $_ := required "splunkObservability.realm or splunkObservability.ingestUrl must be provided" (or .Values.splunkObservability.ingestUrl .Values.splunkObservability.realm) }}
{{- .Values.splunkObservability.ingestUrl | default (printf "https://ingest.%s.signalfx.com" .Values.splunkObservability.realm) }}
{{- end -}}


{{/*
Get Splunk API URL.
*/}}
{{- define "splunk-otel-collector.apiUrl" -}}
{{- $_ := required "splunkObservability.realm or splunkObservability.apiUrl must be provided" (or .Values.splunkObservability.apiUrl .Values.splunkObservability.realm) }}
{{- .Values.apiUrl | default (printf "https://api.%s.signalfx.com" .Values.splunkObservability.realm) }}
{{- end -}}

{{/*
Get splunkAccessToken.
*/}}
{{- define "splunk-otel-collector.o11yAccessToken" -}}
{{- required "splunkObservability.splunkAccessToken value must be provided" .Values.splunkObservability.accessToken -}}
{{- end -}}

{{/*
Get splunkHecToken.
*/}}
{{- define "splunk-otel-collector.platformHecToken" -}}
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

{{/*
Boolean whether to build pipeline for logs
*/}}
{{- define "splunk-otel-collector.collectLog" -}}
{{- $endpoint := default "" .Values.splunkPlatform.endpoint }}
{{- $token := default "" .Values.splunkObservability.accessToken }}
{{- $logToSplunk := and .Values.splunkPlatform.logsEnabled (not (eq $endpoint "")) }}
{{- $logToO11y := and .Values.splunkObservability.logsEnabled (not (eq $token "")) }}
{{- or $logToSplunk $logToO11y }}
{{- end -}}

{{/*
Boolean whether to build pipeline for metrics
*/}}
{{- define "splunk-otel-collector.collectMetric" -}}
{{- $endpoint := default "" .Values.splunkPlatform.endpoint }}
{{- $metricsIndex := default "" .Values.splunkPlatform.metrics_index }}
{{- $token := default "" .Values.splunkObservability.accessToken }}
{{- $metricToSplunk := and .Values.splunkPlatform.metricsEnabled (not (eq $endpoint "")) (not (eq $metricsIndex "")) }}
{{- $metricToO11y := and .Values.splunkObservability.metricsEnabled (not (eq $token "")) }}
{{- or $metricToSplunk $metricToO11y }}
{{- end -}}

{{/*
Boolean whether to build pipeline for traces
*/}}
{{- define "splunk-otel-collector.collectTrace" -}}
{{- $token := default "" .Values.splunkObservability.accessToken }}
{{- $traceToO11y := and .Values.splunkObservability.tracesEnabled (not (eq $token "")) }}
{{- $traceToO11y }}
{{- end -}}

{{/*
Boolean whether to build pipeline for Splunk Platform endpoint
*/}}
{{- define "splunk-otel-collector.splunkPlatformEnabled" -}}
{{- $dataToSplunk := or .Values.splunkPlatform.logsEnabled .Values.splunkPlatform.metricsEnabled }}
{{- $token := default "" .Values.splunkPlatform.token }}
{{- and $dataToSplunk (not (eq $token "")) }}
{{- end -}}

{{/*
Boolean whether to build pipeline for Splunk O11y endpoint
*/}}
{{- define "splunk-otel-collector.splunkO11yEnabled" -}}
{{- $dataToO11y := or .Values.splunkObservability.logsEnabled .Values.splunkObservability.metricsEnabled .Values.splunkObservability.tracesEnabled }}
{{- $token := default "" .Values.splunkObservability.accessToken }}
{{- and $dataToO11y (not (eq $token "")) }}
{{- end -}}

{{/*
Boolean whether to send logs to Splunk Platform
*/}}
{{- define "splunk-otel-collector.sendLogsToSplunk" -}}
{{- $endpoint := default "" .Values.splunkPlatform.endpoint }}
{{- and .Values.splunkPlatform.logsEnabled (not (eq $endpoint "")) }}
{{- end -}}

{{/*
Boolean whether to send metrics to Splunk Platform
*/}}
{{- define "splunk-otel-collector.sendMetricsToSplunk" -}}
{{- $metricsIndex := default "" .Values.splunkPlatform.metrics_index }}
{{- and .Values.splunkPlatform.metricsEnabled .Values.splunkPlatform.endpoint (not (eq $metricsIndex "")) }}
{{- end -}}

{{/*
Boolean whether to send logs to O11y Platform
*/}}
{{- define "splunk-otel-collector.sendLogsToO11y" -}}
{{- $token := default "" .Values.splunkObservability.accessToken }}
{{- and .Values.splunkObservability.logsEnabled (not (eq $token "")) }}
{{- end -}}

{{/*
Boolean whether to send metrics to O11y Platform
*/}}
{{- define "splunk-otel-collector.sendMetricsToO11y" -}}
{{- $token := default "" .Values.splunkObservability.accessToken }}
{{- and .Values.splunkObservability.metricsEnabled (not (eq $token "")) }}
{{- end -}}

{{/*
Boolean whether to send traces to O11y Platform
*/}}
{{- define "splunk-otel-collector.sendTracesToO11y" -}}
{{- $token := default "" .Values.splunkObservability.accessToken }}
{{- and .Values.splunkObservability.tracesEnabled (not (eq $token "")) }}
{{- end -}}


{{/*
Convert memory value from resources.limit to numeric value in MiB to be used by otel memory_limiter processor.
*/}}
{{- define "splunk-otel-collector.convertMemToMib" -}}
{{- $mem := lower . -}}
{{- if hasSuffix "e" $mem -}}
{{- trimSuffix "e" $mem | atoi | mul 1000 | mul 1000 | mul 1000 | mul 1000 -}}
{{- else if hasSuffix "ei" $mem -}}
{{- trimSuffix "ei" $mem | atoi | mul 1024 | mul 1024 | mul 1024 | mul 1024 -}}
{{- else if hasSuffix "p" $mem -}}
{{- trimSuffix "p" $mem | atoi | mul 1000 | mul 1000 | mul 1000 -}}
{{- else if hasSuffix "pi" $mem -}}
{{- trimSuffix "pi" $mem | atoi | mul 1024 | mul 1024 | mul 1024 -}}
{{- else if hasSuffix "t" $mem -}}
{{- trimSuffix "t" $mem | atoi | mul 1000 | mul 1000 -}}
{{- else if hasSuffix "ti" $mem -}}
{{- trimSuffix "ti" $mem | atoi | mul 1024 | mul 1024 -}}
{{- else if hasSuffix "g" $mem -}}
{{- trimSuffix "g" $mem | atoi | mul 1000 -}}
{{- else if hasSuffix "gi" $mem -}}
{{- trimSuffix "gi" $mem | atoi | mul 1024 -}}
{{- else if hasSuffix "m" $mem -}}
{{- div (trimSuffix "m" $mem | atoi | mul 1000) 1024 -}}
{{- else if hasSuffix "mi" $mem -}}
{{- trimSuffix "mi" $mem | atoi -}}
{{- else if hasSuffix "k" $mem -}}
{{- div (trimSuffix "k" $mem | atoi) 1000 -}}
{{- else if hasSuffix "ki" $mem -}}
{{- div (trimSuffix "ki" $mem | atoi) 1024 -}}
{{- else -}}
{{- div (div ($mem | atoi) 1024) 1024 -}}
{{- end -}}
{{- end -}}
