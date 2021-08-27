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


{{/*
Build config file for agent OpenTelemetry Collector
*/}}
{{- define "splunk-otel-collector.agentCollectorConfig" -}}
{{- $values := deepCopy .Values | mustMergeOverwrite (deepCopy .Values) }}
{{- $data := dict "Values" $values | mustMergeOverwrite (deepCopy .) }}
{{- $config := include "splunk-otel-collector.agent.containerLogsConfig" $data | fromYaml }}
{{/*{{ printf "%+v" $config }}*/}}
{{- $config := .Values.agent.config | mustMergeOverwrite $config }}
{{- include "splunk-otel-collector.agent.hecConfig" . | fromYaml | mustMergeOverwrite $config | toYaml }}
{{- end }}

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

{{- define "splunk-otel-collector.agent.hecConfig" -}}
exporters:
  {{- if .Values.splunkPlatform.endpoint }}
  splunk_hec/platform:
    splunk_app_name: {{ .Chart.Name }}
    splunk_app_version: {{ .Chart.Version }}
  {{- end }}
  {{- if .Values.splunkObservability.logsEnabled }} # TODO - need to update when metric/trace pipeline is added
  {{- if or .Values.splunkObservability.ingestUrl .Values.splunkObservability.realm }}
  splunk_hec/o11y:
    splunk_app_name: {{ .Chart.Name }}
    splunk_app_version: {{ .Chart.Version }}
  {{- end }}
  {{- end }}
{{- end }}

{{- define "splunk-otel-collector.agent.containerLogsConfig" -}}
extensions:
  health_check: {}
  file_storage:
    directory: {{ .Values.checkpointPath }}
  memory_ballast:
#   In general, the ballast should be set to 1/3 of the collector's memory, the limit
#   should be 90% of the collector's memory.
#   The simplest way to specify the ballast size is set the value of SPLUNK_BALLAST_SIZE_MIB env variable.
    size_mib: ${SPLUNK_BALLAST_SIZE_MIB}
receivers:
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
    encoding: nop
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
          container_name: 'EXPR($$.container_name)'
          k8s.namespace.name: 'EXPR($$.namespace)'
          k8s.pod.name: 'EXPR($$.pod_name)'
          com.splunk.sourcetype: 'EXPR("kube:container:"+$$.container_name)'
      {{- if .Values.containerLogs.multilineSupportConfig }}
      - type: router
        routes:
        {{- range $.Values.containerLogs.multilineSupportConfig }}
        - output: {{ .containerName | quote }}
          expr: '($$.container_name) == {{ .containerName | quote }}'
        {{- end }}
        default: clean-up-log-record
      {{- range $.Values.containerLogs.multilineSupportConfig }}
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
      node_from_env_var: KUBE_NODE_NAME
  {{- end }}
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
    - key: com.splunk.index
      from_attribute: k8s.pod.annotations.splunk.com/index
      action: upsert
    - key: service.name
      from_attribute: k8s.pod.name
      action: upsert
    - key: service.name
      from_attribute: k8s.pod.labels.app
      action: upsert
exporters:
  {{- if .Values.splunkPlatform.endpoint }}
  splunk_hec/platform:
    endpoint: {{ .Values.splunkPlatform.endpoint | quote }}
    token: "${SPLUNK_PLATFORM_HEC_TOKEN}"
    index: {{ .Values.splunkPlatform.index | quote }}
    source: {{ .Values.splunkPlatform.source | quote }}
    sourcetype: {{ .Values.splunkPlatform.sourcetype | quote }}
    max_connections: {{ .Values.splunkPlatform.max_connections }}
    disable_compression: {{ .Values.splunkPlatform.disable_compression }}
    timeout: {{ .Values.splunkPlatform.timeout }}
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
  {{- if .Values.splunkObservability.logsEnabled }}
  {{- if or .Values.splunkObservability.ingestUrl .Values.splunkObservability.realm }}
  splunk_hec/o11y:
    endpoint: {{ include "splunk-otel-collector.ingestUrl" . }}/v1/log
    token: "${SPLUNK_O11Y_ACCESS_TOKEN}"
  {{- end }}
  {{- end }}
service:
  extensions:
    - health_check
    - file_storage
  pipelines:
    {{- if .Values.containerLogs.enabled }}
    logs/container:
      receivers:
        - filelog
      processors:
        - memory_limiter
        - batch
        {{- if .Values.k8sMetadata.enabled }}
        - k8s_tagger
        {{- end }}
        - resource/splunk
      exporters:
        {{- if .Values.splunkPlatform.endpoint }}
        - splunk_hec/platform
        {{- end }}
        {{- if .Values.splunkObservability.logsEnabled }}
        {{- if or .Values.splunkObservability.ingestUrl .Values.splunkObservability.realm }}
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
        {{- if .Values.splunkPlatform.endpoint }}
        - splunk_hec/platform
        {{- end }}
        {{- if .Values.splunkObservability.logsEnabled }}
        {{- if or .Values.splunkObservability.ingestUrl .Values.splunkObservability.realm }}
        - splunk_hec/o11y
        {{- end }}
        {{- end }}
    {{- end }}
{{- end }}
