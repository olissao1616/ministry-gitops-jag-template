# Repository Structure and Naming Standards

## Overview

When you generate a GitOps repository from this template, it creates a standardized folder structure following BC Government Justice naming conventions.

## Naming Conventions

### License Plate

Your **license plate** is a 6-character identifier assigned by the platform team:
- Format: `abc123`, `xyz789`, etc.
- Used in: namespaces, hostnames, resource names
- **Example:** `e27db1`

### Application Name

Your application name should be:
- Lowercase
- Hyphen-separated words
- Descriptive and unique within your team
- **Examples:** `myapp`, `court-case-api`, `citizen-portal`

### Environment Names

Standard environments:
- `dev` - Development
- `test` - Testing/QA
- `prod` - Production

## Generated Repository Structure

After running cookiecutter with:
```bash
app_name=myapp
licence_plate=abc123
```

You get:

```
myapp-gitops/                           # Your Git repository root
├── README.md                           # Project documentation
├── .gitignore                          # Git ignore rules
│
├── charts/                             # Helm charts directory
│   └── myapp-charts/                   # Chart folder: {app_name}-charts
│       └── gitops/                     # Main chart name
│           ├── Chart.yaml              # Helm chart metadata
│           ├── values.yaml             # Default values
│           ├── charts/                 # Dependencies (downloaded by helm)
│           │   ├── postgresql-14.1.1.tgz
│           │   └── ...
│           └── templates/              # Kubernetes manifests
│               ├── frontend-deployment.yaml
│               ├── frontend-service.yaml
│               ├── frontend-route.yaml
│               ├── frontend-hpa.yaml
│               ├── backend-deployment.yaml
│               ├── backend-service.yaml
│               ├── backend-hpa.yaml
│               └── ...
│
├── deploy/                             # Deployment configurations
│   └── myapp-deploy/                   # Deploy folder: {app_name}-deploy
│       ├── dev_values.yaml             # Development environment
│       ├── test_values.yaml            # Test environment
│       └── prod_values.yaml            # Production environment
│
├── application/                        # Application source code (optional)
│   ├── frontend/                       # Frontend code
│   └── backend/                        # Backend code
│
└── .github/                            # GitHub Actions (optional)
    └── workflows/
        ├── deploy-dev.yaml
        ├── deploy-test.yaml
        └── deploy-prod.yaml
```

## Folder Naming Standards

### Charts Folder: `charts/{app_name}-charts/`

**Pattern:** `{app_name}-charts`

**Examples:**
- `myapp` → `charts/myapp-charts/`
- `court-api` → `charts/court-api-charts/`
- `citizen-portal` → `charts/citizen-portal-charts/`

### Deploy Folder: `deploy/{app_name}-deploy/`

**Pattern:** `{app_name}-deploy`

**Examples:**
- `myapp` → `deploy/myapp-deploy/`
- `court-api` → `deploy/court-api-deploy/`
- `citizen-portal` → `deploy/citizen-portal-deploy/`

### Chart Name: `gitops`

The actual Helm chart is always named `gitops`:
- `charts/{app_name}-charts/gitops/`

This is standard across all Justice applications.

## Kubernetes Resource Naming

### Namespaces

**Pattern:** `{licence_plate}-{environment}`

**Examples:**
- Dev: `abc123-dev`
- Test: `abc123-test`
- Prod: `abc123-prod`

### Deployments

**Pattern:** `{component}`

The Helm release name + component name forms the deployment name.

**Examples with release name "myapp":**
- Frontend: `myapp-frontend`
- Backend: `myapp-backend`
- PostgreSQL: `myapp-postgresql`

**In generated manifests:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-frontend    # {release-name}-{component}
  namespace: abc123-dev   # {licence_plate}-{environment}
