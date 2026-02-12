{{/*
Reusable StatefulSet template.
Params similar to ag-template.deployment, plus:
  .ServiceName (string) - headless service name for stable network IDs
  .VolumeClaims (template name) - list of PVC templates
*/}}
{{- define "ag-template.statefulset" -}}
{{- $p := . -}}
{{- $mv := default (dict) $p.ModuleValues -}}
{{- if not ($mv.disabled | default false) }}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ printf "%s-%s" $p.ApplicationGroup $p.Name | trunc 63 | trimSuffix "-" }}
  {{- if $p.Namespace }}
  namespace: {{ $p.Namespace }}
  {{- else if $.Release }}
  namespace: {{ $.Release.Namespace }}
  {{- end }}
  labels:
    app.kubernetes.io/name: {{ $p.Name }}
    app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
{{ include "ag-template.commonLabels" $p | nindent 4 }}
{{- if $p.LabelData }}
{{- with (include $p.LabelData $p | fromYaml) }}
{{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}
spec:
  replicas: {{ default 1 $mv.replicas }}
  serviceName: {{ required "ServiceName is required for StatefulSet" $p.ServiceName }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ $p.Name }}
      app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ $p.Name }}
        app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
{{ include "ag-template.dataClassLabel" $p | nindent 8 }}
{{- if $p.LabelData }}
{{- with (include $p.LabelData $p | fromYaml) }}
{{- toYaml . | nindent 8 }}
{{- end }}
{{- end }}
    spec:
      terminationGracePeriodSeconds: {{ default 30 $mv.terminationGracePeriod }}
      containers:
        - name: {{ $p.Name }}
          {{ $img := get $mv "image" | default (dict) }}
          {{ $tag := get $img "tag" }}
          image: {{ printf "%s/%s:%s" $p.Registry $p.Name (required "ModuleValues.image.tag is required" $tag) }}
          {{ $pullPolicy := get $img "pullPolicy" }}
          imagePullPolicy: {{ default "IfNotPresent" $pullPolicy }}
          {{- if $p.Ports }}
          ports:
{{ include $p.Ports $p | nindent 12 }}
          {{- end }}
          {{- if $p.Env }}
          env:
{{ include $p.Env $p | nindent 12 }}
          {{- end }}
          {{- if $p.Probes }}
{{ include $p.Probes $p | nindent 10 }}
          {{- end }}
          {{- if $p.VolumeMounts }}
          volumeMounts:
{{ include $p.VolumeMounts $p | nindent 12 }}
          {{- end }}
          {{- if $p.Resources }}
          resources:
{{ include $p.Resources $p | nindent 12 }}
          {{- else if $mv.resources }}
          resources:
{{ toYaml $mv.resources | nindent 12 }}
          {{- end }}
      {{- if $p.Volumes }}
      volumes:
{{ include $p.Volumes $p | nindent 8 }}
      {{- end }}
  {{- if $p.VolumeClaims }}
  volumeClaimTemplates:
{{ include $p.VolumeClaims $p | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}
