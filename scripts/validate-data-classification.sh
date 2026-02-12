#!/bin/bash

# Validate that all pods have proper DataClass labels
# Usage: bash scripts/validate-data-classification.sh <namespace>

NAMESPACE=${1:-"default"}

echo "========================================"
echo "Data Classification Validation"
echo "Namespace: $NAMESPACE"
echo "========================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}✗ Namespace $NAMESPACE does not exist${NC}"
    exit 1
fi

# Get all pods
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)

if [ "$TOTAL_PODS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No pods found in namespace${NC}"
    exit 0
fi

echo "Checking $TOTAL_PODS pod(s):"
echo ""

# Check pods without DataClass label
MISSING_COUNT=$(kubectl get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,DATACLASS:.metadata.labels.DataClass --no-headers 2>/dev/null | grep "<none>" | wc -l)

if [ "$MISSING_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Pods without DataClass label ($MISSING_COUNT):${NC}"
    kubectl get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,DATACLASS:.metadata.labels.DataClass --no-headers | grep "<none>" | awk '{print "  - " $1}'
    echo ""
fi

# Check pods with valid vs invalid DataClass
LOW_COUNT=$(kubectl get pods -n "$NAMESPACE" -o custom-columns=DATACLASS:.metadata.labels.DataClass --no-headers 2>/dev/null | grep "^Low$" | wc -l)
MEDIUM_COUNT=$(kubectl get pods -n "$NAMESPACE" -o custom-columns=DATACLASS:.metadata.labels.DataClass --no-headers 2>/dev/null | grep "^Medium$" | wc -l)
HIGH_COUNT=$(kubectl get pods -n "$NAMESPACE" -o custom-columns=DATACLASS:.metadata.labels.DataClass --no-headers 2>/dev/null | grep "^High$" | wc -l)

# Count invalid (not Low, Medium, High, or <none>)
VALID_COUNT=$((LOW_COUNT + MEDIUM_COUNT + HIGH_COUNT))
WITH_LABEL=$((TOTAL_PODS - MISSING_COUNT))
INVALID_COUNT=$((WITH_LABEL - VALID_COUNT))

if [ "$INVALID_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Pods with invalid DataClass ($INVALID_COUNT):${NC}"
    kubectl get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,DATACLASS:.metadata.labels.DataClass --no-headers | \
        grep -v "<none>" | grep -v "Low" | grep -v "Medium" | grep -v "High" | awk '{print "  - " $1 ": " $2}'
    echo ""
fi

# Show distribution of valid classifications
echo "Data Classification Distribution:"
if [ "$LOW_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}Low:${NC} $LOW_COUNT pod(s)"
fi
if [ "$MEDIUM_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}Medium:${NC} $MEDIUM_COUNT pod(s)"
fi
if [ "$HIGH_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}High:${NC} $HIGH_COUNT pod(s)"
fi
if [ "$MISSING_COUNT" -gt 0 ]; then
    echo -e "  ${RED}None:${NC} $MISSING_COUNT pod(s)"
fi
if [ "$INVALID_COUNT" -gt 0 ]; then
    echo -e "  ${RED}Invalid:${NC} $INVALID_COUNT pod(s)"
fi
echo ""

# Summary
echo "========================================"
echo "Validation Summary"
echo "========================================"
echo "Total Pods: $TOTAL_PODS"
echo -e "Valid Classification: ${GREEN}$VALID_COUNT${NC}"
echo -e "Missing DataClass: ${RED}$MISSING_COUNT${NC}"
echo -e "Invalid DataClass: ${RED}$INVALID_COUNT${NC}"
echo ""

# Exit code
ISSUES=$((MISSING_COUNT + INVALID_COUNT))
if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}✓ All pods have valid data classification${NC}"
    exit 0
else
    echo -e "${RED}✗ Data classification issues found - action required${NC}"
    echo ""
    echo "Required actions:"
    if [ "$MISSING_COUNT" -gt 0 ]; then
        echo "  1. Add DataClass label (Low/Medium/High) to all pods"
        echo "     Example in values.yaml:"
        echo "       podLabels:"
        echo "         DataClass: \"Medium\""
        echo "         data-class: \"medium\""
    fi
    if [ "$INVALID_COUNT" -gt 0 ]; then
        echo "  2. Fix invalid DataClass values (must be: Low, Medium, or High)"
    fi
    exit 1
fi
