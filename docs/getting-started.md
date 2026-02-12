# Getting Started

## Purpose

This repository is a **cookiecutter template** for creating BC Government GitOps repositories. It generates a complete Helm chart structure with support for:
- Frontend applications (React/Next.js)
- Backend APIs (.NET Core)
- PostgreSQL databases
- Horizontal Pod Autoscaling (HPA)
- OpenShift Routes
- Network Policies
- Service Accounts

The template uses the **ag-helm shared library** to provide standardized, reusable Helm templates for all BC Gov Justice applications.

## Prerequisites

Before using this template, ensure you have:
- [Cookiecutter](https://cookiecutter.readthedocs.io/) installed
- [Helm 3.x](https://helm.sh/docs/intro/install/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured
- Access to a Kubernetes/OpenShift cluster (Emerald, Silver, Gold)
- Your **License Plate** (provided by the platform team)

## Quick Start

### 1. Generate Your GitOps Repository

```bash
# Clone this template repository
git clone <template-repo-url>
cd ministry-gitops-jag-template-main

# Generate a GitOps repo (includes charts + deploy values + Argo CD)
cookiecutter ./gitops-repo --no-input \
  app_name=myapp \
  licence_plate=abc123 \
  github_org=bcgov-c
```

### 2. Set Up Dependencies

The generated chart depends on the **ag-helm shared library** via an OCI registry dependency (default in `charts/gitops/Chart.yaml`).

### 3. Configure Your Application

Edit the generated values files to match your application:

**For Development:**
Edit `myapp-gitops/deploy/dev_values.yaml`:

```yaml
frontend:
  enabled: true
  image:
    repository: your-registry
    name: your-frontend-image
    tag: latest

backend:
  enabled: true
  image:
    repository: your-registry
    name: your-backend-api
    tag: latest
```

### 4. Deploy to Your Environment

```bash
cd myapp-gitops/charts/gitops

# Update Helm dependencies
helm dependency update

# Deploy to dev
helm install myapp . \
  --values /tmp/myapp-deploy/dev_values.yaml \
  --namespace abc123-dev
```

### 5. Verify Deployment

```bash
# Check pods
kubectl get pods -n abc123-dev

# Check services
kubectl get svc -n abc123-dev

# Check routes (OpenShift)
kubectl get routes -n abc123-dev
```

## What Gets Generated?

When you run cookiecutter, you get:

### Chart Structure
```
myapp-charts/
└── gitops/
    ├── Chart.yaml                    # Helm chart metadata
    ├── values.yaml                   # Default values
    ├── charts/                       # Subchart dependencies
    └── templates/
        ├── frontend-deployment.yaml  # Frontend workload
        ├── frontend-service.yaml     # Frontend service
        ├── frontend-route.yaml       # Frontend OpenShift route
        ├── frontend-hpa.yaml         # Frontend autoscaling
        ├── backend-deployment.yaml   # Backend workload
        ├── backend-service.yaml      # Backend service
        ├── backend-hpa.yaml          # Backend autoscaling
        └── ...                       # Network policies, service accounts
```

### Deployment Configurations
```
myapp-deploy/
├── dev_values.yaml      # Development environment config
├── test_values.yaml     # Test environment config
└── prod_values.yaml     # Production environment config
```

## Next Steps

- Read [Template Structure](template-structure.md) to understand the generated files
- Read [Configuration Guide](configuration-guide.md) to customize your deployment
- Read [Using ag-helm](architecture.md#ag-helm-shared-library) to add more components
- See [Examples](examples/) for common deployment patterns

## Testing

Test the complete deployment:

```bash
cd ministry-gitops-jag-template-main
bash scripts/test-complete-deployment.sh
```

This validates:
- Cookiecutter generation works
- Helm charts deploy successfully
- All components start correctly
- HPAs are configured
- Services are exposed
