# Troubleshooting Guide

## Common Issues and Solutions

### Cookiecutter Generation Issues

#### Issue: Template syntax errors

```
jinja2.exceptions.TemplateSyntaxError: unexpected '.'
```

**Cause:** Helm syntax not properly escaped in cookiecutter templates.

**Solution:** This has been fixed in the template. Ensure you're using the latest version.

**Fixed files:**
- `frontend-route.yaml`
- `backend-hpa.yaml`
- `frontend-hpa.yaml`

These now use escaped syntax: `{{ "{{" }}` and `{{ "}}" }}`

#### Issue: Cookiecutter not found

```
bash: cookiecutter: command not found
```

**Solution:**
```bash
# Install cookiecutter
pip install cookiecutter

# Or with pipx
pipx install cookiecutter
```

### Helm Dependency Issues

#### Issue: ag-helm library not found

```
Error: directory ../../../shared-lib/ag-helm not found
```

**Cause:** The ag-helm shared library isn't in the expected location.

**Solution:**
```bash
# Copy ag-helm to expected location
mkdir -p /tmp/shared-lib
cp -r shared-lib/ag-helm /tmp/shared-lib/

# Update dependencies
cd charts/myapp-charts/gitops
helm dependency update
```

#### Issue: Bitnami PostgreSQL image not found

```
Failed to pull image "docker.io/bitnami/postgresql:16.2.0-debian-11-r1": not found
```

**Cause:** Specific Bitnami version doesn't exist.

**Solution:** The template now uses `postgres:16` by default. If using older template:

```yaml
# In dev_values.yaml
postgresql:
  image:
    repository: postgres
    tag: "16"
```

### Deployment Issues

#### Issue: Pods stuck in ImagePullBackOff

```
pod/myapp-frontend-xxx   0/1     ImagePullBackOff
```

**Diagnosis:**
```bash
kubectl describe pod myapp-frontend-xxx -n abc123-dev
```

**Common Causes:**

**1. Wrong image name**
```yaml
# Check your values
frontend:
  image:
    repository: docker.io/myorg
    name: my-frontend     # Must match actual image name
    tag: latest
```

**2. Private registry without credentials**
```bash
# Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=myuser \
  --docker-password=mypass \
  -n abc123-dev

# Add to deployment
frontend:
  imagePullSecrets:
    - name: regcred
```

**3. Image tag doesn't exist**
```bash
# Verify image exists
docker pull docker.io/myorg/my-frontend:latest
```

#### Issue: Pods stuck in CreateContainerConfigError

```
pod/myapp-frontend-xxx   0/1     CreateContainerConfigError
```

**Diagnosis:**
```bash
kubectl describe pod myapp-frontend-xxx -n abc123-dev | grep Error
```

**Common Causes:**

**1. runAsNonRoot security context**
```
Error: container has runAsNonRoot and image will run as root
```

**Solution:** This has been fixed in the template. The default security context now allows root:

```yaml
# In ag-helm/templates/_helpers.tpl
runAsNonRoot: false
allowPrivilegeEscalation: false
readOnlyRootFilesystem: false
```

**2. Missing environment variable**
```
Error: required env var SOME_VAR not set
```

**Solution:** Add to values:
```yaml
frontend:
  extraEnv:
    - name: SOME_VAR
      value: "some-value"
```

#### Issue: Pods CrashLoopBackOff

```
pod/myapp-backend-xxx   0/1     CrashLoopBackOff
```

**Diagnosis:**
```bash
# Check logs
kubectl logs myapp-backend-xxx -n abc123-dev

# Check previous container logs
kubectl logs myapp-backend-xxx -n abc123-dev --previous
```

**Common Causes:**

**1. Database connection failure**
```
Error: Could not connect to database
```

**Solution:** Verify database connection string:
```yaml
backend:
  database:
    connectionString: "Host=myapp-postgresql;Port=5432;Database=appdb;Username=appuser;Password=changeme"
```

Check PostgreSQL is running:
```bash
kubectl get pods -n abc123-dev | grep postgresql
```

**2. Missing required configuration**

Check application logs for missing config and add to values.

**3. Port already in use**

Check if port conflicts with another service.

### Service Issues

#### Issue: Service not accessible

**Diagnosis:**
```bash
# Check service exists
kubectl get svc -n abc123-dev

# Check endpoints
kubectl get endpoints -n abc123-dev

# Check if pods are ready
kubectl get pods -n abc123-dev
```

**Solution:** Ensure:
1. Pods are running and ready
2. Service selector matches pod labels
3. Service port matches container port

#### Issue: Route not working (OpenShift)

**Diagnosis:**
```bash
# Check route exists
kubectl get routes -n abc123-dev

# Describe route
kubectl describe route myapp-frontend -n abc123-dev
```

**Common Causes:**

**1. Hostname already in use**

Choose a unique hostname.

**2. Route not enabled**
```yaml
frontend:
  route:
    enabled: true  # Must be true
```

**3. Wrong cluster domain**
```yaml
# Emerald cluster
host: myapp-abc123-dev.apps.emerald.devops.gov.bc.ca

# Silver cluster
host: myapp-abc123-dev.apps.silver.devops.gov.bc.ca

# Gold cluster
host: myapp-abc123-dev.apps.gold.devops.gov.bc.ca
```

### HPA Issues

#### Issue: HPA shows `<unknown>` for metrics

```
NAME             REFERENCE                   TARGETS         MINPODS   MAXPODS
myapp-frontend   Deployment/myapp-frontend   <unknown>/80%   1         10
```

