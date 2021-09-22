{{/*
Common config for the otel-collector sapm exporter
*/}}
{{- define "splunk-otel-collector.otelSapmExporter" -}}
{{- if .Values.splunkObservability.tracesEnabled }}
{{- if eq (include "splunk-otel-collector.splunkO11yEnabled" .) "true" }}
sapm:
  endpoint: {{ include "splunk-otel-collector.ingestUrl" . }}/v2/trace
  access_token: ${SPLUNK_O11Y_ACCESS_TOKEN}
{{- end }}
{{- end }}
{{- end }}

{{/*
Default memory limiter configuration for OpenTelemetry Collector based on k8s resource limits.
*/}}
{{- define "splunk-otel-collector.memoryLimiter" -}}
# check_interval is the time between measurements of memory usage.
check_interval: 5s
# By default limit_mib is set to 80% of ".Values.agent.resources.limits.memory"
limit_mib: ${SPLUNK_MEMORY_LIMIT_MIB}
# Agent will set this value.
ballast_size_mib: ${SPLUNK_BALLAST_SIZE_MIB}
{{- end }}

{{- define "splunk-otel-collector.agent.hecConfig" -}}
exporters:
  {{- if eq (include "splunk-otel-collector.splunkPlatformEnabled" .) "true" }}
  splunk_hec/platform:
    splunk_app_name: {{ .Chart.Name }}
    splunk_app_version: {{ .Chart.Version }}
  {{- if eq (include "splunk-otel-collector.sendMetricsToSplunk" .) "true" }}
  splunk_hec/platformMetrics:
    splunk_app_name: {{ .Chart.Name }}
    splunk_app_version: {{ .Chart.Version }}
  {{- end }}
  {{- end }}
  {{- if eq (include "splunk-otel-collector.splunkO11yEnabled" .) "true" }}
  splunk_hec/o11y:
    splunk_app_name: {{ .Chart.Name }}
    splunk_app_version: {{ .Chart.Version }}
  {{- end }}
{{- end }}


{{/*
Common config for the otel-collector traces receivers
*/}}
{{- define "splunk-otel-collector.otelTraceReceivers" -}}
otlp:
  protocols:
    grpc:
      endpoint: 0.0.0.0:4317
    http:
      endpoint: 0.0.0.0:55681

{{- if .Values.splunkObservability.tracesEnabled }}
jaeger:
  protocols:
    thrift_http:
      endpoint: 0.0.0.0:14268
    grpc:
      endpoint: 0.0.0.0:14250
zipkin:
  endpoint: 0.0.0.0:9411
{{- end }}
{{- end }}

{{/*
Common config for resourcedetection processor
*/}}
{{- define "splunk-otel-collector.resourceDetectionProcessor" -}}
# Resource detection processor picks attributes from host environment.
# https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/resourcedetectionprocessor
resourcedetection:
  detectors:
    - system
    # Note: Kubernetes distro detectors need to come first so they set the proper cloud.platform
    # before it gets set later by the cloud provider detector.
    - env
    {{- if eq .Values.k8sDistro "gke" }}
    - gke
    {{- else if eq .Values.k8sDistro "eks" }}
    - eks
    {{- else if eq .Values.k8sDistro "aks" }}
    - aks
    {{- end }}
    {{- if eq .Values.cloudProvider "gcp" }}
    - gce
    {{- else if eq .Values.cloudProvider "aws" }}
    - ec2
    {{- else if eq .Values.cloudProvider "azure" }}
    - azure
    {{- end }}
  # Don't override existing resource attributes to maintain identification of data sources
  override: false
  timeout: 10s
{{- end }}
