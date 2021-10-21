{{/*
Build config file for agent OpenTelemetry Collector
*/}}
{{- define "splunk-otel-collector.agentCollectorConfig" -}}
{{- $values := deepCopy .Values | mustMergeOverwrite (deepCopy .Values) }}
{{- $data := dict "Values" $values | mustMergeOverwrite (deepCopy .) }}
{{- $config := include "splunk-otel-collector.otelAgentConfig" $data | fromYaml }}
{{- $config := .Values.agent.config | mustMergeOverwrite $config }}
{{- include "splunk-otel-collector.agent.hecConfig" . | fromYaml | mustMergeOverwrite $config | toYaml }}
{{- end }}

{{- define "splunk-otel-collector.otelAgentConfig" -}}
extensions:
  health_check: {}
  file_storage:
    directory: {{ .Values.checkpointPath }}
  memory_ballast:
#   In general, the ballast should be set to 1/3 of the collector's memory, the limit
#   should be 90% of the collector's memory.
#   The simplest way to specify the ballast size is set the value of SPLUNK_BALLAST_SIZE_MIB env variable.
    size_mib: ${SPLUNK_BALLAST_SIZE_MIB}
  k8s_observer:
    auth_type: serviceAccount
    node: ${K8S_NODE_NAME}
  zpages:
