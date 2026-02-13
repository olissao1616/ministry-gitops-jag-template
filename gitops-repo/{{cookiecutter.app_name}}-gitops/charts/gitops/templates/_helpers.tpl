{{ "{{" }}- define "common.labels" -{{ "}}" }}
{{ "{{" }}- toYaml . | nindent 4 }}
{{ "{{" }}- end -{{ "}}" }}


{{ "{{" }}- define "chart.fullname" -{{ "}}" }}
{{ "{{" }}- printf "%s-%s" .Release.Name .Chart.Name -{{ "}}" }}
{{ "{{" }}- end -{{ "}}" }}

{{ "{{" }}/*
Common labels
*/{{ "}}" }}
{{ "{{" }}- define "gitops.labels" -{{ "}}" }}
helm.sh/chart: {{ "{{" }} .Chart.Name {{ "}}" }}-{{ "{{" }} .Chart.Version | replace "+" "_" {{ "}}" }}
{{ "{{" }} include "gitops.selectorLabels" . {{ "}}" }}
{{ "{{" }}- if .Chart.AppVersion {{ "}}" }}
app.kubernetes.io/version: {{ "{{" }} .Chart.AppVersion | quote {{ "}}" }}
{{ "{{" }}- end {{ "}}" }}
app.kubernetes.io/managed-by: {{ "{{" }} .Release.Service {{ "}}" }}
{{ "{{" }}- $global := (index .Values "global" | default dict) -{{ "}}" }}
{{ "{{" }}- $environment := (index $global "environment" | default .Values.environment) -{{ "}}" }}
{{ "{{" }}- if $environment {{ "}}" }}
environment: {{ "{{" }} $environment | quote {{ "}}" }}
{{ "{{" }}- end {{ "}}" }}
{{ "{{" }}- $owner := (index $global "owner" | default .Values.owner) -{{ "}}" }}
{{ "{{" }}- if $owner {{ "}}" }}
owner: {{ "{{" }} $owner | quote {{ "}}" }}
{{ "{{" }}- end {{ "}}" }}
{{ "{{" }}- $project := (index $global "project" | default .Values.project) -{{ "}}" }}
{{ "{{" }}- if $project {{ "}}" }}
project: {{ "{{" }} $project | quote {{ "}}" }}
{{ "{{" }}- end {{ "}}" }}
{{ "{{" }}- end {{ "}}" }}

{{ "{{" }}/*
Selector labels
*/{{ "}}" }}
{{ "{{" }}- define "gitops.selectorLabels" -{{ "}}" }}
app.kubernetes.io/instance: {{ "{{" }} .Release.Name {{ "}}" }}
{{ "{{" }}- end {{ "}}" }}