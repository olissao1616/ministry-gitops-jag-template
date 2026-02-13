# BC Government Justice GitOps Template

A cookiecutter template for creating standardized GitOps repositories for BC Government Justice applications deployed on OpenShift/Kubernetes.

## 🎉 New: Helm Chart Published to GHCR!

The `ag-helm-templates` shared library is now published to GitHub Container Registry. **No need to copy `shared-lib` folders anymore!**

📦 **Package:** `oci://ghcr.io/olissao1616/helm/ag-helm-templates:1.0.3`

See [HELM_PACKAGE_GUIDE.md](HELM_PACKAGE_GUIDE.md) for details.

## Quick Start

**One command to test everything:**

```bash
bash scripts/test-complete-deployment.sh
```

This validates the complete workflow: generation, deployment, and verification.

### Validation & policy scans

For a single-page overview of which tools/policies run in CI, how to run the same checks locally, and how to troubleshoot failures, see:

- `docs/validation-and-policy-scans.md`

## What This Template Provides

- **Standardized Helm Charts** using the ag-helm shared library
- **Support for Frontend + Backend + Database** architectures
- **Environment-specific configurations** (dev, test, prod)
- **Horizontal Pod Autoscaling** (HPA) ready
- **OpenShift Routes** for external access
- **Network Policies** for security
- **Service Accounts** for RBAC

## For Developers

### Prerequisites