receivers:
# https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/journaldreceiver
  {{- if .Values.journaldLogs.enabled }}
  {{- if .Values.journaldLogs.units }}
  {{- range $_, $unit := .Values.journaldLogs.units }}
  {{- printf "journald/%s:" $unit.name | nindent 2 }}
    directory: {{ $.Values.journaldLogs.directory }}
    units: [{{ $unit.name }}]
    priority: {{ $unit.priority | default $.Values.journaldLogs.defaultPriority }}
    resource:
      com.splunk.source: {{ $.Values.journaldLogs.directory }}
      com.splunk.sourcetype: 'EXPR("kube:"+$$._SYSTEMD_UNIT)'
      com.splunk.index: {{ $.Values.journaldLogs.index | default $.Values.splunkPlatform.index}}
      host.name: 'EXPR(env("K8S_NODE_NAME"))'
      {{- if $.Values.clusterName }}
      k8s.cluster.name: {{ $.Values.clusterName }}
      {{- end }}
      {{- if $.Values.environment }}
      deployment.environment: {{ $.Values.environment }}
      {{- end }}
      {{- if $.Values.customMetadata }}
      {{- toYaml $.Values.customMetadata | nindent 6 }}
      {{- end }}
  {{- end }}
  {{- else }}
  journald:
    directory: {{- toYaml .Values.journaldLogs.directory | nindent 6 }}
    priority: {{ .Values.journaldLogs.defaultPriority }}
  {{- end }}
  {{- end }}
  {{- include "splunk-otel-collector.otelTraceReceivers" . | nindent 2 }}
  # Prometheus receiver scraping metrics from the pod itself
  prometheus/agent:
    config:
      scrape_configs:
      - job_name: 'otel-agent'
        scrape_interval: 10s
        static_configs:
        - targets:
          - "${K8S_POD_IP}:8889"

  {{- if eq (include "splunk-otel-collector.collectMetric" .) "true" }}
  hostmetrics:
    collection_interval: 10s
    scrapers:
      cpu:
      disk:
      filesystem:
      memory:
      network:
      # System load average metrics https://en.wikipedia.org/wiki/Load_(computing)
      load:
      # Paging/Swap space utilization and I/O metrics
      paging:
      # Aggregated system process count metrics
      processes:
      # System processes metrics, disabled by default
      # process:

  receiver_creator:
    watch_observers: [k8s_observer]
    receivers:
      {{- if or .Values.autodetect.prometheus .Values.autodetect.istio }}
      prometheus_simple:
        {{- if .Values.autodetect.prometheus }}
        # Enable prometheus scraping for pods with standard prometheus annotations
        rule: type == "pod" && annotations["prometheus.io/scrape"] == "true"
        {{- else }}
        # Enable prometheus scraping for istio pods only
        rule: type == "pod" && annotations["prometheus.io/scrape"] == "true" && "istio.io/rev" in labels
        {{- end }}
        config:
          metrics_path: '`"prometheus.io/path" in annotations ? annotations["prometheus.io/path"] : "/metrics"`'
          endpoint: '`endpoint`:`"prometheus.io/port" in annotations ? annotations["prometheus.io/port"] : 9090`'
      {{- end }}

  kubeletstats:
    collection_interval: 10s
    auth_type: serviceAccount
    endpoint: ${K8S_NODE_IP}:10250
    metric_groups:
      - container
      - pod
      - node
      # Volume metrics are not collected by default
      # - volume
    # To collect metadata from underlying storage resources, set k8s_api_config and list k8s.volume.type
    # under extra_metadata_labels
    # k8s_api_config:
    #  auth_type: serviceAccount
    extra_metadata_labels:
      - container.id
      # - k8s.volume.type

  signalfx:
    endpoint: 0.0.0.0:9943
  {{- end }}

  {{- if eq (include "splunk-otel-collector.collectTrace" .) "true" }}
  smartagent/signalfx-forwarder:
    type: signalfx-forwarder
    listenAddress: 0.0.0.0:9080
  {{- end }}

  # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver
  {{- if .Values.containerLogs.enabled }}
  filelog:
    include: [ {{ .Values.containerLogs.path }} ]
    # Exclude collector container's logs. The file format is /var/log/pods/<namespace_name>_<pod_name>_<pod_uid>/<container_name>/<run_id>.log
    exclude:
      {{- if .Values.containerLogs.excludeAgentLogs }}
      - /var/log/pods/{{ .Release.Namespace }}_{{ include "splunk-otel-collector.fullname" . }}*_*/otelcollector/*.log
      {{- end }}
      {{- range $_, $excludePath := .Values.containerLogs.exclude_paths }}
      - {{ $excludePath }}
      {{- end }}
    start_at: beginning
    include_file_path: true
    include_file_name: false
    poll_interval: 200ms
    resource:
      {{- if .Values.clusterName }}
      k8s.cluster.name: {{ .Values.clusterName }}
      {{- end }}
      {{- if .Values.environment }}
      deployment.environment: {{ .Values.environment }}
      {{- end }}
      {{- if .Values.customMetadata }}
      {{- toYaml .Values.customMetadata | nindent 6 }}
      {{- end }}
    max_concurrent_files: 1024
    encoding: utf-8
    fingerprint_size: 1kb
    max_log_size: 1MiB
    operators:
      {{- if not .Values.containerLogs.containerRuntime }}
      - type: router
        id: get-format
        routes:
          - output: parser-docker
            expr: '$$$$body matches "^\\{"'
          - output: parser-crio
            expr: '$$$$body matches "^[^ Z]+ "'
          - output: parser-containerd
            expr: '$$$$body matches "^[^ Z]+Z"'
      {{- end }}
      {{- if or (not .Values.containerLogs.containerRuntime) (eq .Values.containerLogs.containerRuntime "cri-o") }}
      # Parse CRI-O format
      - type: regex_parser
        id: parser-crio
        regex: '^(?P<time>[^ Z]+) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) (?P<log>.*)$'
        timestamp:
          parse_from: time
          layout_type: gotime
          layout: '2006-01-02T15:04:05.000000000-07:00'
      - type: recombine
        id: crio-recombine
        combine_field: log
        is_last_entry: "($$.logtag) == 'F'"
      - type: restructure
        id: crio-handle_empty_log
        output: filename
        if: $$.log == nil
        ops:
          - add:
              field: log
              value: ""
      {{- end }}
      {{- if or (not .Values.containerLogs.containerRuntime) (eq .Values.containerLogs.containerRuntime "containerd") }}
      # Parse CRI-Containerd format
      - type: regex_parser
        id: parser-containerd
        regex: '^(?P<time>[^ ^Z]+Z) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) (?P<log>.*)$'
        timestamp:
          parse_from: time
          layout: '%Y-%m-%dT%H:%M:%S.%LZ'
      - type: recombine
        id: containerd-recombine
        combine_field: log
        is_last_entry: "($$.logtag) == 'F'"
      - type: restructure
        id: containerd-handle_empty_log
        output: filename
        if: $$.log == nil
        ops:
          - add:
              field: log
              value: ""
      {{- end }}
      {{- if or (not .Values.containerLogs.containerRuntime) (eq .Values.containerLogs.containerRuntime "docker") }}
      # Parse Docker format
      - type: json_parser
        id: parser-docker
        timestamp:
          parse_from: time
          layout: '%Y-%m-%dT%H:%M:%S.%LZ'
      {{- end }}
      - type: metadata
        id: filename
        resource:
          com.splunk.source: EXPR($$$$attributes["file.path"])
      # Extract metadata from file path
      - type: regex_parser
        id: extract_metadata_from_filepath
        regex: '^\/var\/log\/pods\/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<uid>[^\/]+)\/(?P<container_name>[^\._]+)\/(?P<run_id>\d+)\.log$'
        parse_from: $$$$attributes["file.path"]
      # Move out attributes to Attributes
      - type: metadata
        resource:
          k8s.pod.uid: 'EXPR($$.uid)'
          run_id: 'EXPR($$.run_id)'
          stream: 'EXPR($$.stream)'
          k8s.container.name: 'EXPR($$.container_name)'
          k8s.namespace.name: 'EXPR($$.namespace)'
          k8s.pod.name: 'EXPR($$.pod_name)'
          com.splunk.sourcetype: 'EXPR("kube:container:"+$$.container_name)'
      {{- if .Values.containerLogs.multilineConfigs }}
      - type: router
        routes:
        {{- range $.Values.containerLogs.multilineConfigs }}
        - output: {{ .containerName | quote }}
          expr: '($$$$resource["k8s.container.name"]) == {{ .containerName | quote }}'
        {{- end }}
        default: clean-up-log-record
      {{- range $.Values.containerLogs.multilineConfigs }}
      - type: recombine
        id: {{.containerName | quote }}
        output: clean-up-log-record
        combine_field: log
        is_first_entry: '($$.log) matches {{ .first_entry_regex | quote }}'
      {{- end }}
      {{- end }}
      {{- with .Values.containerLogs.extraOperators }}
      {{ . | toYaml | nindent 6 }}
      {{- end }}
      # Clean up log record
      - type: restructure
        id: clean-up-log-record
        ops:
          - move:
              from: log
              to: $$
  {{- end }}
  {{- if .Values.extraFileLogs }}
  {{- toYaml .Values.extraFileLogs | nindent 2 }}
  {{- end }}
processors:
  batch:
    send_batch_size: 8192
    timeout: "200ms"
  memory_limiter:
    {{- include "splunk-otel-collector.memoryLimiter" . | nindent 4 }}
  {{- if .Values.k8sMetadata.enabled }}
  k8s_tagger:
    passthrough: false
    auth_type: "kubeConfig"
    pod_association:
      - from: resource_attribute
        name: k8s.pod.uid
    extract:
      metadata:
        - k8s.pod.name
        - k8s.pod.uid
        - k8s.deployment.name
        {{- if not .Values.clusterName }}
        - k8s.cluster.name
        {{- end }}
        - k8s.namespace.name
        - k8s.node.name
        - k8s.pod.start_time
      annotations:
        - key: splunk.com/index
          from: pod
        - key: splunk.com/sourcetype
          from: pod
        - key: splunk.com/exclude
          from: pod
        - key: splunk.com/include
          from: pod
        - key: splunk.com/index
          from: namespace
        - key: splunk.com/exclude
          from: namespace
        {{- range $k, $v := .Values.k8sMetadata.annotations }}
        - {{ range $kk, $vv := $v }}{{ $kk }}: {{ $vv }}
          {{ end }}
        {{- end }}
      labels:
        {{- range $k, $v := .Values.k8sMetadata.labels }}
        - {{ range $kk, $vv := $v }}{{ $kk }}: {{ $vv }}
          {{ end }}
        {{- end }}
    filter:
      node_from_env_var: K8S_NODE_NAME
  {{- end }}
  # TODO - when new image is released with source_key, sourtype_key, etc., update this processor and splunk hec exporter config
  resource/splunk:
    attributes:
    - key: host.name
      from_attribute: k8s.node.name
      action: upsert
    - key: com.splunk.sourcetype
      from_attribute: k8s.pod.annotations.splunk.com/sourcetype
      action: upsert
    - key: com.splunk.index
      from_attribute: k8s.namespace.annotations.splunk.com/index
      action: upsert
    - key: service.name
      from_attribute: k8s.pod.name
      action: upsert
    - key: service.name
      from_attribute: k8s.pod.labels.app
      action: upsert
  resource/splunk2:
    attributes:
      - key: com.splunk.index
        from_attribute: k8s.pod.annotations.splunk.com/index
        action: upsert
      {{- if .Values.splunkPlatform.sourcetype }}
      - key: com.splunk.sourcetype
        value: "{{.Values.splunkPlatform.sourcetype }}"
        action: upsert
      {{- end }}
  {{- include "splunk-otel-collector.resourceDetectionProcessor" . | nindent 2 }}
  resource/telemetry:
    # General resource attributes that apply to all telemetry passing through the agent.
    attributes:
      - action: insert
        key: k8s.node.name
        value: "${K8S_NODE_NAME}"
      {{- if .Values.clusterName }}
      - action: insert
        key: k8s.cluster.name
        value: "{{ .Values.clusterName }}"
      {{- end }}
      {{- range $k, $v := .Values.customMetadata }}
      - action: insert
        key: {{ $k }}
        value: {{ $v }}
      {{- end }}

  # Resource attributes specific to the agent itself.
  resource/add_agent_k8s:
    attributes:
      - action: insert
        key: k8s.pod.name
        value: "${K8S_POD_NAME}"
      - action: insert
        key: k8s.pod.uid
        value: "${K8S_POD_UID}"
      - action: insert
        key: k8s.namespace.name
        value: "${K8S_NAMESPACE}"

  {{- if .Values.environment }}
  resource/add_environment:
    attributes:
      - action: insert
        key: deployment.environment
        value: "{{ .Values.environment }}"
  {{- end }}

  {{- if .Values.containerLogs.useSplunkIncludeAnnotation }}
  # If .Values.containerLogs.useSplunkIncludeAnnotation is set to true, only logs for pods with include annotation are ingested
  filter/include_pod_logs:
    logs:
      # any logs matching the pod include annotation are included and the rest are excluded from remainder of pipeline
      include:
        match_type: strict
        resource_attributes:
          - key: k8s.pod.annotations.splunk.com/include
            value: "true"
  {{- else }}
  filter/exclude_namespace_logs:
    logs:
      # any logs matching the namespace exclude annotation are excluded from remainder of pipeline
      exclude:
        match_type: strict
        resource_attributes:
          - key: k8s.namespace.annotations.splunk.com/exclude
            value: "true"
  filter/exclude_pod_logs:
    logs:
      # any logs matching the pod exclude annotation are excluded from remainder of pipeline
      exclude:
        match_type: strict
        resource_attributes:
          - key: k8s.pod.annotations.splunk.com/exclude
            value: "true"
  {{- end }}

  {{- include "splunk-otel-collector.resourceDetectionProcessor" . | nindent 2 }}
exporters:
  {{- if eq (include "splunk-otel-collector.splunkPlatformEnabled" .) "true" }}
  splunk_hec/platform:
    endpoint: {{ .Values.splunkPlatform.endpoint | quote }}
    token: "${SPLUNK_PLATFORM_HEC_TOKEN}"
    index: {{ .Values.splunkPlatform.index | quote }}
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
  {{- end }}
  {{- if eq (include "splunk-otel-collector.splunkO11yEnabled" .) "true" }}
  splunk_hec/o11y:
    endpoint: {{ include "splunk-otel-collector.ingestUrl" . }}/v1/log
    token: "${SPLUNK_O11Y_ACCESS_TOKEN}"
  {{- end }}
  {{- if .Values.gateway.enabled }}
  # If gateway is enabled, metrics, logs and traces will be sent to collector
  otlp:
    endpoint: {{ include "splunk-otel-collector.fullname" . }}:4317
    insecure: true
  {{- else }}
  # If gateway is disabled, metrics, logs and traces will be sent to to SignalFx backend
  {{- include "splunk-otel-collector.otelSapmExporter" . | nindent 2 }}
  {{- end }}
  {{- if eq (include "splunk-otel-collector.splunkO11yEnabled" .) "true" }}
  signalfx:
    correlation:
    {{- if .Values.gateway.enabled }}
    ingest_url: http://{{ include "splunk-otel-collector.fullname" . }}:9943
    api_url: http://{{ include "splunk-otel-collector.fullname" . }}:6060
    {{- else }}
    ingest_url: {{ include "splunk-otel-collector.ingestUrl" . }}
    api_url: {{ include "splunk-otel-collector.apiUrl" . }}
    {{- end }}
    access_token: ${SPLUNK_O11Y_ACCESS_TOKEN}
    sync_host_metadata: true
  {{- end }}
service:
  extensions:
    - health_check
    - file_storage
    - k8s_observer
    - zpages
  pipelines:
    {{- if eq (include "splunk-otel-collector.collectLog" .) "true" }}
    {{- if .Values.containerLogs.enabled }}
    logs/container:
      receivers:
        - filelog
      processors:
        - memory_limiter
        - batch
        - resourcedetection
        {{- if .Values.k8sMetadata.enabled }}
        - k8s_tagger
        {{- end }}
        - resource/splunk
        - resource/splunk2
        {{- if .Values.containerLogs.useSplunkIncludeAnnotation }}
        - filter/include_pod_logs
        {{- else }}
        - filter/exclude_pod_logs
        - filter/exclude_namespace_logs
        {{- end }}
      exporters:
        {{- if eq (include "splunk-otel-collector.sendLogsToSplunk" .) "true" }}
        - splunk_hec/platform
        {{- end }}
        {{- if eq (include "splunk-otel-collector.sendLogsToO11y" .) "true" }}
        - splunk_hec/o11y
        {{- end }}
    {{- end }}
    {{- end }}
    {{- if .Values.extraFileLogs }}
    logs/extraFiles:
      receivers:
        {{- range $key, $exporterData := .Values.extraFileLogs }}
        - {{ $key }}
        {{ end }}
      processors:
        - memory_limiter
        - batch
      exporters:
        {{- if eq (include "splunk-otel-collector.sendLogsToSplunk" .) "true" }}
        - splunk_hec/platform
        {{- end }}
        {{- if eq (include "splunk-otel-collector.sendLogsToO11y" .) "true" }}
        - splunk_hec/o11y
        {{- end }}
    {{- end }}
    {{- if eq (include "splunk-otel-collector.collectTrace" .) "true" }}
    # Default traces pipeline.
    traces:
      receivers: [otlp, jaeger, smartagent/signalfx-forwarder, zipkin]
      processors:
        - memory_limiter
        - k8s_tagger
        - batch
        - resource/telemetry
        - resourcedetection
        {{- if .Values.environment }}
        - resource/add_environment
        {{- end }}
      exporters:
        {{- if .Values.gateway.enabled }}
        - otlp
        {{- else }}
        - sapm
        {{- end }}
        {{- if eq (include "splunk-otel-collector.sendMetricsToO11y" .) "true" }}
        # For trace/metric correlation.
        - signalfx
        {{- end }}
    {{- end }}

    {{- if eq (include "splunk-otel-collector.collectMetric" .) "true" }}
    # Default metrics pipeline.
    metrics:
      receivers: [hostmetrics, kubeletstats, receiver_creator, signalfx]
      processors:
        - memory_limiter
        - batch
        - resource/telemetry
        - resourcedetection
      exporters:
        {{- if .Values.gateway.enabled }}
        - otlp
        {{- else }}
        {{- if eq (include "splunk-otel-collector.sendMetricsToO11y" .) "true" }}
        - signalfx
        {{- end }}
        {{- if eq (include "splunk-otel-collector.sendMetricsToSplunk" .) "true" }}
        - splunk_hec/platformMetrics
        {{- end }}
        {{- end }}
    {{- end }}

    {{- if or (eq (include "splunk-otel-collector.splunkO11yEnabled" .) "true") (eq (include "splunk-otel-collector.sendMetricsToSplunk" .) "true") }}
    # Pipeline for metrics collected about the agent pod itself.
    metrics/agent:
      receivers: [prometheus/agent]
      processors:
        - memory_limiter
        - batch
        - resource/telemetry
        - resource/add_agent_k8s
        - resourcedetection
      exporters:
        # Use signalfx instead of otlp even if collector is enabled
        # in order to sync host metadata.
        {{- if eq (include "splunk-otel-collector.splunkO11yEnabled" .) "true" }}
        - signalfx
        {{- end }}
        {{- if eq (include "splunk-otel-collector.sendMetricsToSplunk" .) "true" }}
        - splunk_hec/platformMetrics
        {{- end }}
    {{- end }}
    {{- if eq (include "splunk-otel-collector.collectLog" .) "true" }}
    {{- if .Values.journaldLogs.enabled }}
    logs/journald:
      receivers:
        {{- if .Values.journaldLogs.units }}
        {{- range $_, $unit := .Values.journaldLogs.units }}
        {{- printf "- journald/%s" $unit.name | nindent 8 }}
        {{- end }}
        {{- else }}
        - journald
        {{- end }}
      processors:
        - batch
      exporters:
        {{- if eq (include "splunk-otel-collector.sendLogsToSplunk" .) "true" }}
        - splunk_hec/platform
        {{- end }}
        {{- if eq (include "splunk-otel-collector.sendLogsToO11y" .) "true" }}
        - splunk_hec/o11y
        {{- end }}
    {{- end }}
    {{- end }}
{{- end }}
