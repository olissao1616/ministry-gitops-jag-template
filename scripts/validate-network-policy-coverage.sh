#!/bin/bash

# Validate that all deployments have corresponding network policies
# Usage: bash scripts/validate-network-policy-coverage.sh <namespace>

NAMESPACE=${1:-"default"}

echo "========================================"
echo "Network Policy Coverage Validation"
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

# Get all deployments
TOTAL_DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)

if [ "$TOTAL_DEPLOYMENTS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No deployments found in namespace${NC}"
    exit 0
fi

echo "Checking $TOTAL_DEPLOYMENTS deployment(s):"
echo ""

COVERED_DEPLOYMENTS=0
UNCOVERED_DEPLOYMENTS=0

# Get all network policies
NETWORK_POLICIES=$(kubectl get networkpolicies -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name --no-headers 2>/dev/null)

# Check each deployment
kubectl get deployments -n "$NAMESPACE" --no-headers | while read -r line; do
    DEPLOY_NAME=$(echo "$line" | awk '{print $1}')

    # Check if there's a network policy with this name
    if echo "$NETWORK_POLICIES" | grep -q "$DEPLOY_NAME"; then
        echo -e "${GREEN}✓${NC} $DEPLOY_NAME - network policy exists"
        ((COVERED_DEPLOYMENTS++))
    else
        echo -e "${RED}✗${NC} $DEPLOY_NAME - NO network policy found"
        ((UNCOVERED_DEPLOYMENTS++))
    fi
done

# Read the counters (since the while loop runs in subshell)
COVERED_DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" --no-headers | while read -r line; do
    DEPLOY_NAME=$(echo "$line" | awk '{print $1}')
    if echo "$NETWORK_POLICIES" | grep -q "$DEPLOY_NAME"; then
        echo "1"
    fi
done | wc -l)

UNCOVERED_DEPLOYMENTS=$((TOTAL_DEPLOYMENTS - COVERED_DEPLOYMENTS))

echo ""
echo "========================================"
echo "Coverage Summary"
echo "========================================"
echo "Total Deployments: $TOTAL_DEPLOYMENTS"
echo -e "Covered: ${GREEN}$COVERED_DEPLOYMENTS${NC}"
echo -e "Uncovered: ${RED}$UNCOVERED_DEPLOYMENTS${NC}"

if [ "$TOTAL_DEPLOYMENTS" -gt 0 ]; then
    COVERAGE_PERCENT=$((COVERED_DEPLOYMENTS * 100 / TOTAL_DEPLOYMENTS))
    echo "Coverage: ${COVERAGE_PERCENT}%"
    echo ""

    if [ "$COVERAGE_PERCENT" -eq 100 ]; then
        echo -e "${GREEN}✓ All deployments have network policies${NC}"
        exit 0
    elif [ "$COVERAGE_PERCENT" -ge 80 ]; then
        echo -e "${YELLOW}⚠ Good coverage but some deployments are unprotected${NC}"
        exit 1
    else
        echo -e "${RED}✗ Low network policy coverage - action required${NC}"
        exit 1
    fi
else
    exit 0
fi
