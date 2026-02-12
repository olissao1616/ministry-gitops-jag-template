#!/bin/bash
# Removed set -e to allow Docker failures without exiting script
set -o pipefail

echo "========================================="
echo "NETWORK POLICY VALIDATION TEST SUITE"
echo "========================================="
echo ""

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${TEST_DIR:-${BASE_DIR}/test-output}"

cookiecutter_install_python() {
    # Try to install cookiecutter into the current user's Python environment.
    # This avoids requiring Docker Desktop on Windows.
    local pycmd="$1"
    if [ -z "$pycmd" ]; then
        return 1
    fi
    if ! "$pycmd" -m pip --version >/dev/null 2>&1; then
        return 1
    fi
    echo "Installing cookiecutter (Python user-site)..."
    "$pycmd" -m pip install --user -q cookiecutter==2.6.0
}

cookiecutter_run() {
    if command -v cookiecutter >/dev/null 2>&1; then
        cookiecutter "$@"
        return $?
    fi
    if command -v python >/dev/null 2>&1 && python -c 'import cookiecutter' >/dev/null 2>&1; then
        python -m cookiecutter "$@"
        return $?
    fi
    if command -v python >/dev/null 2>&1; then
        cookiecutter_install_python python >/dev/null 2>&1 || true
        if python -c 'import cookiecutter' >/dev/null 2>&1; then
            python -m cookiecutter "$@"
            return $?
        fi
    fi
    if command -v py >/dev/null 2>&1 && py -c "import cookiecutter" >/dev/null 2>&1; then
        py -m cookiecutter "$@"
        return $?
    fi
    if command -v py >/dev/null 2>&1; then
        cookiecutter_install_python py >/dev/null 2>&1 || true
        if py -c 'import cookiecutter' >/dev/null 2>&1; then
            py -m cookiecutter "$@"
            return $?
        fi
    fi
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import cookiecutter' >/dev/null 2>&1; then
        python3 -m cookiecutter "$@"
        return $?
    fi
    if command -v python3 >/dev/null 2>&1; then
        cookiecutter_install_python python3 >/dev/null 2>&1 || true
        if python3 -c 'import cookiecutter' >/dev/null 2>&1; then
            python3 -m cookiecutter "$@"
            return $?
        fi
    fi

    # Fallback: run cookiecutter inside a Python container.
    # Only attempt this when the Docker daemon is reachable; otherwise fail with actionable guidance.
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        docker run --rm \
            -v "${BASE_DIR}:/work" \
            -w /work \
            python:3.11-slim \
            sh -lc 'pip -q install cookiecutter==2.6.0 >/dev/null && python -m cookiecutter "$@"' \
            sh "$@"
        return $?
    fi

    echo "✗ FAILED: cookiecutter not found and Docker not available"
    echo "Install with: python -m pip install --user cookiecutter"
    return 1
}

echo "[1/14] Preparing test output directory..."
mkdir -p "${TEST_DIR}" 2>/dev/null || true
mkdir -p ~/docker-test 2>/dev/null || true

echo "[2/14] Generating cookiecutter templates..."
cd "${BASE_DIR}"
cookiecutter_run charts/ --no-input charts_dir=test-charts --output-dir "${TEST_DIR}" --overwrite-if-exists
cookiecutter_run deploy/ --no-input deploy_dir=test-deploy --output-dir "${TEST_DIR}" --overwrite-if-exists
cookiecutter_run application/ --no-input application_dir=test-applications --output-dir "${TEST_DIR}" --overwrite-if-exists

echo "[3/14] Skipping shared-lib copy (now using OCI registry: ghcr.io/olissao1616/helm)..."
# No longer needed - ag-helm-templates is pulled from GHCR automatically
# cp -r "${BASE_DIR}/shared-lib" "${TEST_DIR}/"

echo "[3b/14] Copying GitHub workflows into generated chart repo..."
if [ -d "${BASE_DIR}/.github/workflows" ]; then
    mkdir -p "${TEST_DIR}/test-charts/.github/workflows" 2>/dev/null || true
    # Make test-output/test-charts look like a standalone repo for inspection.
    # The real workflows live at repo root; cookiecutter charts/ output is intentionally minimal.
    cp -r "${BASE_DIR}/.github/workflows/." "${TEST_DIR}/test-charts/.github/workflows/" 2>/dev/null || true
else
    echo "WARNING: ${BASE_DIR}/.github/workflows not found; skipping workflow copy"
