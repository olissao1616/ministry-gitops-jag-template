#!/bin/bash
set -e

# Test script for refactored charts using ag-helm

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="/tmp/test-gitops-charts"

echo "🧪 Testing Refactored Charts with ag-helm"
echo "=========================================="
echo ""

# Clean up previous test
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# Test 1: Generate charts with cookiecutter
echo "📋 Step 1: Generating charts with cookiecutter..."
cd "$TEST_DIR"
cookiecutter "$ROOT_DIR/charts" \
  --no-input \
  licence_plate=test123 \
  app_name=testapp \
  team_name=test-team \
  project_name=test-project

echo "✅ Charts generated"
echo ""

# Test 2: Copy ag-helm library
echo "📋 Step 2: Setting up ag-helm library..."
mkdir -p "$TEST_DIR/shared-lib"
cp -r "$ROOT_DIR/shared-lib/ag-helm" "$TEST_DIR/shared-lib/"

# Fix dependency paths in generated charts
cd "$TEST_DIR/charts"
for chart in react-baseapp webapi-core; do
  if [ -d "$chart" ]; then
    sed -i 's|file://../../../shared-lib/ag-helm|file://../../shared-lib/ag-helm|g' "$chart/Chart.yaml"
  fi
done

echo "✅ ag-helm library configured"
echo ""

# Test 3: Test react-baseapp chart
echo "📋 Step 3: Testing react-baseapp chart..."
cd "$TEST_DIR/charts/react-baseapp"

helm dependency update
helm lint .
helm template test . --debug > /tmp/react-baseapp-render.yaml

# Check for required resources
grep -q "kind: Deployment" /tmp/react-baseapp-render.yaml || { echo "❌ Missing Deployment"; exit 1; }
grep -q "kind: Service" /tmp/react-baseapp-render.yaml || { echo "❌ Missing Service"; exit 1; }
grep -q "kind: NetworkPolicy" /tmp/react-baseapp-render.yaml || { echo "❌ Missing NetworkPolicy"; exit 1; }
grep -q "data-class:" /tmp/react-baseapp-render.yaml || { echo "❌ Missing data-class label"; exit 1; }

echo "✅ react-baseapp chart test passed"
echo ""

# Test 4: Test webapi-core chart
echo "📋 Step 4: Testing webapi-core chart..."
cd "$TEST_DIR/charts/webapi-core"

helm dependency update
helm lint .
helm template test . --debug > /tmp/webapi-core-render.yaml

# Check for required resources
grep -q "kind: Deployment" /tmp/webapi-core-render.yaml || { echo "❌ Missing Deployment"; exit 1; }
grep -q "kind: Service" /tmp/webapi-core-render.yaml || { echo "❌ Missing Service"; exit 1; }
grep -q "data-class:" /tmp/webapi-core-render.yaml || { echo "❌ Missing data-class label"; exit 1; }

echo "✅ webapi-core chart test passed"
echo ""

echo "=========================================="
echo "✨ All refactored charts passed!"
echo "=========================================="
echo ""
echo "📁 Generated charts location: $TEST_DIR/charts"
echo "📄 Rendered templates:"
echo "  - /tmp/react-baseapp-render.yaml"
echo "  - /tmp/webapi-core-render.yaml"
