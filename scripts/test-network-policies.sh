#!/bin/bash

# Test network policies in deployed namespace
# Usage: bash scripts/test-network-policies.sh <namespace> <release-name>

NAMESPACE=${1:-"default"}
RELEASE_NAME=${2:-"myapp"}

echo "========================================"
echo "Testing Network Policies"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "========================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Test 1: Check namespace exists
echo "Test 1: Verify namespace exists"
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    pass "Namespace $NAMESPACE exists"
else
    fail "Namespace $NAMESPACE does not exist"
    exit 1
fi
echo ""

# Test 2: Check network policies exist
echo "Test 2: Verify network policies are deployed"
NETWORK_POLICIES=$(kubectl get networkpolicies -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$NETWORK_POLICIES" -gt 0 ]; then
    pass "Found $NETWORK_POLICIES network policies"
    kubectl get networkpolicies -n "$NAMESPACE" --no-headers | awk '{print "  - " $1}'
else
    fail "No network policies found in namespace"
fi
echo ""

# Test 3: Check pods exist and are running
echo "Test 3: Check pod status"
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$TOTAL_PODS" -eq 0 ]; then
    warn "No pods found in namespace"
else
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep "Running" | wc -l)
    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
        pass "All $TOTAL_PODS pods are running"
    else
        warn "$RUNNING_PODS out of $TOTAL_PODS pods are running"
    fi
fi
echo ""

# Test 4: Check DataClass labels on pods
echo "Test 4: Verify DataClass labels on pods"
if [ "$TOTAL_PODS" -gt 0 ]; then
    PODS_WITH_DATACLASS=$(kubectl get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,DATACLASS:.metadata.labels.DataClass --no-headers 2>/dev/null | grep -v "<none>" | wc -l)

    if [ "$PODS_WITH_DATACLASS" -eq "$TOTAL_PODS" ]; then
        pass "All $TOTAL_PODS pods have DataClass labels"
    else
        MISSING=$((TOTAL_PODS - PODS_WITH_DATACLASS))
        fail "$MISSING out of $TOTAL_PODS pods missing DataClass label"
        echo "  Pods without DataClass:"
        kubectl get pods -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,DATACLASS:.metadata.labels.DataClass --no-headers | grep "<none>" | awk '{print "  - " $1}'
    fi
else
    warn "No pods to check"
fi
echo ""

# Test 5: Show data classification distribution
echo "Test 5: Data classification distribution"
if [ "$TOTAL_PODS" -gt 0 ]; then
    echo "  Distribution:"
    kubectl get pods -n "$NAMESPACE" -o custom-columns=DATACLASS:.metadata.labels.DataClass --no-headers 2>/dev/null | sort | uniq -c | awk '{print "  - " $2 ": " $1 " pod(s)"}'
    pass "Data classification check complete"
else
    warn "No pods to check"
fi
echo ""

# Test 6: Test DNS resolution
echo "Test 6: Test DNS resolution"
ANY_POD=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | head -n 1 | awk '{print $1}')
if [ -n "$ANY_POD" ]; then
    if kubectl exec "$ANY_POD" -n "$NAMESPACE" -- nslookup kubernetes.default &>/dev/null 2>&1; then
        pass "DNS resolution works"
    else
        warn "DNS resolution failed (pod may not have nslookup)"
    fi
else
    warn "No pods available to test DNS"
fi
echo ""

# Test 7: Check for network policy matching deployments
echo "Test 7: Check network policy coverage"
DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$DEPLOYMENTS" -gt 0 ]; then
    pass "Found $DEPLOYMENTS deployment(s) in namespace"

    # Check if we have network policies
    if [ "$NETWORK_POLICIES" -ge "$DEPLOYMENTS" ]; then
        pass "Network policy count ($NETWORK_POLICIES) >= deployment count ($DEPLOYMENTS)"
    else
        warn "Only $NETWORK_POLICIES network policies for $DEPLOYMENTS deployments"
    fi
else
    warn "No deployments found in namespace"
fi
echo ""

# Test 8: List all network policies and their pod selectors
echo "Test 8: Network policy details"
if [ "$NETWORK_POLICIES" -gt 0 ]; then
    echo "  Network Policies:"
    kubectl get networkpolicies -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,POD-SELECTOR:.spec.podSelector --no-headers | while read -r line; do
        echo "  - $line"
    done
    pass "Network policy details listed"
else
    warn "No network policies to display"
fi
echo ""

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All critical tests passed${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