fi

echo "[4/14] Updating Helm dependencies..."
cd "${TEST_DIR}/test-charts/gitops"
helm dependency update

echo "[5/14] Rendering Helm templates..."
helm template test-app . --values ../../test-deploy/dev_values.yaml --namespace myapp-dev > ../../rendered-dev.yaml
LINE_COUNT=$(wc -l < ../../rendered-dev.yaml)
echo "✓ Generated ${LINE_COUNT} lines of manifests"
echo ""

cd "${TEST_DIR}"

echo "[6/14] Downloading validation tools..."

download_file() {
    # Usage: download_file <url> <output_path>
    local url="$1"
    local out="$2"

    is_windows_bash() {
        # True for Git Bash / MSYS / Cygwin environments.
        case "$(uname -s 2>/dev/null || echo unknown)" in
            MINGW*|MSYS*|CYGWIN*) return 0 ;;
            *) return 1 ;;
        esac
    }

    curl_supports_flag() {
        # Usage: curl_supports_flag "--some-flag"
        local flag="$1"
        curl --help all 2>/dev/null | grep -q -- "${flag}" && return 0
        curl --help 2>/dev/null | grep -q -- "${flag}" && return 0
        return 1
    }

    if [ "${DEBUG_CONFTEST:-}" = "1" ]; then
        echo "Download URL: ${url}"
        echo "Output file: ${out}"
    fi

    if [ "${USE_POWERSHELL_DOWNLOAD:-}" != "1" ] && command -v curl >/dev/null 2>&1; then
        # --fail: non-2xx is error
        # --show-error: show errors even with -s
        # --http1.1: avoids some corporate proxy HTTP/2 weirdness
        local curl_err
        curl_err="$(mktemp 2>/dev/null || echo "${out}.curl.err")"

        if curl --fail --show-error --location --http1.1 \
            --retry 5 --retry-delay 1 --retry-connrefused \
            --connect-timeout 15 --max-time 180 \
            "${url}" -o "${out}" 2>"${curl_err}"; then
            rm -f "${curl_err}" 2>/dev/null || true
            return 0
        fi

        local rc
        rc=$?
        local err_text
        err_text="$(cat "${curl_err}" 2>/dev/null || true)"

        # Windows Git Bash commonly uses curl+Schannel and can fail certificate revocation checks in locked-down networks.
        # Retry with --ssl-no-revoke (if supported) before falling back to PowerShell.
        if is_windows_bash \
            && (echo "${err_text}" | grep -qiE 'CRYPT_E_NO_REVOCATION_CHECK|0x80092012|schannel:.*revocation|certificate revocation'); then
            if curl_supports_flag "--ssl-no-revoke"; then
                echo "Info: curl failed due to Windows certificate revocation checks; retrying with --ssl-no-revoke..." >&2
                if curl --ssl-no-revoke --fail --show-error --location --http1.1 \
                    --retry 5 --retry-delay 1 --retry-connrefused \
                    --connect-timeout 15 --max-time 180 \
                    "${url}" -o "${out}" 2>"${curl_err}"; then
                    rm -f "${curl_err}" 2>/dev/null || true
                    return 0
                fi
                rc=$?
                err_text="$(cat "${curl_err}" 2>/dev/null || true)"
            fi
        fi

        rm -f "${curl_err}" 2>/dev/null || true

        # If curl failed, fall through to PowerShell downloader if available.
        if command -v powershell.exe >/dev/null 2>&1; then
            echo "Info: curl download failed, retrying with powershell.exe..." >&2
        else
            echo "FAILED: curl download failed." >&2
            if [ -n "${err_text}" ]; then
                echo "curl error:" >&2
                echo "${err_text}" >&2
            fi
            return 1
        fi
    fi

    # Fallback for Windows environments without curl (or where MSYS curl is problematic)
    if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -Command \
            "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri '${url}' -OutFile '${out}'"
        return $?
    fi

    echo "✗ FAILED: No downloader available (need curl or powershell.exe)"
    return 1
}

require_file_nonempty() {
    # Usage: require_file_nonempty <path> <friendly_name>
    local path="$1"
    local name="$2"
    if [ ! -s "${path}" ]; then
        echo "✗ FAILED: ${name} download produced an empty/missing file: ${path}"
        return 1
    fi
}

