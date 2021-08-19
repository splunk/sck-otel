{{- define "opentelemetry-collector.pod" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
serviceAccountName: {{ include "opentelemetry-collector.serviceAccountName" . }}
securityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
containers:
  - name: otelcollector
    command:
      - /{{ .Values.command.name }}
      - --config=/conf/relay.yaml
      - --metrics-addr=0.0.0.0:8888
      {{- range .Values.command.extraArgs }}
      - {{ . }}
      {{- end }}
    securityContext:
      {{- toYaml .Values.securityContext | nindent 6 }}
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    ports:
      {{- range $key, $port := .Values.ports }}
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
      - name: MY_POD_IP
        valueFrom:
          fieldRef:
            apiVersion: v1
            fieldPath: status.podIP
      - name: SPLUNK_MEMORY_TOTAL_MIB
        value: "{{ include "opentelemetry-collector.convertMemToMib" .Values.resources.limits.memory }}"
      - name: KUBE_NODE_NAME
        valueFrom:
          fieldRef:
            apiVersion: v1
            fieldPath: spec.nodeName
      {{- with .Values.extraEnvs }}
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
      {{- toYaml .Values.resources | nindent 6 }}
    volumeMounts:
      - mountPath: /conf
        name: {{ .Chart.Name }}-configmap
      {{- range .Values.extraHostPathMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: {{ .readOnly }}
        {{- if .mountPropagation }}
        mountPropagation: {{ .mountPropagation }}
        {{- end }}
      {{- end }}
      {{- range .Values.secretMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: {{ .readOnly }}
        {{- if .subPath }}
        subPath: {{ .subPath }}
        {{- end }}
      {{- end }}
      {{- if .Values.containers.enabled }}
      - name: varlog
        mountPath: /var/log
        readOnly: true
      - name: varlibdockercontainers
        mountPath: /var/lib/docker/containers
        readOnly: true
      {{- end }}
      - name: checkpoint
        mountPath: {{ .Values.checkpointPath }}
      {{- if or .Values.splunk_hec.clientCert .Values.splunk_hec.clientKey .Values.splunk_hec.caFile }}
      - name: secret
        mountPath: /otel/etc
        readOnly: true
      {{- end }}
volumes:
  - name: {{ .Chart.Name }}-configmap
    configMap:
      name: {{ include "opentelemetry-collector.fullname" . }}
      items:
        - key: relay
          path: relay.yaml
  {{- range .Values.extraHostPathMounts }}
  - name: {{ .name }}
    hostPath:
      path: {{ .hostPath }}
  {{- end }}
  {{- range .Values.secretMounts }}
  - name: {{ .name }}
    secret:
      secretName: {{ .secretName }}
  {{- end }}
  {{- if .Values.containers.enabled }}
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
  {{- if or .Values.splunk_hec.clientCert .Values.splunk_hec.clientKey .Values.splunk_hec.caFile }}
  - name: secret
    secret:
      secretName: {{ template "opentelemetry-collector.secret" . }}
  {{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