- [Cookiecutter](https://cookiecutter.readthedocs.io/) - `pip install cookiecutter`
- [Helm 3.x](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured for your cluster
- Your **License Plate** (provided by platform team)

### Generate Your GitOps Repository

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

### Configure Your Application

Edit the generated values file (`myapp-gitops/deploy/dev_values.yaml`):

```yaml
frontend:
  enabled: true
  image:
    repository: docker.io/myorg
    name: my-frontend-app
    tag: "v1.0.0"
  route:
    host: myapp-abc123-dev.apps.emerald.devops.gov.bc.ca

backend:
  enabled: true
  image:
    repository: docker.io/myorg
    name: my-backend-api
    tag: "v1.0.0"
  database:
    connectionString: "Host=myapp-postgresql;Port=5432;..."
```

### Deploy

```bash
# The ag-helm dependency is now fetched from GHCR automatically!
cd myapp-charts/gitops
helm dependency update

# Deploy to dev
helm install myapp . \
  --values ../../myapp-deploy/dev_values.yaml \
  --namespace abc123-dev \
  --create-namespace

# Verify
kubectl get pods -n abc123-dev
```

**Note:** No need to manually copy `shared-lib/ag-helm` anymore! The cookiecutter template is configured to pull from `oci://ghcr.io/olissao1616/helm/ag-helm-templates` automatically.

## Key Features

### ag-helm Shared Library

Reusable Helm templates for consistent deployments across all Justice applications:

- **Standardized Deployments** - Container configurations, security contexts, resource limits
- **Service Discovery** - Kubernetes services with consistent naming
- **Autoscaling** - HPA configurations for CPU/memory-based scaling
- **Network Policies** - Default security rules for pod communication

### Adding New Components

To add a new service (e.g., "worker"):

**1. Add values configuration:**

```yaml
worker:
  enabled: true
  image:
    repository: docker.io/myorg
    name: my-worker
    tag: latest
  service:
    port: 8081
```

**2. Create deployment template (`worker-deployment.yaml`):**

```yaml
{{- if .Values.worker.enabled }}
{{- $p := dict "Values" .Values.worker -}}
{{- $_ := set $p "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $p "Name" (default "worker" .Values.worker.image.name) -}}
{{- $_ := set $p "Registry" .Values.worker.image.repository -}}
{{- $_ := set $p "ModuleValues" (dict
  "image" (dict "tag" .Values.worker.image.tag "pullPolicy" .Values.worker.image.pullPolicy)
  "replicas" .Values.worker.replicaCount
  "resources" .Values.worker.resources
) -}}
{{ include "ag-template.deployment" $p }}
{{- end }}
```

**3. Deploy:**

```bash
helm upgrade myapp . --values dev_values.yaml
```

See [Architecture Documentation](docs/architecture.md#adding-a-new-service-component) for detailed instructions.

## Documentation

### Developer Onboarding
- **[Developer Cookbook (Emerald / Zero-Trust)](docs/developer-cookbook.md)** - End-to-end onboarding and working patterns

### Getting Started
- **[Getting Started Guide](docs/getting-started.md)** - First-time setup and deployment
- **[Repository Structure](docs/repository-structure.md)** - Naming conventions and folder structure

### Understanding the Template
- **[Architecture](docs/architecture.md)** - How the template works and using ag-helm
- **[Template Structure](docs/template-structure.md)** - Understanding template files
- **[Configuration Guide](docs/configuration-guide.md)** - Complete values reference

### Deployment
- **[Deployment Guide](docs/deployment-guide.md)** - Step-by-step deployment instructions
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

### Changelog
- **[CHANGELOG.md](CHANGELOG.md)** - Recent fixes and improvements

## Recent Fixes

### Template Syntax Issues (2026-02-10)

Fixed critical cookiecutter template syntax errors:

✅ **Fixed Files:**
- `frontend-route.yaml` - Escaped Helm syntax, added closing tag
- `backend-hpa.yaml` - Escaped Helm syntax, added closing tag
- `frontend-hpa.yaml` - Escaped Helm syntax, added closing tag

✅ **Fixed Image Paths:**
- Deployment templates now use `image.name` from values
- Supports custom Docker image names

✅ **Fixed Security Context:**
- Changed `runAsNonRoot: false` to allow standard Docker images
- Changed `readOnlyRootFilesystem: false` for writable containers

✅ **Fixed PostgreSQL:**
- Uses `postgres:16` (official image) instead of unavailable Bitnami image

See [CHANGELOG.md](CHANGELOG.md) for complete details.

## Testing

### End-to-End Test

Validates the complete workflow:

```bash
cd ministry-gitops-jag-template-main
bash scripts/test-complete-deployment.sh
```

**What it tests:**
- ✅ Cookiecutter generation
- ✅ Helm chart deployment
- ✅ Frontend deployment (1/1 ready)
- ✅ Backend deployment (1/1 ready)
- ✅ PostgreSQL deployment (1/1 ready)
- ✅ HPAs configured
- ✅ Services exposed

### Component Tests

```bash
bash scripts/test-unified-gitops-chart.sh
```

Tests individual scenarios:
- Frontend-only deployment
- Backend-only deployment
- Full-stack deployment

## Architecture

```
┌─────────────────────────────────────────┐
│     Environment Values Files             │
│     (dev_values.yaml, prod_values.yaml) │
└──────────────┬──────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│     Application Templates                │
│     (frontend-deployment.yaml, etc.)     │
│     - Uses cookiecutter for generation   │
│     - Uses Helm for deployment           │
└──────────────┬──────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│     ag-helm Shared Library               │
│     (Reusable Helm template functions)   │
│     - ag-template.deployment             │
│     - ag-template.service                │
│     - ag-template.hpa                    │
└──────────────────────────────────────────┘
```

## Repository Structure

```
ministry-gitops-jag-template-main/
├── charts/                          # Helm chart templates
│   └── {{cookiecutter.charts_dir}}/
│       └── gitops/
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/          # Kubernetes manifests
│
├── deploy/                          # Environment configurations
│   └── {{cookiecutter.deploy_dir}}/
│       ├── dev_values.yaml
│       ├── test_values.yaml
│       └── prod_values.yaml
│
├── shared-lib/                      # Shared libraries
│   └── ag-helm/                    # ag-helm Helm library
│
├── scripts/                         # Utility scripts
│   ├── test-complete-deployment.sh
│   └── test-unified-gitops-chart.sh
│
├── docs/                            # Documentation
│   ├── getting-started.md
│   ├── architecture.md
│   ├── configuration-guide.md
│   └── ...
│
├── README.md                        # This file
└── CHANGELOG.md                     # Version history
```

## Common Use Cases

### Frontend-Only Deployment

```yaml
frontend:
  enabled: true
backend:
  enabled: false
postgresql:
  enabled: false
```

### Backend with Database

```yaml
frontend:
  enabled: false
backend:
  enabled: true
  database:
    connectionString: "Host=myapp-postgresql;..."
postgresql:
  enabled: true
```

### Full Stack

```yaml
frontend:
  enabled: true
  apiUrl: "myapp-backend:8080"
backend:
  enabled: true
  database:
    connectionString: "Host=myapp-postgresql;..."
postgresql:
  enabled: true
```

## Naming Conventions

### Namespaces

```
{licence_plate}-{environment}
```

Examples: `abc123-dev`, `abc123-test`, `abc123-prod`

### Routes

```
{app}-{licence_plate}-{environment}.apps.{cluster}.devops.gov.bc.ca
```

Examples:
- `myapp-abc123-dev.apps.emerald.devops.gov.bc.ca`
- `myapp-abc123-prod.apps.gold.devops.gov.bc.ca`

See [Repository Structure](docs/repository-structure.md) for complete naming standards.

## Contributing

### Reporting Issues

Found a bug or have a suggestion? Please open an issue with:
- Description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (Helm version, cluster type, etc.)

### Development

To modify the template:

1. Make changes to templates in `charts/` or `deploy/`
2. Test with `scripts/test-complete-deployment.sh`
3. Update documentation
4. Update CHANGELOG.md

## License

[Specify License]

## Support

For help:
1. Check [Troubleshooting Guide](docs/troubleshooting.md)
2. Review [Documentation](docs/)
3. Contact platform team
4. Open an issue

## Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Cookiecutter Documentation](https://cookiecutter.readthedocs.io/)
- [OpenShift Documentation](https://docs.openshift.com/)

---

**Template Version:** 1.0.0 (2026-02-10)

**Maintained by:** BC Government Justice Digital Services