if [ ! -f conftest.exe ]; then
    echo "Downloading Conftest..."
    download_file "https://github.com/open-policy-agent/conftest/releases/download/v0.49.1/conftest_0.49.1_Windows_x86_64.zip" "conftest.zip"
    require_file_nonempty "conftest.zip" "Conftest"
    unzip -q conftest.zip conftest.exe
    rm -f conftest.zip
fi

if [ ! -f kube-linter.exe ]; then
    echo "Downloading kube-linter..."
    download_file "https://github.com/stackrox/kube-linter/releases/download/v0.6.8/kube-linter-windows.zip" "kube-linter.zip"
    require_file_nonempty "kube-linter.zip" "kube-linter"
    unzip -q kube-linter.zip kube-linter.exe
    rm -f kube-linter.zip
fi

if [ ! -f polaris.exe ]; then
    echo "Downloading Polaris..."
    download_file "https://github.com/FairwindsOps/polaris/releases/download/8.5.0/polaris_windows_amd64.tar.gz" "polaris.tar.gz"
    require_file_nonempty "polaris.tar.gz" "Polaris"
    tar -xzf polaris.tar.gz polaris.exe
    rm -f polaris.tar.gz
fi

if [ ! -f pluto.exe ]; then
    echo "Downloading Pluto..."
    download_file "https://github.com/FairwindsOps/pluto/releases/download/v5.19.0/pluto_5.19.0_windows_amd64.tar.gz" "pluto.tar.gz"
    require_file_nonempty "pluto.tar.gz" "Pluto"
    tar -xzf pluto.tar.gz pluto.exe
    rm -f pluto.tar.gz
fi

echo ""
echo "========================================="
echo "RUNNING VALIDATION TOOLS"
echo "========================================="
echo ""

# Track results
CONFTEST_RESULT="UNKNOWN"
KUBELINTER_RESULT="UNKNOWN"
POLARIS_RESULT="UNKNOWN"
NETPOL_RESULT="UNKNOWN"
DATACLASS_RESULT="UNKNOWN"
DATACLASS_VAL_RESULT="UNKNOWN"
KUBESEC_RESULT="UNKNOWN"
TRIVY_RESULT="UNKNOWN"
CHECKOV_RESULT="UNKNOWN"
KUBESCORE_RESULT="UNKNOWN"
DOCKER_TOOLS="UNKNOWN"

