{{/*
Default memory limiter configuration for OpenTelemetry Collector based on k8s resource limits.
*/}}
{{- define "opentelemetry-collector.memoryLimiter" -}}
# check_interval is the time between measurements of memory usage.
check_interval: 5s

# By default limit_mib is set to 80% of ".Values.resources.limits.memory"
limit_mib: {{ include "opentelemetry-collector.getMemLimitMib" .Values.resources.limits.memory }}

# By default spike_limit_mib is set to 25% of ".Values.resources.limits.memory"
spike_limit_mib: {{ include "opentelemetry-collector.getMemSpikeLimitMib" .Values.resources.limits.memory }}

# By default ballast_size_mib is set to 40% of ".Values.resources.limits.memory"
ballast_size_mib: {{ include "opentelemetry-collector.getMemBallastSizeMib" .Values.resources.limits.memory }}
{{- end }}


{{/*
Build config file for agent OpenTelemetry Collector
*/}}
{{- define "opentelemetry-collector.agentCollectorConfig" -}}
{{- $values := deepCopy .Values | mustMergeOverwrite (deepCopy .Values)  }}
{{- $data := dict "Values" $values | mustMergeOverwrite (deepCopy .) }}
{{- $config := include "opentelemetry-collector.agent.containerLogsConfig" $data | fromYaml }}
{{- $config := .Values.configOverride | mustMergeOverwrite $config }}
{{- include "opentelemetry-collector.agent.hecConfig" . | fromYaml | mustMergeOverwrite $config | toYaml }}
{{- end }}

{{/*
Convert memory value from resources.limit to numeric value in MiB to be used by otel memory_limiter processor.
*/}}
{{- define "opentelemetry-collector.convertMemToMib" -}}
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

{{/*
Get otel memory_limiter limit_mib value based on 80% of resources.memory.limit.
*/}}
{{- define "opentelemetry-collector.getMemLimitMib" -}}
{{- div (mul (include "opentelemetry-collector.convertMemToMib" .) 80) 100 }}
{{- end -}}

{{/*
Get otel memory_limiter spike_limit_mib value based on 25% of resources.memory.limit.
*/}}
{{- define "opentelemetry-collector.getMemSpikeLimitMib" -}}
{{- div (mul (include "opentelemetry-collector.convertMemToMib" .) 25) 100 }}
{{- end -}}

{{/*
Get otel memory_limiter ballast_size_mib value based on 40% of resources.memory.limit.
*/}}
{{- define "opentelemetry-collector.getMemBallastSizeMib" }}
{{- div (mul (include "opentelemetry-collector.convertMemToMib" .) 40) 100 }}
{{- end -}}

{{- define "opentelemetry-collector.agent.hecConfig" -}}
exporters:
  splunk_hec:
    splunk_app_name: {{ .Chart.Name }}
    splunk_app_version: {{ .Chart.Version }}
{{- end }}

{{- define "opentelemetry-collector.agent.containerLogsConfig" -}}
extensions:
  health_check: {}
  file_storage:
    directory: /var/lib/otel_pos
