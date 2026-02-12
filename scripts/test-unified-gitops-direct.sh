#!/bin/bash
set -e

echo "=========================================="
echo "Testing Unified GitOps Chart (Direct)"
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

GITOPS_CHART="charts/{{cookiecutter.charts_dir}}/gitops"

echo "Step 1: Checking chart structure..."
if [ ! -d "$GITOPS_CHART" ]; then
    error "GitOps chart not found at $GITOPS_CHART"
fi
success "GitOps chart found"

# Check for required template files
REQUIRED_TEMPLATES=(
    "frontend-deployment.yaml"
    "frontend-service.yaml"
    "frontend-networkpolicy.yaml"
    "frontend-route.yaml"
    "frontend-hpa.yaml"
    "frontend-serviceaccount.yaml"
    "backend-deployment.yaml"
    "backend-service.yaml"
    "backend-networkpolicy.yaml"
    "backend-ingress.yaml"
    "backend-hpa.yaml"
    "backend-serviceaccount.yaml"
)

for template in "${REQUIRED_TEMPLATES[@]}"; do
    if [ ! -f "$GITOPS_CHART/templates/$template" ]; then
        error "Missing template: $template"
    fi
done
success "All required templates present"

echo ""
echo "Step 2: Checking values.yaml structure..."
if ! grep -q "frontend:" "$GITOPS_CHART/values.yaml"; then
    error "frontend section not found in values.yaml"
fi
if ! grep -q "backend:" "$GITOPS_CHART/values.yaml"; then
    error "backend section not found in values.yaml"
fi
success "Values.yaml has frontend and backend sections"

echo ""
echo "Step 3: Checking ag-helm dependency..."
if ! grep -q "ag-helm-templates" "$GITOPS_CHART/Chart.yaml"; then
    error "ag-helm dependency not found in Chart.yaml"
fi
success "ag-helm dependency configured"

echo ""
echo "Step 4: Verifying templates use ag-helm..."
# Check that deployment templates use ag-template.deployment
if ! grep -q "ag-template.deployment" "$GITOPS_CHART/templates/frontend-deployment.yaml"; then
    error "frontend-deployment.yaml doesn't use ag-helm ag-template.deployment"
fi
if ! grep -q "ag-template.deployment" "$GITOPS_CHART/templates/backend-deployment.yaml"; then
    error "backend-deployment.yaml doesn't use ag-helm ag-template.deployment"
fi
success "Deployments use ag-helm shared library"

# Check that service templates use ag-template.service
if ! grep -q "ag-template.service" "$GITOPS_CHART/templates/frontend-service.yaml"; then
    error "frontend-service.yaml doesn't use ag-helm ag-template.service"
fi
if ! grep -q "ag-template.service" "$GITOPS_CHART/templates/backend-service.yaml"; then
    error "backend-service.yaml doesn't use ag-helm ag-template.service"
fi
success "Services use ag-helm shared library"

# Check that networkpolicy templates use ag-template.networkpolicy
if ! grep -q "ag-template.networkpolicy" "$GITOPS_CHART/templates/frontend-networkpolicy.yaml"; then
    error "frontend-networkpolicy.yaml doesn't use ag-helm ag-template.networkpolicy"
fi
if ! grep -q "ag-template.networkpolicy" "$GITOPS_CHART/templates/backend-networkpolicy.yaml"; then
    error "backend-networkpolicy.yaml doesn't use ag-helm ag-template.networkpolicy"
fi
success "NetworkPolicies use ag-helm shared library"

echo ""
echo "Step 5: Checking template conditionals..."
# Check that templates have proper conditionals
if ! grep -q "\.Values\.frontend\.enabled" "$GITOPS_CHART/templates/frontend-deployment.yaml"; then
    error "frontend-deployment.yaml missing conditional"
fi
if ! grep -q "\.Values\.backend\.enabled" "$GITOPS_CHART/templates/backend-deployment.yaml"; then
    error "backend-deployment.yaml missing conditional"
fi
success "Templates have proper conditionals"

echo ""
echo "Step 6: Verifying cookiecutter template syntax..."
# Check that templates use {% raw %} blocks for Helm syntax
if ! grep -q "{% raw %}" "$GITOPS_CHART/templates/frontend-deployment.yaml"; then
    error "frontend-deployment.yaml missing {% raw %} blocks"
fi
if ! grep -q "{% raw %}" "$GITOPS_CHART/templates/backend-deployment.yaml"; then
    error "backend-deployment.yaml missing {% raw %} blocks"
fi
success "Templates use proper {% raw %} blocks for cookiecutter"

echo ""
echo "Step 7: Checking dataClass configuration..."
# Check that dataClass is properly configured with lowercase values
if ! grep -q 'dataClass: "medium"' "$GITOPS_CHART/values.yaml"; then
    error "dataClass not properly configured in values.yaml"
fi
success "dataClass properly configured (lowercase)"

echo ""
echo "Step 8: Verifying Chart.yaml structure..."
cd "$GITOPS_CHART"

# Check dependencies
if ! grep -q "name: ag-helm-templates" "Chart.yaml"; then
    error "ag-helm-templates dependency not found"
fi
if ! grep -q "repository: file://../../../shared-lib/ag-helm" "Chart.yaml"; then
    error "ag-helm repository path incorrect"
fi
success "Chart dependencies correctly configured"

echo ""
echo "Step 9: Checking for old subchart references..."
# Make sure old react-baseapp and webapi-core dependencies are removed
if grep -q "name: react-baseapp" "Chart.yaml"; then
    error "Old react-baseapp dependency still present in Chart.yaml"
fi
if grep -q "name: webapi-core" "Chart.yaml"; then
    error "Old webapi-core dependency still present in Chart.yaml"
fi
success "Old subchart dependencies removed"

echo ""
echo "=========================================="
echo -e "${GREEN}All structure checks passed!${NC}"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Chart structure: ✓"
echo "  - Template files: ✓ (12 templates)"
echo "  - ag-helm integration: ✓"
echo "  - Conditionals: ✓"
echo "  - Cookiecutter syntax: ✓"
echo "  - Data classification: ✓"
echo "  - Dependencies: ✓"
echo ""
echo "Unified chart refactoring: COMPLETE"
echo ""
echo "Next steps:"
echo "  1. Run 'helm dependency update' in the gitops chart directory"
echo "  2. Test with 'helm template' using test values"
echo "  3. Remove old react-baseapp and webapi-core folders"
