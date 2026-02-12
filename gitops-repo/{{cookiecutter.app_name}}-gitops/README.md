# {{ cookiecutter.app_name }}-gitops

GitOps repository for {{ cookiecutter.app_name }} - Deployed to BC Government Emerald OpenShift Platform

## Overview

{{ cookiecutter.description }}

**License Plate:** `{{ cookiecutter.licence_plate }}`

**Namespaces:**

- Development: `{{ cookiecutter.namespace_dev }}`
- Test: `{{ cookiecutter.namespace_test }}`
- Production: `{{ cookiecutter.namespace_prod }}`

---

## Repository Structure

```
{{ cookiecutter.app_name }}-gitops/
├── .github/
│   ├── policies.yaml              # Datree policy configuration for K8s validation
│   └── workflows/                 # GitHub Actions CI/CD pipelines
│       ├── ci.yml                 # Continuous integration (lint, template, test)
│       ├── policy-enforcement.yaml # Datree policy checks on branch pushes
│       ├── validate-network-policies.yaml           # Network policy validation
│       ├── validate-network-policies-comprehensive.yaml  # Extended validation
│       ├── repository-setup.yml   # Initial repo setup (runs once)
│       ├── setup-repository.yml   # Alternative setup workflow
│       └── template-report.yml    # Template usage reporting
│
├── argocd/                        # ArgoCD Application manifests
│   ├── {{ cookiecutter.licence_plate }}-gitops-dev.yaml   # Dev environment ArgoCD app
│   ├── {{ cookiecutter.licence_plate }}-gitops-test.yaml  # Test environment ArgoCD app
│   └── {{ cookiecutter.licence_plate }}-gitops-prod.yaml  # Prod environment ArgoCD app
│
├── charts/                        # Helm charts
│   ├── .polaris.yaml              # Polaris security validation config
│   ├── .kube-linter.yaml          # Kube-linter validation config
│   ├── policy/                    # OPA/Conftest policies
│   │   ├── dataclass.rego         # DataClass label validation
│   │   ├── networkpolicy.rego     # Network policy validation
│   │   └── security.rego          # Security policy validation
│   └── gitops/                    # Main Helm chart
│       ├── Chart.yaml             # Chart metadata and dependencies
│       ├── values.yaml            # Default values
│       ├── charts/                # Dependency charts (downloaded from OCI registry)
│       └── templates/             # Kubernetes manifest templates
│           ├── _helpers.tpl       # Template helpers
│           ├── backend-*.yaml     # Backend (API) resources
│           ├── frontend-*.yaml    # Frontend (Web) resources
│           ├── postgresql-*.yaml  # Database resources
│           └── priorityclass.yaml # Pod priority configuration
│
└── deploy/                        # Environment-specific values
    ├── dev_values.yaml            # Development environment configuration
    ├── test_values.yaml           # Test environment configuration
    └── prod_values.yaml           # Production environment configuration
```

### Key Files Explained

| File/Folder                   | Purpose                                                              | When to Edit                                        |
| ----------------------------- | -------------------------------------------------------------------- | --------------------------------------------------- |
| `deploy/*_values.yaml`      | Environment-specific configuration (image tags, replicas, resources) | When deploying new versions or adjusting resources  |
| `charts/gitops/Chart.yaml`  | Helm chart metadata and dependency versions                          | When updating dependency chart versions             |
| `charts/gitops/values.yaml` | Default values for all environments                                  | When adding new configuration options               |
| `charts/gitops/templates/`  | Kubernetes resource templates                                        | When adding new services or modifying K8s resources |
| `argocd/*.yaml`             | ArgoCD application definitions                                       | When changing sync policies or repository URLs      |
| `.github/policies.yaml`     | Datree security policies                                             | When adjusting security policy rules                |

---

## Prerequisites

### Required Tools

- `kubectl` - Kubernetes CLI
- `helm` (v3.14+) - Helm package manager
- `oc` - OpenShift CLI
- Git

### Required Access

- BC Government GitHub organization membership
- Emerald OpenShift cluster access
- Appropriate namespace permissions (`{{ cookiecutter.licence_plate }}-dev`, `{{ cookiecutter.licence_plate }}-test`, `{{ cookiecutter.licence_plate }}-prod`)

---

## Quick Start

### 1. Deploy to Development

```bash
# Login to OpenShift
oc login --server=https://api.emerald.devops.gov.bc.ca:6443

# Switch to dev namespace
oc project {{ cookiecutter.namespace_dev }}

# Update Helm dependencies
helm dependency update ./charts/gitops

# Deploy with Helm
helm upgrade --install {{ cookiecutter.app_name }} ./charts/gitops \
  --values ./deploy/dev_values.yaml \
  --namespace {{ cookiecutter.namespace_dev }}
```

### 2. Deploy with ArgoCD (Recommended)

```bash
# Apply ArgoCD application
kubectl apply -f argocd/{{ cookiecutter.licence_plate }}-gitops-dev.yaml

# Check sync status
argocd app get {{ cookiecutter.app_name }}-dev
```

### 3. View Deployed Resources

