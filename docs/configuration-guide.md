# Configuration Guide

## Overview

This guide explains all configuration options available in your values files (`values.yaml`, `dev_values.yaml`, `prod_values.yaml`).

## Global Configuration

### Project Settings

```yaml
# Project identifier - usually your app name
project: "myapp"

# Environment name (dev, test, prod)
environment: dev
```

## Frontend Configuration

### Basic Settings

```yaml
frontend:
  # Enable/disable frontend deployment
  enabled: true

  # Environment labels (optional)
  environment: dev
  env: development
  owner: "myteam"
  project: "myproject"
```

### Image Configuration

```yaml
frontend:
  image:
    # Docker registry (without trailing slash)
    repository: docker.io/myorg

    # Image name (the ag-helm library constructs: repository/name:tag)
    name: my-frontend-app

    # Image tag
    tag: "latest"

    # Image pull policy
    pullPolicy: Always  # Always, IfNotPresent, Never
```

**Important:** The final image path is constructed as: `${repository}/${name}:${tag}`

Example:
- `repository: docker.io/bcgov`
- `name: react-app`
- `tag: v1.2.3`
- **Result:** `docker.io/bcgov/react-app:v1.2.3`

### Replica Configuration

```yaml
frontend:
  # Number of pod replicas (when autoscaling is disabled)
  replicaCount: 2
```

### Resource Limits

```yaml
frontend:
  resources:
    limits:
      cpu: 100m        # Maximum CPU (millicores)
      memory: 256Mi    # Maximum memory
    requests:
      cpu: 50m         # Requested CPU
      memory: 128Mi    # Requested memory
```

**Resource Guidelines:**
- **Small apps:** 50m CPU, 128Mi memory
- **Medium apps:** 100m CPU, 256Mi memory
- **Large apps:** 200m+ CPU, 512Mi+ memory

### Service Configuration

```yaml
frontend:
  service:
    type: ClusterIP    # ClusterIP, NodePort, LoadBalancer
    port: 8000         # Service port
```

### OpenShift Route

```yaml
frontend:
  route:
    # Enable OpenShift route
    enabled: true

    # Hostname for the route
    host: myapp-abc123-dev.apps.emerald.devops.gov.bc.ca

    # Additional annotations
    annotations:
      aviinfrasetting.ako.vmware.com/name: "dataclass-medium"
```

**Route Naming Convention:**
```
{app-name}-{licence-plate}-{environment}.apps.{cluster}.devops.gov.bc.ca
```

### Horizontal Pod Autoscaling (HPA)

```yaml
frontend:
  autoscaling:
    # Enable autoscaling
    enabled: true

    # Minimum number of pods
    minReplicas: 2

    # Maximum number of pods
    maxReplicas: 10

    # CPU threshold for scaling up (percentage)
    targetCPUUtilizationPercentage: 80

    # Memory threshold for scaling up (percentage)
    targetMemoryUtilizationPercentage: 80
```

**HPA Behavior:**
- Scales up when CPU/memory exceeds threshold
- Scales down when usage drops below threshold
- Respects min/max replica limits

### Keycloak/SSO Configuration

```yaml
frontend:
  keycloak:
    authUrl: https://sso-e27db1-dev.apps.gold.devops.gov.bc.ca/auth
    realm: ISB
    clientId: my-frontend-app
```

These values are exposed as environment variables:
- `VITE_DIAM_AUTH_URL`
- `VITE_DIAM_AUTH_REALM`
- `VITE_DIAM_AUTH_CLIENT_ID`

### API URL

```yaml
frontend:
  # Backend API URL (for frontend to call backend)
  apiUrl: "myapp-backend:8080"
```

Exposed as: `VITE_API_URL`

### Service Account

```yaml
frontend:
  serviceAccount:
    create: true
    automount: true
    annotations: {}
```

### Security Context

```yaml
frontend:
  containerSecurityContext:
    runAsNonRoot: false
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: false
```

### Data Classification

```yaml
frontend:
  # Data classification label (low, medium, high)
  dataClass: "medium"

  # Pod labels
  podLabels:
    DataClass: "Medium"
```

### Custom Environment Variables

```yaml
frontend:
  extraEnv:
    - name: CUSTOM_VAR
      value: "custom-value"
    - name: SECRET_VAR
      valueFrom:
        secretKeyRef:
          name: my-secret
          key: password
```

### Volumes and Volume Mounts

```yaml
frontend:
  volumes:
    - name: config
      configMap:
        name: my-config

  volumeMounts:
    - name: config
      mountPath: /etc/config
      readOnly: true
```

