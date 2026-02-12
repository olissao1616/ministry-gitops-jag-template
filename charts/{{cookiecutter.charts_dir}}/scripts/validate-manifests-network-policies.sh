#!/bin/bash

# Validate network policies in rendered Helm manifests (for CI/CD)
# Usage: bash scripts/validate-manifests-network-policies.sh <rendered-manifests.yaml>

MANIFEST_FILE=${1}

if [ -z "$MANIFEST_FILE" ]; then
    echo "Usage: bash scripts/validate-manifests-network-policies.sh <rendered-manifests.yaml>"
    exit 1
fi

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: File $MANIFEST_FILE not found"
    exit 1
fi

echo "========================================"
echo "Network Policy Manifest Validation"
echo "File: $MANIFEST_FILE"
echo "========================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

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

# Test 1: Check if NetworkPolicy resources exist
echo "Test 1: Check for NetworkPolicy resources"
NETWORK_POLICY_COUNT=$(grep "^kind: NetworkPolicy" "$MANIFEST_FILE" | wc -l)
if [ "$NETWORK_POLICY_COUNT" -gt 0 ]; then
    pass "Found $NETWORK_POLICY_COUNT NetworkPolicy resource(s)"
else
    fail "No NetworkPolicy resources found in manifests"
fi
echo ""

# Test 2: Check if Deployments exist
echo "Test 2: Check for Deployment resources"
DEPLOYMENT_COUNT=$(grep "^kind: Deployment" "$MANIFEST_FILE" | wc -l)
if [ "$DEPLOYMENT_COUNT" -gt 0 ]; then
    pass "Found $DEPLOYMENT_COUNT Deployment resource(s)"
else
    warn "No Deployment resources found"
fi
echo ""

# Test 3: Check policy types (Ingress and Egress)
echo "Test 3: Check NetworkPolicy has policyTypes defined"
POLICIES_WITH_TYPES=$(grep "^  policyTypes:" "$MANIFEST_FILE" | wc -l)
if [ "$POLICIES_WITH_TYPES" -eq "$NETWORK_POLICY_COUNT" ]; then
    pass "All $NETWORK_POLICY_COUNT NetworkPolicies define policyTypes"
elif [ "$POLICIES_WITH_TYPES" -gt 0 ]; then
    warn "$POLICIES_WITH_TYPES out of $NETWORK_POLICY_COUNT NetworkPolicies define policyTypes"
else
    fail "No policyTypes defined in NetworkPolicies"
fi
echo ""

# Test 4: Check for DataClass labels in Deployments (simplified check)
echo "Test 4: Check DataClass labels exist"
DATACLASS_IN_PODS=$(grep "DataClass:" "$MANIFEST_FILE" | wc -l)
if [ "$DATACLASS_IN_PODS" -ge "$DEPLOYMENT_COUNT" ]; then
    pass "Found DataClass labels ($DATACLASS_IN_PODS instances)"
else
    fail "Insufficient DataClass labels (found $DATACLASS_IN_PODS, need at least $DEPLOYMENT_COUNT)"
fi
echo ""

# Test 5: Check for valid DataClass values
echo "Test 5: Validate DataClass values (Low/Medium/High)"
TOTAL_DATACLASS=$(grep "DataClass:" "$MANIFEST_FILE" | wc -l)
VALID_DATACLASS=$(grep "DataClass:" "$MANIFEST_FILE" | grep -E "Low|Medium|High" | wc -l)

if [ "$TOTAL_DATACLASS" -eq "$VALID_DATACLASS" ]; then
    pass "All DataClass labels have valid values"
else
    INVALID=$((TOTAL_DATACLASS - VALID_DATACLASS))
    fail "Found $INVALID invalid DataClass value(s)"
    grep "DataClass:" "$MANIFEST_FILE" | grep -v "Low" | grep -v "Medium" | grep -v "High" | head -3
fi
echo ""

# Test 6: Check for podSelector in NetworkPolicies
echo "Test 6: Check NetworkPolicies have podSelectors"
POLICIES_WITH_SELECTOR=$(grep "^  podSelector:" "$MANIFEST_FILE" | wc -l)
if [ "$POLICIES_WITH_SELECTOR" -eq "$NETWORK_POLICY_COUNT" ]; then
    pass "All $NETWORK_POLICY_COUNT NetworkPolicies have podSelector"
else
    fail "Only $POLICIES_WITH_SELECTOR out of $NETWORK_POLICY_COUNT NetworkPolicies have podSelector"
fi
echo ""

# Test 7: Check for empty podSelector (dangerous)
echo "Test 7: Check for dangerous empty podSelectors"
EMPTY_SELECTOR=$(grep "podSelector: {}" "$MANIFEST_FILE" | wc -l)
if [ "$EMPTY_SELECTOR" -eq 0 ]; then
    pass "No empty podSelectors found (good)"
else
    fail "Found $EMPTY_SELECTOR empty podSelector(s) - matches ALL pods!"
fi
echo ""

# Test 8: Check for allow-all rules (dangerous)
echo "Test 8: Check for allow-all ingress/egress rules"
ALLOW_ALL=$(grep -E "ingress: \[\]|egress: \[\]" "$MANIFEST_FILE" | wc -l)

if [ "$ALLOW_ALL" -eq 0 ]; then
    pass "No allow-all rules found (good)"
else
    warn "Found $ALLOW_ALL allow-all rule(s) - review for security"
fi
echo ""

# Test 9: Coverage ratio
echo "Test 9: Network policy coverage"
if [ "$DEPLOYMENT_COUNT" -gt 0 ]; then
    if [ "$NETWORK_POLICY_COUNT" -ge "$DEPLOYMENT_COUNT" ]; then
        pass "NetworkPolicy count ($NETWORK_POLICY_COUNT) >= Deployment count ($DEPLOYMENT_COUNT)"
    else
        fail "Only $NETWORK_POLICY_COUNT NetworkPolicies for $DEPLOYMENT_COUNT Deployments"
    fi
else
    warn "No deployments found"
fi
echo ""

# Summary
echo "========================================"
echo "Validation Summary"
echo "========================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ ALL CHECKS PASSED - 100% ✓✓✓${NC}"
    exit 0
else
    echo -e "${RED}✗ VALIDATION FAILED - MUST BE 100% TO PASS${NC}"
    exit 1
fi
