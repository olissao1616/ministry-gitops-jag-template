#!/bin/bash
# Quick test to verify ag-helm-templates can be pulled from GHCR

set -e

echo "=========================================="
echo "Testing ag-helm-templates from GHCR"
echo "=========================================="
echo ""

# Test 1: Show chart info
echo "[1/3] Fetching chart metadata..."
helm show chart oci://ghcr.io/olissao1616/helm/ag-helm-templates --version 1.0.3
echo ""

# Test 2: Pull the chart
echo "[2/3] Pulling chart package..."
rm -f ag-helm-templates-1.0.3.tgz
helm pull oci://ghcr.io/olissao1616/helm/ag-helm-templates --version 1.0.3
ls -lh ag-helm-templates-1.0.3.tgz
echo ""

# Test 3: Verify chart contents
echo "[3/3] Extracting and verifying chart contents..."
tar -tzf ag-helm-templates-1.0.3.tgz | head -20
echo ""

echo "✅ SUCCESS! ag-helm-templates is working from GHCR"
echo ""
echo "Package: oci://ghcr.io/olissao1616/helm/ag-helm-templates:1.0.3"
echo "Size: $(du -h ag-helm-templates-1.0.3.tgz | cut -f1)"
echo ""
echo "To use in your Chart.yaml:"
echo "dependencies:"
echo "  - name: ag-helm-templates"
echo "    version: \"1.0.3\""
echo "    repository: \"oci://ghcr.io/olissao1616/helm\""
echo ""

# Cleanup
rm -f ag-helm-templates-1.0.3.tgz
