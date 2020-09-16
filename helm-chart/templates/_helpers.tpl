{{/*
Expand the name of the chart.
*/}}
{{- define "microservice-generic.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "microservice-generic.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "microservice-generic.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservice-generic.labels" -}}
helm.sh/chart: {{ include "microservice-generic.chart" . }}
{{ include "microservice-generic.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "microservice-generic.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice-generic.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "microservice-generic.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "microservice-generic.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Pod annotations
*/}}
{{- define "microservice-generic.podAnnotations" -}}
{{- if or .Values.podAnnotations .Values.vault.enabled }}
{{- if .Values.podAnnotations }}
{{- toYaml .Values.podAnnotations }}
{{- end }}
{{- if and .Values.podAnnotations .Values.vault.enabled }}
{{ end }}
{{- if .Values.vault.enabled -}}
vault.hashicorp.com/agent-inject: {{ default true .Values.vault.inject | quote }}
vault.hashicorp.com/agent-inject-status: "update"
vault.hashicorp.com/agent-configmap: {{ include "microservice-generic.fullname" . }}-vault-agent
{{- end }}
{{- else -}}
{}
{{- end }}
{{- end }}

{{/*
Create the name of the Vault role to use
*/}}
{{- define "microservice-generic.vaultRole" -}}
{{- default (include "microservice-generic.fullname" .) .Values.vault.role }}
{{- end }}

{{/*
Create the Vault secret path to use
*/}}
{{- define "microservice-generic.vaultSecretPath" -}}
{{- default (printf "secret/%s" (include "microservice-generic.fullname" .)) .Values.vault.secretPath }}
{{- end }}

{{/*
Vault agent config
*/}}
{{- define "microservice-generic.vaultAgentConfig" }}
exit_after_auth = {{ ternary true false .configInit }}
pid_file = "/home/vault/pidfile"
auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "{{ include "microservice-generic.vaultRole" . }}"
    }
  }
  sink "file" {
    config = {
      path = "/home/vault/.vault-token"
    }
  }
}
vault {
  address = "{{ .Values.vault.address }}"
}
{{- if eq .Values.vaultAgent.config.templateType "quarkus" }}
template {
    contents = <<EOF
        quarkus.vault.url={{ .Values.vault.address }}
        quarkus.vault.authentication.kubernetes.role={{ include "microservice-generic.vaultRole" . }}

        {{- range .Values.dataSources.databases }}
        quarkus.vault.credentials-provider.{{ .engine }}-{{ .name }}.credentials-mount={{ .engine }}
        quarkus.vault.credentials-provider.{{ .engine }}-{{ .name }}.credentials-role={{ .name }}-database-creds-reader
        quarkus.datasource.{{ .engine }}-{{ .name }}.db-kind={{ .engine }}
        quarkus.datasource.{{ .engine }}-{{ .name }}.credentials-provider={{ .engine }}-{{ .name }}
        quarkus.datasource.{{ .engine }}-{{ .name }}.jdbc.url=jdbc:{{ .engine }}://{{ .host }}:{{ .port }}/{{ .name }}?sslmode=disable
        {{- end }}
    EOF
    destination = "/vault/secrets/application.properties"
}
{{- else }}
  {{- range .Values.dataSources.databases }}
template {
  contents = "{{`{{- with secret \"`}}{{ .engine }}/creds/{{ .name }}-database-creds-reader\"{{` -}}`}}{{ .engine }}://{{`{{ .Data.username }}:{{ .Data.password }}@`}}{{ .host }}:{{ .port }}/{{ .name }}?sslmode=disable{{`{{- end }}`}}"
  destination = "/vault/secrets/database-creds.{{ .engine }}-{{ .name }}"
}
  {{- end }}
{{- end }}
{{- end }}
