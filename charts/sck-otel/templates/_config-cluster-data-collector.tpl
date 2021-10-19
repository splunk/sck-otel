{{/*
Config for the otel-collector k8s cluster receiver deployment.
The values can be overridden in .Values.clusterDataCollectorConfig.config
*/}}
{{- define "splunk-otel-collector.clusterDataCollectorConfig" -}}
extensions:
  health_check:

receivers:
  # Prometheus receiver scraping metrics from the pod itself, both otel and fluentd
  prometheus/k8s_cluster_receiver:
    config:
      scrape_configs:
      - job_name: 'otel-k8s-cluster-receiver'
        scrape_interval: 10s
        static_configs:
        - targets: ["${K8S_POD_IP}:8889"]
  k8s_cluster:
    auth_type: serviceAccount
    {{- if eq (include "splunk-otel-collector.splunkO11yEnabled" .) "true" }}
    metadata_exporters: [signalfx]
    {{- end }}

processors:
  memory_limiter:
    {{- include "splunk-otel-collector.memoryLimiter" . | nindent 4 }}
  batch:

  {{- include "splunk-otel-collector.resourceDetectionProcessor" . | nindent 2 }}

  # Resource attributes specific to the collector itself.
  resource/add_collector_k8s:
    attributes:
      - action: insert
        key: k8s.node.name
        value: "${K8S_NODE_NAME}"
      - action: insert
        key: k8s.pod.name
        value: "${K8S_POD_NAME}"
      - action: insert
        key: k8s.pod.uid
        value: "${K8S_POD_UID}"
      - action: insert
        key: k8s.namespace.name
        value: "${K8S_NAMESPACE}"

  resource:
    attributes:
      # TODO: Remove once available in mapping service.
      - action: insert
        key: metric_source
        value: kubernetes
      # XXX: Added so that Smart Agent metrics and OTel metrics don't map to the same MTS identity
      # (same metric and dimension names and values) after mappings are applied. This would be
      # the case if somebody uses the same cluster name from Smart Agent and OTel in the same org.
      - action: insert
        key: receiver
        value: k8scluster
      {{- if .Values.clusterName }}
      - action: upsert
        key: k8s.cluster.name
        value: {{ .Values.clusterName }}
      {{- end }}
      {{- range $k, $v := .Values.customMetadata }}
      - action: insert
        key: {{ $k }}
        value: {{ $v }}
      {{- end }}

exporters:
  {{- if eq (include "splunk-otel-collector.splunkO11yEnabled" .) "true" }}
  signalfx:
    {{- if .Values.gateway.enabled }}
    ingest_url: http://{{ include "splunk-otel-collector.fullname" . }}:9943
    api_url: http://{{ include "splunk-otel-collector.fullname" . }}:6060
    {{- else }}
    ingest_url: {{ include "splunk-otel-collector.ingestUrl" . }}
    api_url: {{ include "splunk-otel-collector.apiUrl" . }}
    {{- end }}
    access_token: ${SPLUNK_O11Y_ACCESS_TOKEN}
    timeout: 10s
  {{- end }}
  {{- if eq (include "splunk-otel-collector.sendMetricsToSplunk" .) "true" }}
  splunk_hec/platformMetrics:
    endpoint: {{ .Values.splunkPlatform.endpoint | quote }}
    token: "${SPLUNK_PLATFORM_HEC_TOKEN}"
    index: {{ .Values.splunkPlatform.metrics_index | quote }}
    source: {{ .Values.splunkPlatform.source | quote }}
    sourcetype: {{ .Values.splunkPlatform.sourcetype | quote }}
    max_connections: {{ .Values.splunkPlatform.max_connections }}
    disable_compression: {{ .Values.splunkPlatform.disable_compression }}
    timeout: {{ .Values.splunkPlatform.timeout }}
    tls:
      insecure: {{ .Values.splunkPlatform.insecure }}
      insecure_skip_verify: {{ .Values.splunkPlatform.insecure_skip_verify }}
      {{- if .Values.splunkPlatform.clientCert }}
      cert_file: /otel/etc/hec_client_cert
      {{- end }}
      {{- if .Values.splunkPlatform.clientKey  }}
      key_file: /otel/etc/hec_client_key
      {{- end }}
      {{- if .Values.splunkPlatform.caFile }}
      ca_file: /otel/etc/hec_ca_file
      {{- end }}
  {{- end }}

service:
  extensions: [health_check]
  pipelines:
    # k8s metrics pipeline
    metrics:
      receivers: [k8s_cluster]
      processors: [memory_limiter, batch, resource]
      exporters:
        {{- if eq (include "splunk-otel-collector.sendMetricsToO11y" .) "true" }}
        - signalfx
        {{- end }}
        {{- if eq (include "splunk-otel-collector.sendMetricsToSplunk" .) "true" }}
        - splunk_hec/platformMetrics
        {{- end }}

    # Pipeline for metrics collected about the collector pod itself.
    metrics/collector:
      receivers: [prometheus/k8s_cluster_receiver]
      processors:
        - memory_limiter
        - batch
        - resource
        - resource/add_collector_k8s
        - resourcedetection
      exporters: 
        {{- if eq (include "splunk-otel-collector.splunkO11yEnabled" .) "true" }}
        - signalfx
        {{- end }}
        {{- if eq (include "splunk-otel-collector.sendMetricsToSplunk" .) "true" }}
        - splunk_hec/platformMetrics
        {{- end }}
{{- end }}
