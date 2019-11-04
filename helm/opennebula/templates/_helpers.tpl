{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "opennebula.name" -}}
{{- default "opennebula" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "opennebula.fullname" -}}
{{- $name := default "opennebula" .Values.nameOverride -}}
{{- if eq .Release.Name "release-name" -}}
{{- $name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Print OpenNebula-style config
*/}}
{{- define "opennebula.config" -}}
  {{- range $key, $value := . }}
    {{- if eq (printf "%T" $value) "[]interface {}" }}
      {{- range $keyz, $valuez := $value }}
        {{- template "opennebula.configItem" dict "key" $key "value" $valuez }}
      {{- end }}
    {{- else }}
      {{- template "opennebula.configItem" dict "key" $key "value" $value }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Print OpenNebula-style config item
*/}}
{{- define "opennebula.configItem" -}}
  {{- if eq (printf "%T" .value) "bool" }}
    {{- .key | nindent 0 }}  = {{ .value | ternary "YES" "NO" }}
  {{- else if eq (printf "%T" .value) "float64" }}
    {{- .key | nindent 0 }} = {{ .value }}
  {{- else if eq (printf "%T" .value) "string" }}
    {{- .key | nindent 0 }} = "{{ .value }}"
  {{- else if eq (printf "%T" .value) "map[string]interface {}" }}
    {{- .key | nindent 0 }} = [
    {{- $local := dict "first" true -}}
    {{- range $key, $value := .value }}
      {{- if not $local.first -}},{{- end -}}
      {{- if eq (printf "%T" $value) "bool" }}
        {{- $key | nindent 2 }} = {{ $value | ternary "YES" "NO" }}
      {{- else if eq (printf "%T" $value) "float64" }}
        {{- $key | nindent 2 }} = {{ $value }}
      {{- else if or (eq (printf "%T" $value) "string") (eq (printf "%T" $value) "<nil>") }}
        {{- $key | nindent 2 }} = "{{ $value }}"
      {{- end }}
    {{- $_ := set $local "first" false -}}
    {{- end }}
    {{- "]" | nindent 0 }}
  {{- end }}
{{- end }}