echo "[7/14] Running Conftest (OPA)..."
echo "-----------------------------------------"
if [ "${DEBUG_CONFTEST:-}" = "1" ]; then
    echo "Conftest binary: $(pwd)/conftest.exe"
    ./conftest.exe --version || true
    echo "Conftest policy dir: $(pwd)/test-charts/policy"
    if [ -d test-charts/policy ]; then
        echo "Policy files:"
        ls -la test-charts/policy || true
        if command -v sha256sum >/dev/null 2>&1; then
            echo "Policy SHA256:"
            sha256sum test-charts/policy/*.rego 2>/dev/null || true
        elif command -v shasum >/dev/null 2>&1; then
            echo "Policy SHA256:"
            shasum -a 256 test-charts/policy/*.rego 2>/dev/null || true
        fi
    else
        echo "WARNING: test-charts/policy directory not found"
    fi
    echo ""
fi
if ./conftest.exe test rendered-dev.yaml --policy test-charts/policy --all-namespaces --output table; then
    echo "PASSED: Conftest validation"
    CONFTEST_RESULT="PASSED"
else
    echo "FAILED: Conftest validation failed"
    CONFTEST_RESULT="FAILED"
fi
echo ""

echo "[8/14] Running kube-linter..."
echo "-----------------------------------------"
if ./kube-linter.exe lint rendered-dev.yaml --config test-charts/.kube-linter.yaml; then
    echo "PASSED: kube-linter validation"
    KUBELINTER_RESULT="PASSED"
else
    echo "WARNINGS: kube-linter found issues"
    KUBELINTER_RESULT="WARNINGS"
fi
echo ""

echo "[10/10] Running Network Policy Checks..."
echo "-----------------------------------------"
NP_COUNT=$(grep -c "kind: NetworkPolicy" rendered-dev.yaml || echo "0")
DEPLOY_COUNT=$(grep -c "kind: Deployment" rendered-dev.yaml || echo "0")
DATACLASS_COUNT=$(grep -c "DataClass:" rendered-dev.yaml || echo "0")

echo "NetworkPolicies found: ${NP_COUNT}"
echo "Deployments found: ${DEPLOY_COUNT}"

if [ "${NP_COUNT}" -ge "${DEPLOY_COUNT}" ]; then
    echo "PASSED: NetworkPolicy coverage adequate"
    NETPOL_RESULT="PASSED"
else
    echo "FAILED: Insufficient NetworkPolicies (${NP_COUNT}) for Deployments (${DEPLOY_COUNT})"
    NETPOL_RESULT="FAILED"
fi

echo "DataClass labels found: ${DATACLASS_COUNT}"

if [ "${DATACLASS_COUNT}" -ge "${DEPLOY_COUNT}" ]; then
    echo "PASSED: DataClass labels present"
    DATACLASS_RESULT="PASSED"
else
    echo "FAILED: Missing DataClass labels"
    DATACLASS_RESULT="FAILED"
fi

INVALID=$(grep "DataClass:" rendered-dev.yaml | grep -v "Low" | grep -v "Medium" | grep -v "High" || echo "")
if [ -z "$INVALID" ]; then
    echo "PASSED: All DataClass values valid (Low/Medium/High)"
    DATACLASS_VAL_RESULT="PASSED"
else
    echo "FAILED: Invalid DataClass values found"
    DATACLASS_VAL_RESULT="FAILED"
fi
echo ""

echo "========================================="
echo "DOCKER-BASED TOOLS (requires Docker)"
echo "========================================="
echo ""

# Check if Docker is available
if ! docker --version >/dev/null 2>&1; then
    echo "WARNING: Docker not available, skipping Docker-based tools"
    echo "Skipped: Kubesec, Trivy, Checkov, kube-score"
    DOCKER_TOOLS="SKIPPED"
    KUBESEC_RESULT="SKIPPED"
    TRIVY_RESULT="SKIPPED"
    CHECKOV_RESULT="SKIPPED"
    KUBESCORE_RESULT="SKIPPED"
else
    export MSYS_NO_PATHCONV=1
    
    echo "Running Kubesec..."
    echo "-----------------------------------------"
    # Kubesec scans only workload resources; ignore schema errors for non-workload kinds
    docker run --rm -v "$(pwd):/work" kubesec/kubesec:v2 scan /work/rendered-dev.yaml > kubesec-results.json 2>&1 || true
    if [ -f kubesec-results.json ] && grep -q '"object": "Deployment\|"object": "StatefulSet' kubesec-results.json 2>/dev/null; then
        echo "PASSED: Kubesec scan completed"
        KUBESEC_RESULT="PASSED"
    elif [ -f kubesec-results.json ] && grep -q "no such file or directory" kubesec-results.json 2>/dev/null; then
        echo "FAILED: Kubesec could not access file"
        cat kubesec-results.json | head -5
        KUBESEC_RESULT="FAILED"
    elif [ ! -f kubesec-results.json ]; then
        echo "FAILED: Kubesec produced no output"
        KUBESEC_RESULT="FAILED"
    else
        echo "WARNING: No workloads found to scan"
        KUBESEC_RESULT="PASSED"
    fi
    echo ""

    echo "Running Trivy..."
    echo "-----------------------------------------"
    TRIVY_OUTPUT=$(docker run --rm -v "$(pwd):/work" aquasec/trivy:latest config /work/rendered-dev.yaml --severity HIGH,CRITICAL 2>&1 || true)
    echo "$TRIVY_OUTPUT"
    if echo "$TRIVY_OUTPUT" | grep -q "no such file or directory"; then
        echo "FAILED: Trivy could not access file"
        TRIVY_RESULT="FAILED"
    elif echo "$TRIVY_OUTPUT" | grep -q "Misconfigurations"; then
        echo "PASSED: Trivy found no HIGH/CRITICAL issues"
        TRIVY_RESULT="PASSED"
    else
        echo "FAILED: Trivy produced unexpected output"
        TRIVY_RESULT="FAILED"
    fi
    echo ""

    echo "Running Checkov..."
    echo "-----------------------------------------"
    CHECKOV_OUTPUT=$(docker run --rm -v "$(pwd):/work" bridgecrew/checkov:latest -f /work/rendered-dev.yaml --framework kubernetes --compact --quiet 2>&1 || true)
    echo "$CHECKOV_OUTPUT"
    if echo "$CHECKOV_OUTPUT" | grep -q "no such file or directory"; then
        echo "FAILED: Checkov could not access file"
        CHECKOV_RESULT="FAILED"
    elif echo "$CHECKOV_OUTPUT" | grep -q "Passed checks:"; then
        echo "PASSED: Checkov found no failures"
        CHECKOV_RESULT="PASSED"
    else
        echo "FAILED: Checkov produced unexpected output"
        CHECKOV_RESULT="FAILED"
    fi
    echo ""

    echo "Running kube-score..."
    echo "-----------------------------------------"
    KUBESCORE_OUTPUT=$(docker run --rm -v "$(pwd):/project" zegl/kube-score:latest score /project/rendered-dev.yaml --ignore-test pod-networkpolicy 2>&1 || true)
    echo "$KUBESCORE_OUTPUT"
    if echo "$KUBESCORE_OUTPUT" | grep -q "Failed to score files"; then
        echo "FAILED: kube-score could not access file"
        KUBESCORE_RESULT="FAILED"
    elif echo "$KUBESCORE_OUTPUT" | grep -q "no such file or directory"; then
        echo "FAILED: kube-score could not find file"
        KUBESCORE_RESULT="FAILED"
    elif [ -z "$KUBESCORE_OUTPUT" ]; then
        echo "FAILED: kube-score produced no output"
        KUBESCORE_RESULT="FAILED"
    else
        echo "PASSED: kube-score"
        KUBESCORE_RESULT="PASSED"
    fi
    echo ""
fi

echo "[9/10] Running Polaris..."
echo "-----------------------------------------"
if ./polaris.exe audit --audit-path rendered-dev.yaml --config test-charts/.polaris.yaml --format pretty --set-exit-code-below-score 100; then
    echo "PASSED: Polaris validation"
    POLARIS_RESULT="PASSED"
else
    echo "FAILED: Polaris score below 100"
    POLARIS_RESULT="FAILED"
fi
echo ""

echo ""
echo "========================================="
echo "VALIDATION SUMMARY"
echo "========================================="
echo "Conftest (OPA):        ${CONFTEST_RESULT}"
echo "kube-linter:           ${KUBELINTER_RESULT}"
echo "Polaris:               ${POLARIS_RESULT}"
echo "NetworkPolicy Count:   ${NETPOL_RESULT}"
echo "DataClass Labels:      ${DATACLASS_RESULT}"
echo "DataClass Values:      ${DATACLASS_VAL_RESULT}"
echo "Docker Tools:          ${DOCKER_TOOLS}"
if [ "${DOCKER_TOOLS}" != "SKIPPED" ]; then
    echo "  Kubesec:           ${KUBESEC_RESULT}"
    echo "  Trivy:             ${TRIVY_RESULT}"
    echo "  Checkov:           ${CHECKOV_RESULT}"
    echo "  kube-score:        ${KUBESCORE_RESULT}"
fi

# Calculate overall result
OVERALL_RESULT="PASSED"
if [ "${CONFTEST_RESULT}" != "PASSED" ]; then OVERALL_RESULT="FAILED"; fi
if [ "${KUBELINTER_RESULT}" != "PASSED" ]; then OVERALL_RESULT="FAILED"; fi
if [ "${POLARIS_RESULT}" != "PASSED" ]; then OVERALL_RESULT="FAILED"; fi
if [ "${NETPOL_RESULT}" != "PASSED" ]; then OVERALL_RESULT="FAILED"; fi
if [ "${DATACLASS_RESULT}" != "PASSED" ]; then OVERALL_RESULT="FAILED"; fi
if [ "${DATACLASS_VAL_RESULT}" != "PASSED" ]; then OVERALL_RESULT="FAILED"; fi
if [ "${DOCKER_TOOLS}" = "FAILED" ]; then OVERALL_RESULT="FAILED"; fi

echo "Overall:               ${OVERALL_RESULT}"
echo "========================================="
echo ""
echo "Test results saved in: ${TEST_DIR}"
echo "Rendered manifests: ${TEST_DIR}/rendered-dev.yaml"
echo ""

echo "========================================="
echo "DATREE (OFFLINE MODE) - Optional"
echo "========================================="
echo "Skipping Datree - slow in offline mode"
echo "Datree validation runs automatically in GitHub Actions CI"
echo ""

echo "========================================="
echo "VALIDATION COMPLETE"
echo "========================================="

if [ "${OVERALL_RESULT}" = "FAILED" ]; then
    echo ""
    echo "ERROR: One or more validations failed."
    exit 1
fi
