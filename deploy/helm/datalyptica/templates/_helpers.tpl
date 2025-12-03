{{/*
Expand the name of the chart.
*/}}
{{- define "datalyptica.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "datalyptica.fullname" -}}
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
{{- define "datalyptica.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "datalyptica.labels" -}}
helm.sh/chart: {{ include "datalyptica.chart" . }}
{{ include "datalyptica.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
platform: datalyptica
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "datalyptica.selectorLabels" -}}
app.kubernetes.io/name: {{ include "datalyptica.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-specific labels
*/}}
{{- define "datalyptica.componentLabels" -}}
{{- $component := .component }}
{{- $tier := .tier }}
{{ include "datalyptica.labels" .root }}
app: {{ $component }}
{{- if $tier }}
tier: {{ $tier }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "datalyptica.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "datalyptica.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate image name with registry
*/}}
{{- define "datalyptica.image" -}}
{{- $registry := .registry | default .root.Values.global.imageRegistry -}}
{{- $repository := .repository -}}
{{- $tag := .tag | default "latest" -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Generate PostgreSQL connection string
*/}}
{{- define "datalyptica.postgresql.connectionString" -}}
{{- $host := printf "postgresql.%s.svc.cluster.local" .Values.namespaces.core -}}
{{- $port := "5432" -}}
{{- $database := .database | default "datalyptica" -}}
{{- $username := .username | default "postgres" -}}
{{- printf "postgresql+psycopg2://%s:$(POSTGRES_PASSWORD)@%s:%s/%s" $username $host $port $database }}
{{- end }}

{{/*
Generate Redis connection string
*/}}
{{- define "datalyptica.redis.connectionString" -}}
{{- $host := printf "redis.%s.svc.cluster.local" .Values.namespaces.core -}}
{{- $port := "6379" -}}
{{- $db := .db | default "0" -}}
{{- printf "redis://:$(REDIS_PASSWORD)@%s:%s/%s" $host $port $db }}
{{- end }}

{{/*
Generate MinIO endpoint
*/}}
{{- define "datalyptica.minio.endpoint" -}}
{{- printf "http://minio.%s.svc.cluster.local:9000" .Values.namespaces.core }}
{{- end }}

{{/*
Generate Nessie API endpoint
*/}}
{{- define "datalyptica.nessie.endpoint" -}}
{{- printf "http://nessie.%s.svc.cluster.local:19120/api/v2" .Values.namespaces.core }}
{{- end }}

{{/*
Generate Kafka bootstrap servers
*/}}
{{- define "datalyptica.kafka.bootstrapServers" -}}
{{- printf "kafka.%s.svc.cluster.local:9092" .Values.namespaces.apps }}
{{- end }}

{{/*
Generate Spark master URL
*/}}
{{- define "datalyptica.spark.masterUrl" -}}
{{- printf "spark://spark-master.%s.svc.cluster.local:7077" .Values.namespaces.apps }}
{{- end }}

{{/*
Generate random password if not provided
*/}}
{{- define "datalyptica.password" -}}
{{- if .password }}
{{- .password }}
{{- else }}
{{- randAlphaNum 32 }}
{{- end }}
{{- end }}

{{/*
Generate Airflow environment variables
*/}}
{{- define "datalyptica.airflow.env" -}}
- name: AIRFLOW__CORE__EXECUTOR
  value: "CeleryExecutor"
- name: AIRFLOW__CORE__SQL_ALCHEMY_CONN
  value: "postgresql+psycopg2://airflow:{{ include "datalyptica.password" (dict "key" "airflow-password" "root" .) }}@postgresql.{{ .Values.namespaces.core }}.svc.cluster.local:5432/airflow"
- name: AIRFLOW__CELERY__BROKER_URL
  value: "redis://:{{ include "datalyptica.password" (dict "key" "redis-password" "root" .) }}@redis.{{ .Values.namespaces.core }}.svc.cluster.local:6379/0"
- name: AIRFLOW__CELERY__RESULT_BACKEND
  value: "db+postgresql://airflow:{{ include "datalyptica.password" (dict "key" "airflow-password" "root" .) }}@postgresql.{{ .Values.namespaces.core }}.svc.cluster.local:5432/airflow"
- name: AIRFLOW__CORE__FERNET_KEY
  valueFrom:
    secretKeyRef:
      name: airflow-credentials
      key: secret-key
- name: AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION
  value: "true"
- name: AIRFLOW__CORE__LOAD_EXAMPLES
  value: "false"
- name: AIRFLOW__WEBSERVER__EXPOSE_CONFIG
  value: "true"
- name: AIRFLOW__WEBSERVER__RBAC
  value: "true"
- name: AIRFLOW__WEBSERVER__WEB_SERVER_PORT
  value: "8082"
{{- end }}

{{/*
Generate Superset environment variables
*/}}
{{- define "datalyptica.superset.env" -}}
- name: SUPERSET_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: superset-credentials
      key: secret-key
- name: DATABASE_DIALECT
  value: "postgresql"
- name: DATABASE_HOST
  value: "postgresql.{{ .Values.namespaces.core }}.svc.cluster.local"
- name: DATABASE_PORT
  value: "5432"
- name: DATABASE_DB
  value: "superset"
- name: DATABASE_USER
  value: "superset"
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgresql-credentials
      key: superset-password
- name: REDIS_HOST
  value: "redis.{{ .Values.namespaces.core }}.svc.cluster.local"
- name: REDIS_PORT
  value: "6379"
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: redis-credentials
      key: password
- name: SUPERSET_LOAD_EXAMPLES
  value: "no"
{{- end }}

{{/*
Resource limits
*/}}
{{- define "datalyptica.resources" -}}
{{- if .resources }}
resources:
  {{- if .resources.requests }}
  requests:
    memory: {{ .resources.requests.memory | quote }}
    cpu: {{ .resources.requests.cpu | quote }}
  {{- end }}
  {{- if .resources.limits }}
  limits:
    memory: {{ .resources.limits.memory | quote }}
    cpu: {{ .resources.limits.cpu | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Security context
*/}}
{{- define "datalyptica.securityContext" -}}
{{- if .securityContext }}
securityContext:
  runAsNonRoot: {{ .securityContext.runAsNonRoot | default true }}
  {{- if .securityContext.runAsUser }}
  runAsUser: {{ .securityContext.runAsUser }}
  {{- end }}
  {{- if .securityContext.fsGroup }}
  fsGroup: {{ .securityContext.fsGroup }}
  {{- end }}
  {{- if .securityContext.capabilities }}
  capabilities:
    {{- toYaml .securityContext.capabilities | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
