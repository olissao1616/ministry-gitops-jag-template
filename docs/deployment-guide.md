# Deployment Guide

## Prerequisites

Before deploying, ensure you have:

1. **Generated your GitOps repository** using cookiecutter
2. **Kubernetes cluster access** configured (`kubectl` working)
3. **Helm 3.x** installed
4. **License plate** and namespace created by platform team
5. **Docker images** built and pushed to a registry
6. **Values files** configured for your environment

## Deployment Workflow

```
┌──────────────────┐
│ Generate with    │
│ Cookiecutter     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Configure        │
│ Values Files     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Setup            │
│ Dependencies     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Deploy with Helm │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Verify           │
│ Deployment       │
└──────────────────┘
```

## Step 1: Generate Repository

If you haven't already, generate your GitOps repository:

```bash
# Generate charts
cd charts
cookiecutter . --no-input \
  app_name=myapp \
  licence_plate=abc123 \
  charts_dir=myapp-charts

# Generate deploy configs
cd ../deploy
cookiecutter . --no-input \
  app_name=myapp \
  licence_plate=abc123 \
  deploy_dir=myapp-deploy \
  team_name=myteam \
  project_name=myproject
```

## Step 2: Configure Values Files

### Update Image References

Edit your environment values file (e.g., `dev_values.yaml`):

```yaml
frontend:
  enabled: true
  image:
    repository: docker.io/myorg      # Your registry
    name: myapp-frontend             # Your image name
    tag: "v1.0.0"                    # Your image tag
```

### Update Hostnames

```yaml
frontend:
  route:
    enabled: true
    host: myapp-abc123-dev.apps.emerald.devops.gov.bc.ca
```

**Hostname Format:**
- **Dev:** `{app}-{licence_plate}-dev.apps.{cluster}.devops.gov.bc.ca`
- **Test:** `{app}-{licence_plate}-test.apps.{cluster}.devops.gov.bc.ca`
- **Prod:** `{app}-{licence_plate}-prod.apps.{cluster}.devops.gov.bc.ca`

### Update Database Connection

```yaml
backend:
  database:
    connectionString: "Host=myapp-postgresql;Port=5432;Database=appdb;Username=appuser;Password=CHANGEME"
```

**Production:** Use Kubernetes secrets instead of plain text passwords!

### Update Keycloak/SSO

```yaml
frontend:
  keycloak:
    authUrl: https://sso-e27db1-dev.apps.gold.devops.gov.bc.ca/auth
    realm: YOUR_REALM
    clientId: YOUR_CLIENT_ID

backend:
  keycloak:
    realmUrl: https://sso-e27db1-dev.apps.gold.devops.gov.bc.ca/auth/realms/YOUR_REALM
    adminClientId: YOUR_ADMIN_CLIENT
    ClientId: YOUR_CLIENT_ID
```

## Step 3: Setup Dependencies

The chart depends on the ag-helm shared library. Copy it to the expected location:

```bash
# From the template repo root
mkdir -p /tmp/shared-lib
cp -r shared-lib/ag-helm /tmp/shared-lib/
```

**Note:** In production GitOps workflows, the ag-helm library should be:
- Stored in a Helm chart repository
- Or included in your Git repository
- Or packaged with your chart

## Step 4: Update Helm Dependencies

```bash
cd myapp-charts/gitops

# Download dependencies
helm dependency update

# Verify dependencies
helm dependency list
```

