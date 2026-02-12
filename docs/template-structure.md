# Template Structure

## Repository Layout

```
ministry-gitops-jag-template-main/
├── charts/                          # Cookiecutter template for Helm charts
│   ├── cookiecutter.json           # Chart generation config
│   └── {{cookiecutter.charts_dir}}/
│       └── gitops/
│           ├── Chart.yaml          # Helm chart metadata
│           ├── values.yaml         # Default values
│           └── templates/          # Kubernetes manifests
│
├── deploy/                          # Cookiecutter template for deploy configs
│   ├── cookiecutter.json           # Deploy generation config
│   └── {{cookiecutter.deploy_dir}}/
│       ├── dev_values.yaml         # Development environment
│       ├── test_values.yaml        # Test environment
│       └── prod_values.yaml        # Production environment
│
├── shared-lib/                      # Shared Helm libraries
│   └── ag-helm/                    # ag-helm shared library
│       ├── Chart.yaml
│       └── templates/
│           ├── _deployment.tpl     # Deployment template functions
│           ├── _service.tpl        # Service template functions
│           ├── _helpers.tpl        # Helper functions
│           └── ...
│
├── scripts/                         # Utility scripts
│   ├── test-complete-deployment.sh # End-to-end test
│   └── test-unified-gitops-chart.sh # Component tests
│
├── docs/                            # Documentation
│   ├── getting-started.md
│   ├── architecture.md
│   └── ...
│
└── README.md
```

## Chart Template Directory

### `charts/cookiecutter.json`

Defines cookiecutter variables for chart generation:

```json
{
  "app_name": "myapp",
  "licence_plate": "abc123",
  "charts_dir": "{{ cookiecutter.app_name }}-charts"
}
```

### `charts/{{cookiecutter.charts_dir}}/gitops/Chart.yaml`

Helm chart metadata with cookiecutter placeholders:

```yaml
apiVersion: v2
name: {{ cookiecutter.app_name }}-gitops
description: GitOps deployment chart for {{ cookiecutter.app_name }}
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: ag-helm-templates
    version: 1.0.3
    repository: file://../../../shared-lib/ag-helm
```

**Key Points:**
- Uses cookiecutter variables for dynamic naming
- Declares dependency on ag-helm shared library
- File path dependency assumes specific directory structure

### `charts/{{cookiecutter.charts_dir}}/gitops/values.yaml`

Default values for the chart:

```yaml
my_app_name: "{{ cookiecutter.app_name }}"

project: "{{ cookiecutter.app_name }}"
environment: dev

frontend:
  enabled: false
  image:
    repository: docker.io/bcgov
    name: react-app
    tag: "latest"
  ...

backend:
  enabled: false
  ...

postgresql:
  enabled: false
  ...
```

**Key Points:**
- All components disabled by default
- Values are overridden by environment-specific files
- Provides sensible defaults for resources, ports, etc.

### `charts/{{cookiecutter.charts_dir}}/gitops/templates/`

Kubernetes manifest templates using Helm + cookiecutter syntax.

## Template Files

### Frontend Templates

#### `frontend-deployment.yaml`

Generates a Kubernetes Deployment for the frontend:

```yaml
{% raw %}{{- define "frontend.ports" }}
- name: http
  containerPort: {{ .Values.service.port }}
  protocol: TCP
{{- end }}

{{- define "frontend.env" }}
{{- if .Values.keycloak }}
- name: VITE_DIAM_AUTH_URL
  value: {{ .Values.keycloak.authUrl }}
...
{{- end }}
{{- end }}

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
{% endraw %}
```

**Important Syntax:**
- `{% raw %}` / `{% endraw %}` - Cookiecutter raw blocks to preserve Helm syntax
- `{{- if .Values.frontend.enabled }}` - Helm conditional
- `{{- define "..." }}` - Helm template definition
- `{{ include "ag-template.deployment" $p }}` - Call ag-helm function

#### `frontend-service.yaml`

Generates a Kubernetes Service:

```yaml
{% raw %}{{- if .Values.frontend.enabled }}
{{- $p := dict "Values" .Values.frontend -}}
{{- $_ := set $p "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $p "Name" "frontend" -}}
{{- $_ := set $p "ModuleValues" (dict
  "service" .Values.frontend.service
) -}}
{{ include "ag-template.service" $p }}
{{- end }}
{% endraw %}
```

#### `frontend-route.yaml`

Generates an OpenShift Route:

```yaml
{% raw %}{{ "{{" }}- if and .Values.frontend.enabled .Values.frontend.route.enabled {{ "}}" }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: {{ "{{" }} printf "%s-frontend" .Release.Name {{ "}}" }}
  labels:
    {{ "{{" }}- include "gitops.labels" . | nindent 4 {{ "}}" }}
spec:
  host: {{ "{{" }} .Values.frontend.route.host {{ "}}" }}
  to:
    kind: Service
    name: {{ "{{" }} printf "%s-frontend" .Release.Name {{ "}}" }}
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
{{ "{{" }}- end {{ "}}" }}
{% endraw %}
```

**Syntax Note:**
- `{{ "{{" }}` - Escaped Helm syntax (cookiecutter outputs `{{`)
- `{{ "}}" }}` - Escaped closing brace (outputs `}}`)
- Required because cookiecutter also uses `{{` `}}` syntax

#### `frontend-hpa.yaml`

