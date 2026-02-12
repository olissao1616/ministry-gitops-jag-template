#!/bin/bash
set -e

echo "=========================================="
echo "Complete GitOps Template Deployment Test"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

# Function to print info
info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Change to repo root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

info "Step 1: Cleaning up any existing deployments..."
helm uninstall testapp -n default 2>/dev/null || true
kubectl delete pods,svc,hpa,deploy,statefulset -n default -l app.kubernetes.io/instance=testapp 2>/dev/null || true
success "Cleanup complete"

echo ""
info "Step 2: Checking ag-helm shared library..."
if [ ! -d "shared-lib/ag-helm" ]; then
    error "ag-helm library not found"
fi
success "ag-helm library found"

echo ""
info "Step 3: Setting up shared library..."
rm -rf /tmp/shared-lib
mkdir -p /tmp/shared-lib
cp -r shared-lib/ag-helm /tmp/shared-lib/
success "Shared library copied"

echo ""
info "Step 4: Generating charts with cookiecutter..."
rm -rf /tmp/test-deployment
cd charts
cookiecutter . --no-input \
    app_name=testapp \
    licence_plate=test123 \
    charts_dir=testapp-charts \
    --output-dir /tmp/test-deployment
success "Charts generated"

echo ""
info "Step 5: Generating deploy configs with cookiecutter..."
cd ../deploy
cookiecutter . --no-input \
    app_name=testapp \
    licence_plate=test123 \
    deploy_dir=testapp-deploy \
    team_name=testteam \
    project_name=testproject \
    --output-dir /tmp/test-deployment
success "Deploy configs generated"

echo ""
info "Step 6: Updating Helm dependencies..."
cd /tmp/test-deployment/testapp-charts/gitops
helm dependency update > /dev/null 2>&1
success "Dependencies updated"

echo ""
info "Step 7: Deploying with Helm using dev_values.yaml..."
helm install testapp . \
    --values /tmp/test-deployment/testapp-deploy/dev_values.yaml \
    --set frontend.route.enabled=false \
    --namespace default \
    --wait \
    --timeout 3m
success "Helm deployment complete"

echo ""
info "Step 8: Waiting for all pods to be ready..."
sleep 10
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=app -n default --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=testapp -n default --timeout=120s 2>/dev/null || true

echo ""
echo "=========================================="
echo "Deployment Status:"
echo "=========================================="
kubectl get pods,svc,hpa,deploy,statefulset -n default -o wide | grep -E "NAME|app-|testapp-"

echo ""
echo "=========================================="
echo "Verification:"
echo "=========================================="

# Check frontend
FRONTEND_READY=$(kubectl get deploy app-react-baseapp -n default -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$FRONTEND_READY" = "1" ]; then
    success "Frontend: 1/1 READY"
else
    error "Frontend: NOT READY"
fi

# Check backend
BACKEND_READY=$(kubectl get deploy app-web-api -n default -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$BACKEND_READY" = "1" ]; then
    success "Backend: 1/1 READY"
else
    error "Backend: NOT READY"
fi

# Check postgres
POSTGRES_READY=$(kubectl get statefulset testapp-postgresql -n default -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$POSTGRES_READY" = "1" ]; then
    success "PostgreSQL: 1/1 READY"
else
    error "PostgreSQL: NOT READY"
fi

# Check HPAs
HPA_COUNT=$(kubectl get hpa -n default -o name 2>/dev/null | wc -l)
if [ "$HPA_COUNT" -ge "2" ]; then
    success "HPAs: $HPA_COUNT deployed"
else
    error "HPAs: Expected 2, found $HPA_COUNT"
fi

# Check services
SERVICE_COUNT=$(kubectl get svc -n default -o name 2>/dev/null | grep -c "app-\|testapp-postgresql" || echo "0")
if [ "$SERVICE_COUNT" -ge "4" ]; then
    success "Services: $SERVICE_COUNT deployed"
else
    error "Services: Expected 4+, found $SERVICE_COUNT"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}ALL TESTS PASSED!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Cookiecutter generation: SUCCESS"
echo "  ✓ Helm deployment: SUCCESS"
echo "  ✓ Frontend: RUNNING"
echo "  ✓ Backend: RUNNING"
echo "  ✓ PostgreSQL: RUNNING"
echo "  ✓ HPAs: DEPLOYED"
echo "  ✓ Services: DEPLOYED"
echo ""
echo "Template is ready for production use!"
echo ""
echo "To cleanup:"
echo "  helm uninstall testapp -n default"
echo ""
