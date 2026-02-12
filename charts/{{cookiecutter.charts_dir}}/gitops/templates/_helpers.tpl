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
{{ "{{" }}- end {{ "}}" }}

{{ "{{" }}/*
Selector labels
*/{{ "}}" }}
{{ "{{" }}- define "gitops.selectorLabels" -{{ "}}" }}
app.kubernetes.io/instance: {{ "{{" }} .Release.Name {{ "}}" }}
{{ "{{" }}- end {{ "}}" }}