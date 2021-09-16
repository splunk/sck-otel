{{- define "splunk-otel-collector.pod" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "splunk-otel-collector.serviceAccountName" . }}
securityContext:
  {{- toYaml .Values.agent.podSecurityContext | nindent 2 }}
containers:
  - name: otelcollector
    command:
      - /{{ .Values.command.name }}
      - --config=/conf/relay.yaml
      - --metrics-addr=0.0.0.0:8889
      {{- range .Values.command.extraArgs }}
      - {{ . }}
      {{- end }}
    securityContext:
      {{- toYaml .Values.agent.securityContext | nindent 6 }}
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    ports:
      {{- range $key, $port := .Values.agent.ports }}
      {{- if $port.enabled }}
      - name: {{ $key }}
        containerPort: {{ $port.containerPort }}
        protocol: {{ $port.protocol }}
        {{- if $port.hostPort }}
        hostPort: {{ $port.hostPort }}
        {{- end }}
      {{- end }}
      {{- end }}
    env:
      - name: K8S_NODE_NAME
        valueFrom:
          fieldRef:
            fieldPath: spec.nodeName
      - name: K8S_NODE_IP
        valueFrom:
          fieldRef:
            apiVersion: v1
            fieldPath: status.hostIP
      - name: K8S_POD_IP
        valueFrom:
          fieldRef:
            apiVersion: v1
            fieldPath: status.podIP
      - name: K8S_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: K8S_POD_UID
        valueFrom:
          fieldRef:
            fieldPath: metadata.uid
      - name: K8S_NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
      {{- if .Values.metricsEnabled }}
      # Env variables for host metrics receiver
      - name: HOST_PROC
        value: /hostfs/proc
      - name: HOST_SYS
        value: /hostfs/sys
      - name: HOST_ETC
        value: /hostfs/etc
      - name: HOST_VAR
        value: /hostfs/var
      - name: HOST_RUN
        value: /hostfs/run
      - name: HOST_DEV
        value: /hostfs/dev
      {{- end }}
      - name: SPLUNK_MEMORY_TOTAL_MIB
        value: "{{ include "splunk-otel-collector.convertMemToMib" .Values.agent.resources.limits.memory }}"
      {{- if .Values.splunkObservability.accessToken }}
      - name: SPLUNK_O11Y_ACCESS_TOKEN
        valueFrom:
          secretKeyRef:
            name: {{ include "splunk-otel-collector.secret" . }}
            key: splunk_o11y_access_token
      {{- end }}
      {{- if .Values.splunkPlatform.token }}
      - name: SPLUNK_PLATFORM_HEC_TOKEN
        valueFrom:
          secretKeyRef:
            name: {{ include "splunk-otel-collector.secret" . }}
            key: splunk_platform_hec_token
      {{- end }}
      {{- with .Values.agent.extraEnvs }}
      {{- . | toYaml | nindent 6 }}
      {{- end }}
    livenessProbe: 
      httpGet:
        path: /
        port: 13133
    readinessProbe:
      httpGet:
        path: /
        port: 13133
    resources:
      {{- toYaml .Values.agent.resources | nindent 6 }}
    volumeMounts:
      - mountPath: /conf
        name: {{ .Chart.Name }}-configmap
      {{- if .Values.agent.extraVolumeMounts}}
      {{- with .Values.agent.extraVolumeMounts }}
      {{ . | toYaml | nindent 6 }}
      {{- end }}
      {{- end }}
      {{- if .Values.containerLogs.enabled }}
      - name: varlog
        mountPath: /var/log
        readOnly: true
      - name: varlibdockercontainers
        mountPath: /var/lib/docker/containers
        readOnly: true
      {{- end }}
      - name: checkpoint
        mountPath: {{ .Values.checkpointPath }}
      {{- if or .Values.splunkPlatform.clientCert .Values.splunkPlatform.clientKey .Values.splunkPlatform.caFile }}
      - name: secret
        mountPath: /otel/etc
        readOnly: true
      {{- end }}
volumes:
  - name: {{ .Chart.Name }}-configmap
    configMap:
      name: {{ include "splunk-otel-collector.fullname" . }}
      items:
        - key: relay
          path: relay.yaml
  {{- with .Values.agent.extraVolumes }}
  {{ . | toYaml | nindent 2 }}
  {{- end }}
  {{- if .Values.containerLogs.enabled }}
  - name: varlog
    hostPath:
      path: /var/log
  - name: varlibdockercontainers
    hostPath:
      path: /var/lib/docker/containers
  {{- end }}
  - name: checkpoint
    hostPath: 
      {{- with .Values.checkpointPath }}
      path: {{ . }}
      {{- end }}
      type: DirectoryOrCreate
  {{- if or .Values.splunkPlatform.clientCert .Values.splunkPlatform.clientKey .Values.splunkPlatform.caFile }}
  - name: secret
    secret:
      secretName: {{ template "splunk-otel-collector.secret" . }}-cert
  {{- end }}
{{- with .Values.agent.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.agent.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.agent.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
