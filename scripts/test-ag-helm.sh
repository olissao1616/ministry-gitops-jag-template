#!/bin/bash
set -e

# Test script for ag-helm shared library

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🧪 Testing ag-helm Shared Library"
echo "=================================="
echo ""

# Test 1: Lint ag-helm library
echo "📋 Test 1: Linting ag-helm library..."
cd "$ROOT_DIR/shared-lib/ag-helm"
helm lint .
echo "✅ ag-helm lint passed"
echo ""

# Test 2: Test with example-app
echo "📋 Test 2: Testing with example-app..."
cd "$ROOT_DIR/shared-lib/example-app"

# Update dependencies
echo "  → Updating dependencies..."
helm dependency update

# Lint example-app
echo "  → Linting example-app..."
helm lint .

# Template with example values
echo "  → Templating with example values..."
helm template test . --values values-examples.yaml --debug > /tmp/example-app-render.yaml
echo "  → Rendered output saved to /tmp/example-app-render.yaml"

# Check for required components
echo "  → Verifying required Kubernetes resources..."
grep -q "kind: Deployment" /tmp/example-app-render.yaml || { echo "❌ Missing Deployment"; exit 1; }
grep -q "kind: Service" /tmp/example-app-render.yaml || { echo "❌ Missing Service"; exit 1; }
grep -q "kind: NetworkPolicy" /tmp/example-app-render.yaml || { echo "❌ Missing NetworkPolicy"; exit 1; }
grep -q "data-class:" /tmp/example-app-render.yaml || { echo "❌ Missing data-class label"; exit 1; }

echo "✅ example-app test passed"
echo ""

# Test 3: Validate data-class labels
echo "📋 Test 3: Validating data-class labels..."
if grep -q 'data-class: "low"' /tmp/example-app-render.yaml && \
   grep -q 'data-class: "medium"' /tmp/example-app-render.yaml; then
    echo "✅ Data-class labels are correct"
else
    echo "❌ Data-class labels validation failed"
    exit 1
fi
echo ""

# Test 4: Check for standard labels
echo "📋 Test 4: Checking for standard labels..."
if grep -q "app.kubernetes.io/name:" /tmp/example-app-render.yaml && \
   grep -q "app.kubernetes.io/part-of:" /tmp/example-app-render.yaml; then
    echo "✅ Standard Kubernetes labels present"
else
    echo "❌ Missing standard labels"
    exit 1
fi
echo ""

echo "=================================="
echo "✨ All tests passed!"
echo "=================================="
