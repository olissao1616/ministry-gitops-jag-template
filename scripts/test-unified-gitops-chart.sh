#!/bin/bash
set -e

echo "=========================================="
echo "Testing Unified GitOps Chart"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print success
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
error() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

# Change to repo root
cd "$(dirname "$0")/.."

echo "Step 1: Checking ag-helm shared library..."
if [ ! -d "shared-lib/ag-helm" ]; then
    error "ag-helm library not found"
fi
success "ag-helm library found"

echo ""
echo "Step 2: Running cookiecutter to generate test project..."
rm -rf /tmp/test-gitops-unified
cookiecutter ./gitops-repo --no-input \
  --output-dir /tmp/test-gitops-unified \
  app_name=testapp \
  licence_plate=abc123 \
  github_org=bcgov-c

success "Cookiecutter generation complete"

echo ""
echo "Step 3: Updating Helm dependencies..."
cd /tmp/test-gitops-unified/testapp-gitops/charts/gitops
helm dependency update
success "Dependencies updated"

echo ""
echo "Step 4: Linting gitops chart..."
helm lint .
success "Chart linting passed"

echo ""
echo "Step 5: Testing chart with frontend enabled..."
cat > /tmp/test-frontend-values.yaml <<EOF
project: testapp
environment: dev

frontend:
  enabled: true
  image:
    repository: sookeke/react-baseapp
    tag: "nextjs"
  service:
    port: 8000
  route:
    enabled: true
    host: test-frontend.apps.gov.bc.ca
  dataClass: "medium"
  replicaCount: 1
  resources:
    limits:
      cpu: 50m
      memory: 128Mi
    requests:
      cpu: 20m
      memory: 50Mi

backend:
  enabled: false
EOF

helm template testapp . --values /tmp/test-frontend-values.yaml > /tmp/frontend-render.yaml
success "Frontend-only rendering succeeded"

# Check for frontend resources
grep -q "kind: Deployment" /tmp/frontend-render.yaml && success "  - Deployment created"
grep -q "testapp-frontend" /tmp/frontend-render.yaml && success "  - Frontend name correct"
grep -q "data-class: medium" /tmp/frontend-render.yaml && success "  - data-class label present"
grep -q "kind: Service" /tmp/frontend-render.yaml && success "  - Service created"
grep -q "kind: NetworkPolicy" /tmp/frontend-render.yaml && success "  - NetworkPolicy created"

# Check backend NOT rendered
if grep -q "testapp-backend" /tmp/frontend-render.yaml; then
    error "Backend resources found when backend.enabled=false"
fi
success "  - Backend correctly disabled"

echo ""
echo "Step 6: Testing chart with backend enabled..."
cat > /tmp/test-backend-values.yaml <<EOF
project: testapp
environment: dev

frontend:
  enabled: false

backend:
  enabled: true
  image:
    repository: sookeke/web-api
    tag: "v2"
  service:
    port: 8080
  dataClass: "medium"
  replicaCount: 1
  resources:
    limits:
      cpu: 50m
      memory: 128Mi
    requests:
      cpu: 20m
      memory: 50Mi

database:
  enabled: true
  connectionString: "Host=postgres;Database=testdb"
EOF

helm template testapp . --values /tmp/test-backend-values.yaml > /tmp/backend-render.yaml
success "Backend-only rendering succeeded"

# Check for backend resources
grep -q "kind: Deployment" /tmp/backend-render.yaml && success "  - Deployment created"
grep -q "testapp-backend" /tmp/backend-render.yaml && success "  - Backend name correct"
grep -q "data-class: medium" /tmp/backend-render.yaml && success "  - data-class label present"
grep -q "kind: Service" /tmp/backend-render.yaml && success "  - Service created"
grep -q "kind: NetworkPolicy" /tmp/backend-render.yaml && success "  - NetworkPolicy created"

# Check frontend NOT rendered
if grep -q "testapp-frontend" /tmp/backend-render.yaml; then
    error "Frontend resources found when frontend.enabled=false"
fi
success "  - Frontend correctly disabled"

echo ""
echo "Step 7: Testing chart with both frontend and backend enabled..."
cat > /tmp/test-full-values.yaml <<EOF
project: testapp
environment: dev

keycloak:
  enabled: true
  authUrl: "https://sso.gov.bc.ca/auth"
  realm: "test-realm"
  clientId: "testapp"

database:
  enabled: true
  connectionString: "Host=postgres;Database=testdb"

frontend:
  enabled: true
  image:
    repository: sookeke/react-baseapp
    tag: "nextjs"
  service:
    port: 8000
  route:
    enabled: true
    host: test-frontend.apps.gov.bc.ca
  dataClass: "medium"
  replicaCount: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10

backend:
  enabled: true
  image:
    repository: sookeke/web-api
    tag: "v2"
  service:
    port: 8080
  dataClass: "high"
  replicaCount: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
EOF

helm template testapp . --values /tmp/test-full-values.yaml > /tmp/full-render.yaml
success "Full-stack rendering succeeded"

# Check both frontend and backend
grep -q "testapp-frontend" /tmp/full-render.yaml && success "  - Frontend resources present"
grep -q "testapp-backend" /tmp/full-render.yaml && success "  - Backend resources present"
grep -q "kind: HorizontalPodAutoscaler" /tmp/full-render.yaml && success "  - HPA created"

# Count deployments (should have 2: frontend and backend)
DEPLOY_COUNT=$(grep -c "kind: Deployment" /tmp/full-render.yaml || true)
if [ "$DEPLOY_COUNT" -eq 2 ]; then
    success "  - Correct number of deployments (2)"
else
    error "Expected 2 deployments, found $DEPLOY_COUNT"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}All tests passed!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - ag-helm shared library integration: ✓"
echo "  - Frontend conditional rendering: ✓"
echo "  - Backend conditional rendering: ✓"
echo "  - Full-stack rendering: ✓"
echo "  - Data classification labels: ✓"
echo "  - Resource independence: ✓"
echo ""
echo "Chart refactoring to unified structure: SUCCESS"