**Cause:** Metrics server not installed or pod has no resource requests.

**Solution:**

**1. Ensure resource requests are set:**
```yaml
frontend:
  resources:
    requests:
      cpu: 50m      # Required for HPA
      memory: 128Mi
```

**2. Wait for metrics (takes 1-2 minutes)**
```bash
kubectl top pods -n abc123-dev
```

**3. Check metrics server:**
```bash
kubectl get deployment metrics-server -n kube-system
```

### Configuration Issues

#### Issue: Environment variables not set

**Diagnosis:**
```bash
kubectl exec myapp-frontend-xxx -n abc123-dev -- env | grep VITE
```

**Solution:** Check your values file:
```yaml
frontend:
  keycloak:
    authUrl: "https://..."  # Will become VITE_DIAM_AUTH_URL
    realm: "ISB"            # Will become VITE_DIAM_AUTH_REALM
```

#### Issue: Database password visible in values

**Security Risk:** Never commit passwords to Git!

**Solution:** Use Kubernetes secrets:

```bash
# Create secret
kubectl create secret generic myapp-db-secret \
  --from-literal=connection-string="Host=..." \
  -n abc123-dev

# Reference in values
backend:
  database:
    connectionString: ""  # Leave empty
  extraEnv:
    - name: ConnectionStrings__Database
      valueFrom:
        secretKeyRef:
          name: myapp-db-secret
          key: connection-string
```

### Helm Issues

#### Issue: Release already exists

```
Error: cannot re-use a name that is still in use
```

**Solution:**
```bash
# Uninstall existing release
helm uninstall myapp -n abc123-dev

# Or use upgrade instead
helm upgrade --install myapp . --values values.yaml
```

#### Issue: Helm dependencies out of date

```
Error: found in Chart.yaml, but missing in charts/ directory
```

**Solution:**
```bash
cd charts/myapp-charts/gitops
helm dependency update
```

#### Issue: Values not taking effect

**Diagnosis:**
```bash
# Check what Helm is using
helm get values myapp -n abc123-dev
```

**Solution:** Ensure you're passing the correct values file:
```bash
helm upgrade myapp . --values /correct/path/to/dev_values.yaml -n abc123-dev
```

### Network Policy Issues

#### Issue: Pods can't communicate

**Diagnosis:**
```bash
# Test connectivity
kubectl exec myapp-frontend-xxx -n abc123-dev -- curl myapp-backend:8080

# Check network policies
kubectl get networkpolicies -n abc123-dev
```

**Solution:** Network policies are automatically created. If issues persist:

```yaml
# Temporarily disable to test
frontend:
  networkPolicy:
    enabled: false
```

### Resource Limit Issues

#### Issue: Pods OOMKilled (Out of Memory)

```
pod/myapp-backend-xxx   0/1     OOMKilled
```

**Diagnosis:**
```bash
kubectl describe pod myapp-backend-xxx -n abc123-dev | grep -A 5 "Last State"
```

**Solution:** Increase memory limits:
```yaml
backend:
  resources:
    limits:
      memory: 512Mi  # Increase from 256Mi
    requests:
      memory: 256Mi
```

#### Issue: Pods throttled (CPU)

**Diagnosis:**
```bash
kubectl top pods -n abc123-dev
```

**Solution:** Increase CPU limits:
```yaml
backend:
  resources:
    limits:
      cpu: 200m  # Increase from 100m
```

## Debugging Commands

### Get All Resources

```bash
kubectl get all -n abc123-dev
```

### Describe Pod

```bash
kubectl describe pod myapp-frontend-xxx -n abc123-dev
```

### View Logs

```bash
# Current logs
kubectl logs myapp-frontend-xxx -n abc123-dev

# Previous container logs
kubectl logs myapp-frontend-xxx -n abc123-dev --previous

# Follow logs
kubectl logs myapp-frontend-xxx -n abc123-dev -f

# All pods in deployment
kubectl logs deployment/myapp-frontend -n abc123-dev
```

### Execute Commands in Pod

```bash
# Interactive shell
kubectl exec -it myapp-frontend-xxx -n abc123-dev -- /bin/sh

# Single command
kubectl exec myapp-frontend-xxx -n abc123-dev -- env
```

### Port Forward for Testing

```bash
# Forward local port to pod
kubectl port-forward myapp-frontend-xxx 8000:8000 -n abc123-dev

# Forward to service
kubectl port-forward svc/myapp-frontend 8000:8000 -n abc123-dev
```

### Check Events

```bash
kubectl get events -n abc123-dev --sort-by='.lastTimestamp'
```

### Check Resource Usage

```bash
kubectl top pods -n abc123-dev
kubectl top nodes
```

## Getting Help

### Check Template Version

```bash
# Check if you have latest fixes
grep -r "runAsNonRoot: false" shared-lib/ag-helm/templates/_helpers.tpl
```

### Run Tests

```bash
cd ministry-gitops-jag-template-main
bash scripts/test-complete-deployment.sh
```

### Review Generated Manifests

```bash
helm template myapp ./charts/myapp-charts/gitops \
  --values ./deploy/dev_values.yaml \
  > debug-manifests.yaml

# Review the file
cat debug-manifests.yaml
```

## Next Steps

- Review [Configuration Guide](configuration-guide.md) for correct settings
- Review [Deployment Guide](deployment-guide.md) for proper deployment steps
- Check [Examples](examples/) for working configurations
