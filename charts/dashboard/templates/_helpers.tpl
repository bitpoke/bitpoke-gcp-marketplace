{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "dashboard.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dashboard.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dashboard.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the apiserver service account to use
*/}}
{{- define "dashboard.apiserver.serviceAccountName" -}}
{{- if .Values.apiserver.serviceAccount.create -}}
    {{ default (printf "%s-apiserver" (include "dashboard.fullname" .)) .Values.apiserver.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.apiserver.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the controller service account to use
*/}}
{{- define "dashboard.controller.serviceAccountName" -}}
{{- if .Values.controller.serviceAccount.create -}}
    {{ default (printf "%s-controller" (include "dashboard.fullname" .)) .Values.controller.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.controller.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the webhook secret to use
*/}}
{{- define "dashboard.webhook.secretName" -}}
{{ default (printf "%s-webhook" (include "dashboard.fullname" .)) .Values.webhook.secretName }}
{{- end -}}

{{/*
Create the name of the webhook service to use
*/}}
{{- define "dashboard.webhook.serviceName" -}}
{{ default (printf "%s-webhook" (include "dashboard.fullname" .)) .Values.webhook.service.name }}
{{- end -}}

{{/*
Create the path of the webhook certificates directory
*/}}
{{- define "dashboard.webhook.certDir" -}}
{{ default (printf "/tmp/%s-webhook-cert-dir" (include "dashboard.fullname" .)) .Values.webhook.certDir }}
{{- end -}}
