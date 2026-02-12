#!/usr/bin/env bash
set -euo pipefail

# Tests the Conftest policy that blocks unapproved edge-terminated OpenShift Routes.
# Expected behavior:
# 1) Unapproved edge-terminated Route => conftest FAIL
# 2) Approved edge-terminated Route   => conftest PASS

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_DIR="${ROOT_DIR}/charts/{{cookiecutter.charts_dir}}/policy"

CONFTEST_BIN=""
if command -v conftest >/dev/null 2>&1; then
  CONFTEST_BIN="conftest"
elif [[ -f "${ROOT_DIR}/conftest.exe" ]]; then
  CONFTEST_BIN="${ROOT_DIR}/conftest.exe"
elif [[ -f "${ROOT_DIR}/test-output/conftest.exe" ]]; then
  CONFTEST_BIN="${ROOT_DIR}/test-output/conftest.exe"
else
  echo "conftest not found. Run test-all-validations.sh/.bat first (it downloads conftest), or install conftest." >&2
  exit 2
fi

TMP_DIR="${ROOT_DIR}/test-output/route-policy-test"
mkdir -p "${TMP_DIR}"

BAD="${TMP_DIR}/bad-edge-route.yaml"
GOOD="${TMP_DIR}/good-edge-route.yaml"

cat >"${BAD}" <<'YAML'
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: internal-api
  namespace: unit-test
  labels:
    app.kubernetes.io/component: backend
spec:
  host: internal-api.example.invalid
  to:
    kind: Service
    name: internal-api
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
YAML

cat >"${GOOD}" <<'YAML'
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: public-entry
  namespace: unit-test
  labels:
    app.kubernetes.io/component: backend
  annotations:
    isb.gov.bc.ca/edge-termination-approval: "ISB-UNIT-TEST"
spec:
  host: public-entry.example.invalid
  to:
    kind: Service
    name: public-entry
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
YAML

echo "=== [1/2] Expect FAIL: unapproved edge-terminated Route ==="
set +e
"${CONFTEST_BIN}" test "${BAD}" --policy "${POLICY_DIR}" --output table
bad_rc=$?
set -e
if [[ ${bad_rc} -eq 0 ]]; then
  echo "ERROR: Expected conftest to FAIL, but it PASSED." >&2
  exit 1
fi
echo "OK: conftest failed as expected."

echo
echo "=== [2/2] Expect PASS: approved edge-terminated Route ==="
"${CONFTEST_BIN}" test "${GOOD}" --policy "${POLICY_DIR}" --output table

echo
echo "SUCCESS: Edge-termination Route policy behaves correctly."