receivers:
  # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver
  filelog:
    include: [ /var/log/pods/*/*/*.log ]
    # Exclude collector container's logs. The file format is /var/log/pods/<namespace_name>_<pod_name>_<pod_uid>/<container_name>/<run_id>.log
    exclude:
      {{- if .Values.containers.excludeAgentLogs }}
      - /var/log/pods/{{ .Release.Namespace }}_{{ include "opentelemetry-collector.fullname" . }}*_*/{{ .Chart.Name }}/*.log
      {{- end }}
      {{- range $_, $excludePath := .Values.containers.exclude_paths }}
      - {{ $excludePath }}
      {{- end }}
    start_at: beginning
    include_file_path: true
    include_file_name: false
    poll_interval: 200ms
    {{- if .Values.customMetadata }}
    resource:
      {{- toYaml .Values.customMetadata | nindent 6 }}
    {{- end }}
    max_concurrent_files: 1024
    encoding: nop
    fingerprint_size: 1kb
    max_log_size: 1MiB
    operators:
      {{- if eq .Values.containers.containerRuntime "cri-o" }}
      # Parse CRI-O format
      - type: regex_parser
        id: parser-crio
        regex: '^(?P<time>[^ Z]+) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) (?P<log>.*)$'
        timestamp:
          parse_from: time
          layout_type: gotime
          layout: '2006-01-02T15:04:05.000000000-07:00'
      - type: recombine
        output: extract_metadata_from_filepath
        combine_field: log
        is_last_entry: "($.logtag) == 'F'"
      - type: restructure
        id: check for empty log
        ops:
          - add:
              if: 'EXPR($.log) != nil'
              field: log
              value: ""
      {{- end }}
      {{- if eq .Values.containers.containerRuntime "containerd" }}
      # Parse CRI-Containerd format
      - type: regex_parser
        id: parser-containerd
        regex: '^(?P<time>[^ ^Z]+Z) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) (?P<log>.*)$'
        timestamp:
          parse_from: time
          layout: '%Y-%m-%dT%H:%M:%S.%LZ'
      - type: recombine
        output: extract_metadata_from_filepath
        combine_field: log
        is_last_entry: "($.logtag) == 'F'"
      {{- end }}
      # Parse Docker format
      {{- if eq .Values.containers.containerRuntime "docker" }}
      - type: json_parser
        id: parser-docker
        timestamp:
          parse_from: time
          layout: '%Y-%m-%dT%H:%M:%S.%LZ'
      {{- end }}
      # Store the file_path to `service.name` field (`source` field)
      - type: metadata
        id: filename
        resource:
          service.name: EXPR($$attributes.file_path)
      # Extract metadata from file path
      - type: regex_parser
        id: extract_metadata_from_filepath
        regex: '^\/var\/log\/pods\/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<uid>[^\/]+)\/(?P<container_name>[^\._]+)\/(?P<run_id>\d+)\.log$'
        parse_from: $$attributes.file_path
      # Move out attributes to Attributes
      - type: metadata
        resource:
          k8s.pod.uid: 'EXPR($.uid)'
          run_id: 'EXPR($.run_id)'
          stream: 'EXPR($.stream)'
          container_name: 'EXPR($.container_name)'
          k8s.namespace.name: 'EXPR($.namespace)'
          k8s.pod.name: 'EXPR($.pod_name)'
          com.splunk.sourcetype: 'EXPR("kube:container:"+$.container_name)'
      # Clean up log record
      - type: restructure
        id: clean-up-log-record
        ops:
          - move:
              from: log
              to: $
  {{- if .Values.extraHostFileConfig }}
  {{- toYaml .Values.extraHostFileConfig | nindent 2 }}
  {{- end }}
processors:
  batch:
    send_batch_size: {{ .Values.batch.send_batch_size | default 8192 }}
    timeout: {{ .Values.batch.timeout | quote | default "200ms" }}
    send_batch_max_size: {{ .Values.batch.send_batch_max_size | default 0 }}
  memory_limiter:
    {{ include "opentelemetry-collector.memoryLimiter" . | nindent 4 }}
  {{- if .Values.containers.enrichK8sMetadata }}
  k8s_tagger:
    passthrough: false
    auth_type: "kubeConfig"
    pod_association:
      - from: resource_attribute
        name: k8s.pod.uid
    extract:
      metadata:
        - deployment
        - cluster
        - namespace
        - node
        - startTime
      annotations:
        {{- toYaml .Values.containers.listOfAnnotations | nindent 8 }}
      labels:
        {{- toYaml .Values.containers.listOfLabels | nindent 8 }}
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
exporters:
  splunk_hec:
    endpoint: {{ .Values.splunk_hec.endpoint | quote }}
    token: {{ .Values.splunk_hec.token | quote }}
    index: {{ .Values.splunk_hec.index | quote }}
    source: {{ .Values.splunk_hec.source | quote }}
    sourcetype: {{ .Values.splunk_hec.sourcetype | quote }}
    max_connections: {{ .Values.splunk_hec.max_connections }}
    disable_compression: {{ .Values.splunk_hec.disable_compression }}
    timeout: {{ .Values.splunk_hec.timeout }}
    insecure_skip_verify: {{ .Values.splunk_hec.insecure_skip_verify }}
    {{- if .Values.splunk_hec.clientCert }}
    cert_file: /otel/etc/hec_client_cert
    {{- end }}
    {{- if .Values.splunk_hec.clientKey  }}
    key_file: /otel/etc/hec_client_key
    {{- end }}
    {{- if .Values.splunk_hec.caFile }}
    ca_file: /otel/etc/hec_ca_file
    {{- end }}
    server_name_override: host.docker.internal
service:
  extensions:
    - health_check
    - file_storage
  pipelines:
    logs/container:
      receivers:
        - filelog
      processors:
        - memory_limiter
        - batch
        {{- if .Values.containers.enrichK8sMetadata }}
        - k8s_tagger
        {{- end }}
        - resource/splunk
      exporters:
        - splunk_hec
    {{- if .Values.extraHostFileConfig }}
    logs/extraFiles:
      receivers:
        {{- range $key, $exporterData := .Values.extraHostFileConfig }}
        - {{ $key }}
        {{ end }}
      processors:
        - memory_limiter
        - batch
      exporters:
        - splunk_hec
    {{- end }}
{{- end }}