This downloads:
- ag-helm-templates (from file:// path)
- postgresql (from Bitnami repository)

## Step 5: Validate Chart

Before deploying, validate your chart:

```bash
# Lint the chart
helm lint .

# Dry-run to see what will be deployed
helm install myapp . \
  --values /path/to/dev_values.yaml \
  --namespace abc123-dev \
  --dry-run \
  --debug

# Template to file for review
helm template myapp . \
  --values /path/to/dev_values.yaml \
  --namespace abc123-dev \
  > rendered-manifests.yaml
```

## Step 6: Deploy to Development

```bash
cd myapp-charts/gitops

# Deploy
helm install myapp . \
  --values /path/to/myapp-deploy/dev_values.yaml \
  --namespace abc123-dev \
  --create-namespace

# Watch deployment
kubectl get pods -n abc123-dev --watch
```

### Deployment Output

```
NAME: myapp
LAST DEPLOYED: 2026-02-10 09:00:00
NAMESPACE: abc123-dev
STATUS: deployed
REVISION: 1
```

## Step 7: Verify Deployment

### Check Pods

```bash
kubectl get pods -n abc123-dev
```

Expected output:
```
NAME                            READY   STATUS    RESTARTS   AGE
myapp-frontend-xxxxx-xxxxx      1/1     Running   0          2m
myapp-backend-xxxxx-xxxxx       1/1     Running   0          2m
myapp-postgresql-0              1/1     Running   0          2m
```

### Check Services

```bash
kubectl get svc -n abc123-dev
```

Expected output:
```
NAME                    TYPE        CLUSTER-IP      PORT(S)
myapp-frontend          ClusterIP   10.43.x.x       8000/TCP
myapp-backend           ClusterIP   10.43.x.x       8080/TCP
myapp-postgresql        ClusterIP   10.43.x.x       5432/TCP
myapp-postgresql-hl     ClusterIP   None            5432/TCP
```

### Check Routes (OpenShift)

```bash
kubectl get routes -n abc123-dev
```

### Check HPAs

```bash
kubectl get hpa -n abc123-dev
```

Expected output:
```
NAME                REFERENCE                   TARGETS         MINPODS   MAXPODS
myapp-frontend      Deployment/myapp-frontend   cpu: 25%/80%    1         10
myapp-backend       Deployment/myapp-backend    cpu: 30%/80%    1         10
```

### Check Logs

```bash
# Frontend logs
kubectl logs -n abc123-dev deployment/myapp-frontend

# Backend logs
kubectl logs -n abc123-dev deployment/myapp-backend

# Follow logs
kubectl logs -n abc123-dev deployment/myapp-frontend -f
```

### Test Application

```bash
# Port forward to test locally
kubectl port-forward -n abc123-dev svc/myapp-frontend 8000:8000

# In another terminal
curl http://localhost:8000
```

## Step 8: Deploy to Test

```bash
helm install myapp . \
  --values /path/to/myapp-deploy/test_values.yaml \
  --namespace abc123-test \
  --create-namespace
```

## Step 9: Deploy to Production

### Production Checklist

Before deploying to production:

- [ ] Image tags are specific versions (not `latest`)
- [ ] Secrets are stored in Kubernetes secrets (not values files)
- [ ] Resource limits are set appropriately
- [ ] Autoscaling is enabled and configured
- [ ] Monitoring and alerting configured
- [ ] Backup strategy in place for database
- [ ] Rollback plan documented
- [ ] Change approval obtained

### Deploy

```bash
helm install myapp . \
  --values /path/to/myapp-deploy/prod_values.yaml \
  --namespace abc123-prod \
  --create-namespace
```

## Updating a Deployment

### Update Values

Edit your values file with new configuration.

### Upgrade

```bash
helm upgrade myapp . \
  --values /path/to/dev_values.yaml \
  --namespace abc123-dev
```

### Update Image Tag Only

```bash
helm upgrade myapp . \
  --values /path/to/dev_values.yaml \
  --set frontend.image.tag=v1.1.0 \
  --set backend.image.tag=v1.1.0 \
  --namespace abc123-dev
```

### Check Upgrade Status

```bash
# Watch pods restart
kubectl rollout status deployment/myapp-frontend -n abc123-dev

# Check upgrade history
helm history myapp -n abc123-dev
```

## Rolling Back

### Rollback to Previous Version

```bash
helm rollback myapp -n abc123-dev
```

### Rollback to Specific Revision

```bash
# List revisions
helm history myapp -n abc123-dev

# Rollback to revision 3
helm rollback myapp 3 -n abc123-dev
```

## Uninstalling

```bash
# Uninstall release
helm uninstall myapp -n abc123-dev

# Verify deletion
kubectl get all -n abc123-dev
```

**Note:** This does NOT delete:
- Persistent Volume Claims (PVCs)
- Secrets
- ConfigMaps (unless managed by Helm)

### Delete PVCs

```bash
kubectl delete pvc -n abc123-dev --all
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to Dev

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Helm
        uses: azure/setup-helm@v3

      - name: Deploy
        run: |
          helm upgrade --install myapp ./charts/gitops \
            --values ./deploy/dev_values.yaml \
            --namespace abc123-dev \
            --kubeconfig ${{ secrets.KUBECONFIG }}
```

### ArgoCD

Store your generated chart in Git:

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp-gitops
    targetRevision: HEAD
    path: charts/gitops
    helm:
      valueFiles:
        - ../../deploy/dev_values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: abc123-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Troubleshooting

If deployment fails, see [Troubleshooting Guide](troubleshooting.md).

Common issues:
- Image pull failures
- Missing dependencies
- Incorrect hostnames
- Resource limits too low
- Database connection failures

## Next Steps

- Monitor your application with [Monitoring Guide](monitoring.md)
- Set up alerts
- Configure backups
- Review [Security Best Practices](security.md)
