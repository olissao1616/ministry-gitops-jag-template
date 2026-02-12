{{/* Common helper templates for annotations, labels, env, ports, volumes, etc. */}}

{{- define "ag-template.mergeMaps" -}}
{{- /* Merges two maps: a (base) and b (overrides). b wins on conflicts. */ -}}
{{- $a := index . 0 | default dict -}}
{{- $b := index . 1 | default dict -}}
{{- $out := deepCopy $a -}}
{{- range $k, $v := $b -}}
{{- $_ := set $out $k $v -}}
{{- end -}}
{{- $out -}}
{{- end -}}

{{- define "ag-template.renderNamedTemplate" -}}
{{- /* Renders a template by name with given dict if name provided, else outputs nothing */ -}}
{{- $name := index . 0 -}}
{{- $ctx := index . 1 | default dict -}}
{{- if $name }}
{{- include $name $ctx -}}
{{- end -}}
{{- end -}}

{{- define "ag-template.defaultSecurityContext" -}}
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
{{- end -}}

{{- define "ag-template.defaultPodSecurityContext" -}}
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "ag-template.commonLabels" -}}
{{- $vals := .Values | default . -}}
{{- if $vals.commonLabels }}
{{ toYaml $vals.commonLabels }}
{{- end }}
{{- end -}}

{{/* Resolve and validate dataClass from dict: prefer ModuleValues.dataClass, then .DataClass. Fallback: low. Allowed: low|medium|high */}}
{{- define "ag-template.getDataClass" -}}
{{- $p := . -}}
{{- $mv := default (dict) $p.ModuleValues -}}
{{- $raw := default (default "" $p.DataClass) $mv.dataClass -}}
{{- $dc := default "low" $raw -}}
{{- if or (eq $dc "low") (eq $dc "medium") (eq $dc "high") -}}
{{- $dc -}}
{{- else -}}
{{- fail (printf "invalid dataClass '%s' (allowed: low|medium|high)" $dc) -}}
{{- end -}}
{{- end -}}

{{- define "ag-template.dataClassLabel" -}}
data-class: {{ include "ag-template.getDataClass" . | quote }}
{{- end -}}