Generates a HorizontalPodAutoscaler:

```yaml
{% raw %}{{ "{{" }}- if and .Values.frontend.enabled .Values.frontend.autoscaling.enabled {{ "}}" }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ "{{" }} printf "%s-frontend" .Release.Name {{ "}}" }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ "{{" }} printf "%s-frontend" .Release.Name {{ "}}" }}
  minReplicas: {{ "{{" }} .Values.frontend.autoscaling.minReplicas {{ "}}" }}
  maxReplicas: {{ "{{" }} .Values.frontend.autoscaling.maxReplicas {{ "}}" }}
  metrics:
    {{ "{{" }}- if .Values.frontend.autoscaling.targetCPUUtilizationPercentage {{ "}}" }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ "{{" }} .Values.frontend.autoscaling.targetCPUUtilizationPercentage {{ "}}" }}
    {{ "{{" }}- end {{ "}}" }}
{{ "{{" }}- end {{ "}}" }}
{% endraw %}
```

### Backend Templates

Backend templates follow the same structure:
- `backend-deployment.yaml`
- `backend-service.yaml`
- `backend-hpa.yaml`

With backend-specific environment variables for database and Keycloak.

### Additional Templates

- `frontend-serviceaccount.yaml` - Service account for frontend
- `backend-serviceaccount.yaml` - Service account for backend
- `frontend-networkpolicy.yaml` - Network policy for frontend
- `backend-networkpolicy.yaml` - Network policy for backend
- `_helpers.tpl` - Shared helper templates

## Deploy Template Directory

### `deploy/cookiecutter.json`

```json
{
  "app_name": "myapp",
  "licence_plate": "abc123",
  "deploy_dir": "{{ cookiecutter.app_name }}-deploy",
  "team_name": "myteam",
  "project_name": "{{ cookiecutter.app_name }}"
}
```

### Environment Values Files

#### `dev_values.yaml`

Development environment configuration:

```yaml
postgresql:
  enabled: true  # Local database for dev

frontend:
  enabled: true
  environment: dev
  image:
    repository: docker.io/myorg
    name: my-frontend
    tag: latest
  ...

backend:
  enabled: true
  ...
```

#### `test_values.yaml`

Test environment configuration:
- May use shared test database
- More realistic resource limits
- Test-specific hostnames

#### `prod_values.yaml`

Production environment configuration:
- Specific image versions (not `latest`)
- Higher replica counts
- Autoscaling enabled
- Production hostnames
- Managed database (postgresql.enabled: false)

## ag-helm Shared Library

### `shared-lib/ag-helm/Chart.yaml`

```yaml
apiVersion: v2
name: ag-helm-templates
description: Shared Helm templates for BC Gov Justice applications
type: library
version: 1.0.3
```

### `shared-lib/ag-helm/templates/_deployment.tpl`

Contains `ag-template.deployment` function that generates Deployments.

**Key Features:**
- Standardized labels and annotations
- Security contexts
- Resource limits
- Health probes
- Volume mounts
- Environment variables

### `shared-lib/ag-helm/templates/_service.tpl`

Contains `ag-template.service` function that generates Services.

### `shared-lib/ag-helm/templates/_helpers.tpl`

Helper functions:
- `ag-template.defaultSecurityContext` - Default container security settings
- Label generators
- Name generators

## Cookiecutter vs Helm

### Cookiecutter Processing (One-Time)

**Input:** Template with `{{cookiecutter.variable}}`

**Output:** Files with `{{cookiecutter.variable}}` replaced

**Example:**
```yaml
# Template
name: {{cookiecutter.app_name}}-frontend

# After cookiecutter
name: myapp-frontend
```

### Helm Processing (Every Deployment)

**Input:** Chart with `{{ .Values.variable }}`

**Output:** Kubernetes manifests with values substituted

**Example:**
```yaml
# Template
image: {{ .Values.frontend.image.repository }}/{{ .Values.frontend.image.name }}:{{ .Values.frontend.image.tag }}

# After helm
image: docker.io/myorg/my-frontend:v1.2.3
```

### Combined Syntax

Templates can use both:

```yaml
# Cookiecutter + Helm
name: {{cookiecutter.app_name}}-{{ .Values.environment }}

# After cookiecutter
name: myapp-{{ .Values.environment }}

# After helm (with values.yaml: environment: dev)
name: myapp-dev
```

### Escaped Helm in Cookiecutter Templates

When you need Helm syntax in a cookiecutter template:

```yaml
# In template file
{{ "{{" }} .Values.frontend.enabled {{ "}}" }}

# After cookiecutter (generates valid Helm syntax)
{{ .Values.frontend.enabled }}
```

## Generated File Structure

After running cookiecutter, you get:

```
output/
├── myapp-charts/
│   └── gitops/
│       ├── Chart.yaml          # No more cookiecutter syntax
│       ├── values.yaml         # No more cookiecutter syntax
│       └── templates/
│           ├── frontend-deployment.yaml
│           └── ...
│
└── myapp-deploy/
    ├── dev_values.yaml
    ├── test_values.yaml
    └── prod_values.yaml
```

All cookiecutter variables are replaced with actual values.

## Next Steps

- Read [Architecture](architecture.md) to understand how components interact
- Read [Configuration Guide](configuration-guide.md) for all values
- See [Examples](examples/) for common use cases