```bash
# Check pods
kubectl get pods -n {{ cookiecutter.namespace_dev }}

# Check services
kubectl get svc -n {{ cookiecutter.namespace_dev }}

# Check routes
kubectl get route -n {{ cookiecutter.namespace_dev }}
```

---

## How to Make Changes

### Update Application Version

**File to edit:** `deploy/dev_values.yaml` (or test_values.yaml, prod_values.yaml)

```yaml
backend:
  image:
    tag: "v1.2.3"  # Change this version

frontend:
  image:
    tag: "v2.0.1"  # Change this version
```

**Commit and push** - ArgoCD will automatically sync the changes.

### Adjust Resources (CPU/Memory)

**File to edit:** `deploy/dev_values.yaml`

```yaml
backend:
  resources:
    requests:
      cpu: "500m"      # Increase if needed
      memory: "1Gi"    # Increase if needed
    limits:
      cpu: "1000m"
      memory: "2Gi"
```

### Scale Replicas

**File to edit:** `deploy/dev_values.yaml`

```yaml
backend:
  replicaCount: 3  # Increase for high availability
```

### Add Environment Variables

**File to edit:** `deploy/dev_values.yaml`

```yaml
backend:
  env:
    - name: NEW_ENV_VAR
      value: "some_value"
```

---

## CI/CD Pipelines

### Workflows Overview

| Workflow                            | Trigger                   | Purpose                                                        |
| ----------------------------------- | ------------------------- | -------------------------------------------------------------- |
| **CI**                        | Push/PR to main           | Lints and templates charts for all environments                |
| **Policy Enforcement**        | Push to main/test/develop | Runs Datree security policy checks                             |
| **Network Policy Validation** | Push/PR                   | Validates network policies with Conftest, Polaris, kube-linter |
| **Comprehensive Validation**  | Push/PR                   | Extended validation with Trivy, Checkov, kube-score            |

### Policy Checks

Your repo is validated against BC Government Emerald security policies:

- **DataClass Labels** - Must be `Low`, `Medium`, or `High`
- **Network Policies** - All pods must have network policies defined
- **Security Context** - Containers must not run as root
- **Resource Limits** - All containers must have CPU/memory limits
- **Image Tags** - No `latest` tags allowed

**Fix policy failures** before merging to main.

---

## Emerald Platform Specifics

### Network Policies

All services **must** have network policies. Templates included:

- `backend-networkpolicy.yaml` - API service network policy
- `frontend-networkpolicy.yaml` - Web app network policy
- `postgresql-networkpolicy.yaml` - Database network policy

### DataClass Labels

All workloads **must** have `dataClass` labels:

```yaml
metadata:
  labels:
    dataClass: "Medium"  # Options: Low, Medium, High
```

### Routes (External Access)

Routes use edge termination by default:

```yaml
spec:
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

---

## Testing Locally

### Render Templates

```bash
helm template {{ cookiecutter.app_name }} ./charts/gitops \
  --values ./deploy/dev_values.yaml \
  --debug > rendered-dev.yaml
```

### Validate with Helm

```bash
helm lint ./charts/gitops --values ./deploy/dev_values.yaml
```

### Validate Policies Locally

```bash
# Install Datree
helm plugin install https://github.com/datreeio/helm-datree

# Run policy check
helm datree test --policy-config .github/policies.yaml \
  ./charts/gitops -- --values ./deploy/dev_values.yaml
```

---

## Troubleshooting

### Common Issues

**Problem:** Pods in `ImagePullBackOff`
**Solution:** Check image registry access and image tag in `deploy/*_values.yaml`

**Problem:** Service not accessible
**Solution:** Check route configuration and network policies

**Problem:** Helm dependency update fails
**Solution:** Ensure you have access to `ghcr.io/olissao1616/helm` registry

**Problem:** ArgoCD not syncing
**Solution:** Check ArgoCD application status: `argocd app get {{ cookiecutter.app_name }}-dev`

### Get Logs

```bash
# Pod logs
kubectl logs -f <pod-name> -n {{ cookiecutter.namespace_dev }}

# Previous pod logs (after crash)
kubectl logs <pod-name> -n {{ cookiecutter.namespace_dev }} --previous
```

---

## Additional Resources

For detailed documentation about the template structure, advanced customization, and architecture decisions:

📚 **Template Documentation:** https://github.com/bcgov-c/ministry-gitops-jag-template/tree/main/docs

**Key documents:**

- [Repository Structure](https://github.com/bcgov-c/ministry-gitops-jag-template/blob/main/docs/repository-structure.md)
- [Network Policies Guide](https://github.com/bcgov-c/ministry-gitops-jag-template/blob/main/docs/network-policies.md)
- [Configuration Guide](https://github.com/bcgov-c/ministry-gitops-jag-template/blob/main/docs/configuration-guide.md)
- [Troubleshooting](https://github.com/bcgov-c/ministry-gitops-jag-template/blob/main/docs/troubleshooting.md)

---

## Support

**Emerald Platform Support:** [Emerald Support Channel]
**Template Issues:** https://github.com/bcgov-c/ministry-gitops-jag-template/issues
