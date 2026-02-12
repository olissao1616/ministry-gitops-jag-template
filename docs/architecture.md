# Architecture

## Overview

This GitOps template uses a **layered architecture** to separate concerns and promote reusability:

```
┌─────────────────────────────────────────┐
│     Your Application Values             │
│     (dev_values.yaml, prod_values.yaml) │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│     Application Templates               │
│     (frontend-deployment.yaml, etc.)    │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│     ag-helm Shared Library              │
│     (Reusable template functions)       │
└─────────────────────────────────────────┘
```

## Components

### 1. Cookiecutter Template Layer

**Location:** `charts/{{cookiecutter.charts_dir}}/`, `deploy/{{cookiecutter.deploy_dir}}/`

This layer generates the initial repository structure using Jinja2 templating:
- Substitutes `{{cookiecutter.app_name}}` with your app name
- Substitutes `{{cookiecutter.licence_plate}}` with your license plate
- Creates environment-specific values files

**Key Point:** Cookiecutter runs ONCE to generate files. After generation, you work with standard Helm charts.

### 2. Application Template Layer

**Location:** `charts/{{cookiecutter.charts_dir}}/gitops/templates/`

Application-specific templates that define your workloads:
- `frontend-deployment.yaml` - Frontend container deployment
- `backend-deployment.yaml` - Backend API deployment
- `frontend-service.yaml` - Frontend Kubernetes service
- `backend-service.yaml` - Backend Kubernetes service
- `frontend-route.yaml` - Frontend OpenShift route
- `frontend-hpa.yaml` - Frontend horizontal pod autoscaler
- `backend-hpa.yaml` - Backend horizontal pod autoscaler

These templates call the ag-helm library functions to generate Kubernetes resources.

### 3. ag-helm Shared Library

**Location:** `shared-lib/ag-helm/`

The **ag-helm library** is a collection of reusable Helm template functions used across all BC Gov Justice applications. It provides:

- **Standard deployment patterns** - Consistent container configurations
- **Security contexts** - Default security settings
- **Network policies** - Standard networking rules
- **Resource templates** - CPU/memory configurations
- **Label management** - Standard Kubernetes labels

## ag-helm Shared Library Deep Dive

### How It Works

The ag-helm library uses Helm's `include` function to generate Kubernetes resources from configuration dictionaries.

**Example: Creating a Deployment**

In `frontend-deployment.yaml`:

```yaml
{{- if .Values.frontend.enabled }}
{{- $p := dict "Values" .Values.frontend -}}
{{- $_ := set $p "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $p "Name" (default "frontend" .Values.frontend.image.name) -}}
{{- $_ := set $p "Registry" .Values.frontend.image.repository -}}
{{- $_ := set $p "ModuleValues" (dict
  "image" (dict
    "tag" .Values.frontend.image.tag
    "pullPolicy" .Values.frontend.image.pullPolicy
  )
  "replicas" .Values.frontend.replicaCount
  "resources" .Values.frontend.resources
) -}}
{{- $_ := set $p "Ports" "frontend.ports" -}}
{{- $_ := set $p "Env" "frontend.env" -}}
{{ include "ag-template.deployment" $p }}
{{- end }}
```

**What This Does:**
1. Creates a dictionary `$p` with configuration
2. Sets `ApplicationGroup` - Used for grouping related services
3. Sets `Name` - The component name (used in image path: `registry/name:tag`)
4. Sets `Registry` - Docker registry URL
5. Sets `ModuleValues` - Container-specific config
6. Sets `Ports`, `Env` - References to custom templates
7. Calls `ag-template.deployment` to generate the Deployment

### Key ag-helm Functions

#### `ag-template.deployment`

**Location:** `shared-lib/ag-helm/templates/_deployment.tpl`

Generates a Kubernetes Deployment from a configuration dictionary.

**Required Parameters:**
- `ApplicationGroup` - Service grouping (e.g., "app")
- `Name` - Component name (e.g., "frontend", "backend", "api")
- `Registry` - Image registry (e.g., "docker.io/myorg")
- `ModuleValues.image.tag` - Image tag
- `ModuleValues.replicas` - Number of replicas
- `ModuleValues.resources` - CPU/memory limits

**Optional Parameters:**
- `Ports` - Template name for container ports
- `Env` - Template name for environment variables
- `Probes` - Template name for liveness/readiness probes
- `Volumes` - Template name for volumes
- `VolumeMounts` - Template name for volume mounts
- `SecurityContext` - Custom security context