```

### Services

**Pattern:** Same as deployments

**Examples:**
- `myapp-frontend`
- `myapp-backend`
- `myapp-postgresql`
- `myapp-postgresql-hl` (headless service)

### Routes (OpenShift)

**Pattern:** `{app}-{licence_plate}-{environment}.apps.{cluster}.devops.gov.bc.ca`

**Examples:**
- Dev: `myapp-abc123-dev.apps.emerald.devops.gov.bc.ca`
- Test: `myapp-abc123-test.apps.silver.devops.gov.bc.ca`
- Prod: `myapp-abc123-prod.apps.gold.devops.gov.bc.ca`

### HPAs (Horizontal Pod Autoscalers)

**Pattern:** `{release-name}-{component}`

**Examples:**
- `myapp-frontend`
- `myapp-backend`

### Service Accounts

**Pattern:** `{release-name}-{component}`

**Examples:**
- `myapp-frontend`
- `myapp-backend`

## Helm Chart Metadata

### Chart.yaml

```yaml
apiVersion: v2
name: myapp-gitops                      # {app_name}-gitops
description: GitOps deployment chart for myapp
type: application
version: 0.1.0
appVersion: "1.0.0"
```

**Chart Name Pattern:** `{app_name}-gitops`

### Release Name

When deploying with Helm:

```bash
helm install myapp ./charts/myapp-charts/gitops
#            ^^^^^
#            Release name (typically same as app name)
```

The release name is used as a prefix for all resources.

## Values File Naming

### Standard Names

- `values.yaml` - Default values (in chart)
- `dev_values.yaml` - Development environment
- `test_values.yaml` - Test environment
- `prod_values.yaml` - Production environment

### Custom Environment Names

You can create additional values files:
- `dev_values.yaml` - Standard dev
- `dev2_values.yaml` - Second dev environment
- `uat_values.yaml` - User acceptance testing
- `staging_values.yaml` - Staging environment

## Label Standards

All resources include standard labels:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: frontend              # Component name
    app.kubernetes.io/instance: myapp             # Release name
    app.kubernetes.io/part-of: myapp              # Application group
    app.kubernetes.io/managed-by: Helm
    environment: dev                              # Environment
    owner: myteam                                 # Team name
    project: myproject                            # Project name
    DataClass: Medium                             # Data classification
```

## Example: Complete Resource Names

For application `court-case-api` with license plate `xyz789` in dev:

### Namespace
```
xyz789-dev
```

### Helm Release
```
court-case-api
```

### Deployments
```
court-case-api-frontend
court-case-api-backend
court-case-api-postgresql
```

### Services
```
court-case-api-frontend
court-case-api-backend
court-case-api-postgresql
court-case-api-postgresql-hl
```

### Route
```
court-case-api-xyz789-dev.apps.emerald.devops.gov.bc.ca
```

### Full Resource Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: court-case-api-frontend
  namespace: xyz789-dev
  labels:
    app.kubernetes.io/name: frontend
    app.kubernetes.io/instance: court-case-api
    app.kubernetes.io/part-of: court-case-api
    environment: dev
```

## File Path Examples

### Scenario 1: Simple App

```
my-simple-app-gitops/
├── charts/
│   └── my-simple-app-charts/
│       └── gitops/
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/
└── deploy/
    └── my-simple-app-deploy/
        ├── dev_values.yaml
        └── prod_values.yaml
```

### Scenario 2: Multi-Service App

```
court-system-gitops/
├── charts/
│   └── court-system-charts/
│       └── gitops/
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/
│               ├── frontend-deployment.yaml
│               ├── api-deployment.yaml
│               ├── worker-deployment.yaml
│               └── ...
└── deploy/
    └── court-system-deploy/
        ├── dev_values.yaml
        ├── test_values.yaml
        └── prod_values.yaml
```

## Directory Structure Best Practices

### Keep Application Code Separate (Optional)

```
myapp-gitops/
├── charts/              # Helm charts (infrastructure as code)
├── deploy/              # Environment configurations
└── application/         # Application source code (optional)
    ├── frontend/
    │   ├── src/
    │   ├── Dockerfile
    │   └── package.json
    └── backend/
        ├── src/
        ├── Dockerfile
        └── *.csproj
```

Or maintain separate repositories:
- `myapp-frontend` - Frontend code
- `myapp-backend` - Backend code
- `myapp-gitops` - GitOps manifests

### Git Repository Structure

Recommended Git repository organization:

**Option 1: Monorepo**
```
myapp/
├── .git/
├── frontend/            # Frontend source
├── backend/             # Backend source
├── charts/              # Helm charts
└── deploy/              # Deployment configs
```

**Option 2: Separate Repos (Recommended)**
```
myapp-frontend/          # Frontend repo
myapp-backend/           # Backend repo
myapp-gitops/            # GitOps repo (generated from template)
```

## Customizing Naming Conventions

If you need different naming conventions, modify the cookiecutter templates:

### Chart Name

Edit `charts/{{cookiecutter.charts_dir}}/Chart.yaml`:
```yaml
name: {{ cookiecutter.app_name }}-custom-suffix
```

### Folder Names

Edit `charts/cookiecutter.json`:
```json
{
  "charts_dir": "{{ cookiecutter.app_name }}-my-custom-charts"
}
```

## Validation

To validate your structure matches standards:

```bash
# Check folder names
ls -la charts/
ls -la deploy/

# Check chart metadata
cat charts/*/gitops/Chart.yaml

# Verify resource names
helm template myapp ./charts/myapp-charts/gitops \
  --values ./deploy/dev_values.yaml \
  | grep "name:"
```

## Next Steps

- Read [Getting Started](getting-started.md) for generation instructions
- Read [Architecture](architecture.md) to understand the structure
- See [Examples](examples/) for real-world structures