## Backend Configuration

Backend configuration follows the same structure as frontend, with additional database settings:

### Database Configuration

```yaml
backend:
  database:
    connectionString: "Host=myapp-postgresql;Port=5432;Database=appdb;Username=appuser;Password=changeme"
```

Exposed as: `ConnectionStrings__Database`

### Keycloak Configuration

```yaml
backend:
  keycloak:
    realmUrl: https://sso-e27db1-dev.apps.gold.devops.gov.bc.ca/auth/realms/ISB
    adminClientId: WEB-API
    ClientId: WEB-API
```

Exposed as:
- `Keycloak__RealmUrl`
- `Keycloak__AdministrationClientId`
- `Keycloak__ClientId`

### Backend Image Example

```yaml
backend:
  enabled: true
  image:
    repository: docker.io/myorg
    name: my-api
    tag: "v2.1.0"
    pullPolicy: Always
  service:
    port: 8080
```

## PostgreSQL Configuration

```yaml
postgresql:
  # Enable PostgreSQL deployment
  enabled: true

  # PostgreSQL image
  image:
    repository: postgres
    tag: "16"
    pullPolicy: Always

  # Authentication
  auth:
    username: appuser
    password: changeme  # Use Kubernetes secrets in production!
    database: appdb

  # Storage
  primary:
    persistence:
      enabled: true
      size: 256Mi  # Adjust based on data needs

    # Resources
    resources:
      limits:
        cpu: 100m
        memory: 512Mi
      requests:
        cpu: 50m
        memory: 256Mi

    # Initialization scripts
    initdb:
      scripts:
        01_init_schema.sql: |
          CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            username VARCHAR(255) UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          );
```

**PostgreSQL Notes:**
- Default port: 5432
- Service name: `{release-name}-postgresql`
- Headless service: `{release-name}-postgresql-hl`

## Environment-Specific Values

### Development (`dev_values.yaml`)

```yaml
frontend:
  enabled: true
  image:
    repository: docker.io/myorg
    name: my-frontend
    tag: "latest"  # Use latest for dev
  replicaCount: 1   # Single replica for dev
  autoscaling:
    enabled: false  # Disable autoscaling in dev
  route:
    host: myapp-abc123-dev.apps.emerald.devops.gov.bc.ca

backend:
  enabled: true
  image:
    repository: docker.io/myorg
    name: my-backend
    tag: "latest"
  replicaCount: 1

postgresql:
  enabled: true  # Local postgres for dev
```

### Production (`prod_values.yaml`)

```yaml
frontend:
  enabled: true
  image:
    repository: docker.io/myorg
    name: my-frontend
    tag: "v1.2.3"  # Specific version for prod
  replicaCount: 3   # Multiple replicas
  autoscaling:
    enabled: true   # Enable autoscaling
    minReplicas: 3
    maxReplicas: 20
  resources:
    limits:
      cpu: 200m     # More resources in prod
      memory: 512Mi
  route:
    host: myapp.apps.gov.bc.ca

backend:
  enabled: true
  image:
    tag: "v1.2.3"
  replicaCount: 3
  autoscaling:
    enabled: true

postgresql:
  enabled: false  # Use managed database in prod
```

## Common Configuration Patterns

### Disable a Component

```yaml
frontend:
  enabled: false  # Frontend won't be deployed
```

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
    connectionString: "Host=myapp-postgresql;Port=5432;..."

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
    connectionString: "Host=myapp-postgresql;Port=5432;..."

postgresql:
  enabled: true
```

## Validation

After modifying values, validate your chart:

```bash
# Check for syntax errors
helm lint .

# Dry-run to see generated manifests
helm install myapp . --values values.yaml --dry-run --debug

# Template to file for inspection
helm template myapp . --values values.yaml > output.yaml
```

## Secrets Management

**Never commit secrets to Git!**

### Option 1: Sealed Secrets

```yaml
backend:
  database:
    connectionString: ""  # Leave empty, use sealed secret

  extraEnv:
    - name: ConnectionStrings__Database
      valueFrom:
        secretKeyRef:
          name: myapp-db-secret
          key: connection-string
```

### Option 2: External Secrets

Use External Secrets Operator to sync from Vault or AWS Secrets Manager.

### Option 3: Helm Values Override

```bash
helm install myapp . \
  --values values.yaml \
  --set backend.database.connectionString="..."
```

## Next Steps

- See [Deployment Guide](deployment-guide.md) for deploying your app
- See [Examples](examples/) for common configurations
- See [Troubleshooting](troubleshooting.md) for common issues