#### `ag-template.service`

**Location:** `shared-lib/ag-helm/templates/_service.tpl`

Generates a Kubernetes Service.

**Required Parameters:**
- `ApplicationGroup` - Service grouping
- `Name` - Component name
- `ModuleValues.service.type` - Service type (ClusterIP, NodePort, LoadBalancer)
- `ModuleValues.service.port` - Service port

#### `ag-template.hpa`

**Location:** `shared-lib/ag-helm/templates/_hpa.tpl`

Generates a HorizontalPodAutoscaler.

**Required Parameters:**
- `Name` - Component name
- `ModuleValues.autoscaling.minReplicas` - Minimum pods
- `ModuleValues.autoscaling.maxReplicas` - Maximum pods
- `ModuleValues.autoscaling.targetCPUUtilizationPercentage` - CPU threshold

### Default Security Context

**Location:** `shared-lib/ag-helm/templates/_helpers.tpl`

All containers get this default security context:

```yaml
runAsNonRoot: false
allowPrivilegeEscalation: false
readOnlyRootFilesystem: false
```

**Note:** `runAsNonRoot: false` allows containers to run as root, which is required for many standard images.

## Adding a New Service Component

To add a new service (e.g., "worker", "cron-job", "api-v2"):

### Step 1: Add Values Configuration

In `values.yaml`:

```yaml
worker:
  enabled: true
  image:
    repository: docker.io/myorg
    name: my-worker
    tag: "latest"
    pullPolicy: Always
  replicaCount: 2
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 128Mi
  service:
    type: ClusterIP
    port: 8081
```

### Step 2: Create Deployment Template

Create `worker-deployment.yaml`:

```yaml
{{- define "worker.ports" }}
- name: http
  containerPort: {{ .Values.service.port }}
  protocol: TCP
{{- end }}

{{- define "worker.env" }}
- name: WORKER_MODE
  value: "background"
{{- end }}

{{- if .Values.worker.enabled }}
{{- $p := dict "Values" .Values.worker -}}
{{- $_ := set $p "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $p "Name" (default "worker" .Values.worker.image.name) -}}
{{- $_ := set $p "Registry" .Values.worker.image.repository -}}
{{- $_ := set $p "ModuleValues" (dict
  "image" (dict
    "tag" .Values.worker.image.tag
    "pullPolicy" .Values.worker.image.pullPolicy
  )
  "replicas" .Values.worker.replicaCount
  "resources" .Values.worker.resources
) -}}
{{- $_ := set $p "Ports" "worker.ports" -}}
{{- $_ := set $p "Env" "worker.env" -}}
{{ include "ag-template.deployment" $p }}
{{- end }}
```

### Step 3: Create Service Template

Create `worker-service.yaml`:

```yaml
{{- if .Values.worker.enabled }}
{{- $p := dict "Values" .Values.worker -}}
{{- $_ := set $p "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $p "Name" "worker" -}}
{{- $_ := set $p "ModuleValues" (dict
  "service" .Values.worker.service
) -}}
{{ include "ag-template.service" $p }}
{{- end }}
```

### Step 4: (Optional) Add HPA

Create `worker-hpa.yaml`:

```yaml
{{- if and .Values.worker.enabled .Values.worker.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ printf "%s-worker" .Release.Name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ printf "%s-worker" .Release.Name }}
  minReplicas: {{ .Values.worker.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.worker.autoscaling.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.worker.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```

### Step 5: Deploy

```bash
helm upgrade myapp . --values values.yaml
```

## Image Path Construction

The ag-helm library constructs image paths as:

```
${Registry}/${Name}:${Tag}
```

**Example:**
- Registry: `docker.io/myorg`
- Name: `my-frontend`
- Tag: `v1.0.0`
- **Result:** `docker.io/myorg/my-frontend:v1.0.0`

**Important:** Make sure your `image.name` matches your actual Docker image name in the registry.

## Environment-Specific Configuration

Use different values files for each environment:

```bash
# Development
helm install myapp . --values dev_values.yaml

# Test
helm install myapp . --values test_values.yaml

# Production
helm install myapp . --values prod_values.yaml
```

Each values file can override:
- Image tags (dev vs prod versions)
- Replica counts
- Resource limits
- Environment variables
- Hostnames/routes

## Next Steps

- Read [Template Structure](template-structure.md) for file organization
- Read [Configuration Guide](configuration-guide.md) for all configuration options
- See [Examples](examples/adding-new-component.md) for adding components
