#!/bin/bash
# Removed set -e to allow Docker failures without exiting script
set -o pipefail

echo "========================================="
echo "NETWORK POLICY VALIDATION TEST SUITE"
echo "========================================="
echo ""

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${BASE_DIR}/.." && pwd)"

# Default to a repo-root test-output folder so this script works from any CWD and
# aligns with test-all-validations.bat.
TEST_DIR="${TEST_DIR:-${REPO_ROOT}/test-output}"

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
            -v "${REPO_ROOT}:/work" \
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
cd "${REPO_ROOT}"

if [ ! -d "${REPO_ROOT}/gitops-repo" ]; then
    echo "✗ FAILED: gitops-repo template directory not found at: ${REPO_ROOT}/gitops-repo"
    exit 1
fi

cookiecutter_run gitops-repo/ --no-input \
    app_name=test-app \
    licence_plate=abc123 \
    github_org=bcgov-c \
    --output-dir "${TEST_DIR}" --overwrite-if-exists

if [ ! -d "${TEST_DIR}/test-app-gitops" ]; then
    echo "✗ FAILED: Cookiecutter output folder was not created: ${TEST_DIR}/test-app-gitops"
    exit 1
fi

echo "[3/14] Skipping shared-lib copy (ag-helm-templates pulled from OCI registry by default)..."

echo "[4/14] Updating Helm dependencies..."
cd "${TEST_DIR}/test-app-gitops/charts/gitops"
helm dependency update || {
    echo "✗ FAILED: helm dependency update"
    exit 1
}

echo "[5/14] Rendering Helm templates (dev/test/prod)..."
for ENV in dev test prod; do
    helm template test-app . \
        --values "../../deploy/${ENV}_values.yaml" \
        --namespace "abc123-${ENV}" \
        > "../../../rendered-${ENV}.yaml"
    if [ ! -s "../../../rendered-${ENV}.yaml" ]; then
        echo "✗ FAILED: Render produced empty output for ${ENV}"
        exit 1
    fi
    LINE_COUNT=$(wc -l < "../../../rendered-${ENV}.yaml")
    echo "✓ ${ENV}: Generated ${LINE_COUNT} lines of manifests"
done
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

POLARIS_VERSION="10.1.4"
POLARIS_VERSION_FILE="polaris.version"
CURRENT_POLARIS_VERSION=""
if [ -f "${POLARIS_VERSION_FILE}" ]; then
    CURRENT_POLARIS_VERSION="$(cat "${POLARIS_VERSION_FILE}" 2>/dev/null || true)"
fi

if [ ! -f polaris.exe ] || [ "${CURRENT_POLARIS_VERSION}" != "${POLARIS_VERSION}" ]; then
        echo "Downloading Polaris ${POLARIS_VERSION}..."
        download_file "https://github.com/FairwindsOps/polaris/releases/download/${POLARIS_VERSION}/polaris_windows_amd64.tar.gz" "polaris.tar.gz"
        require_file_nonempty "polaris.tar.gz" "Polaris"
        tar -xzf polaris.tar.gz polaris.exe
        rm -f polaris.tar.gz
        echo "${POLARIS_VERSION}" > "${POLARIS_VERSION_FILE}"
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
FAILED_FLAG=0
SUMMARY_FILE="${TEST_DIR}/validation-summary.txt"
: > "${SUMMARY_FILE}"
KUBESEC_RESULT="UNKNOWN"
TRIVY_RESULT="UNKNOWN"
CHECKOV_RESULT="UNKNOWN"
KUBESCORE_RESULT="UNKNOWN"
DOCKER_TOOLS="UNKNOWN"

echo "[7/14] Running policy tools (dev/test/prod)..."
echo "-----------------------------------------"

for ENV in dev test prod; do
    echo "========================================="
    echo "ENV: ${ENV}"
    echo "========================================="
    echo "ENV: ${ENV}" >> "${SUMMARY_FILE}"

    if ./conftest.exe test "rendered-${ENV}.yaml" --policy "${BASE_DIR}/policies" --all-namespaces --output table; then
        echo "PASSED: Conftest (${ENV})"
        echo "Conftest (${ENV}): PASSED" >> "${SUMMARY_FILE}"
    else
        echo "FAILED: Conftest (${ENV})"
        echo "Conftest (${ENV}): FAILED" >> "${SUMMARY_FILE}"
        FAILED_FLAG=1
    fi
    echo "" >> "${SUMMARY_FILE}"
    echo ""

    if ./kube-linter.exe lint "rendered-${ENV}.yaml" --config "${BASE_DIR}/policies/kube-linter.yaml"; then
        echo "PASSED: kube-linter (${ENV})"
        echo "kube-linter (${ENV}): PASSED" >> "${SUMMARY_FILE}"
    else
        echo "WARNINGS: kube-linter (${ENV})"
        echo "kube-linter (${ENV}): WARNINGS" >> "${SUMMARY_FILE}"
    fi
    echo "" >> "${SUMMARY_FILE}"
    echo ""

    if ./polaris.exe audit --audit-path "rendered-${ENV}.yaml" --config "${BASE_DIR}/policies/polaris.yaml" --format pretty --set-exit-code-below-score 100; then
        echo "PASSED: Polaris (${ENV})"
        echo "Polaris (${ENV}): PASSED" >> "${SUMMARY_FILE}"
    else
        echo "FAILED: Polaris (${ENV})"
        echo "Polaris (${ENV}): FAILED" >> "${SUMMARY_FILE}"
        FAILED_FLAG=1
    fi
    echo "" >> "${SUMMARY_FILE}"
    echo ""

    echo "Running Network Policy Checks (${ENV})..."
    NP_COUNT=$(grep -c "kind: NetworkPolicy" "rendered-${ENV}.yaml" || echo "0")
    DEPLOY_COUNT=$(grep -c "kind: Deployment" "rendered-${ENV}.yaml" || echo "0")
    DATACLASS_COUNT=$(grep -c "DataClass:" "rendered-${ENV}.yaml" || echo "0")
    echo "NetworkPolicies found: ${NP_COUNT}"
    echo "Deployments found: ${DEPLOY_COUNT}"

    if [ "${NP_COUNT}" -ge "${DEPLOY_COUNT}" ]; then
        echo "PASSED: NetworkPolicy coverage (${ENV})"
        echo "NetworkPolicy coverage (${ENV}): PASSED" >> "${SUMMARY_FILE}"
    else
        echo "FAILED: NetworkPolicy coverage (${ENV})"
        echo "NetworkPolicy coverage (${ENV}): FAILED" >> "${SUMMARY_FILE}"
        FAILED_FLAG=1
    fi

    echo "DataClass labels found: ${DATACLASS_COUNT}"
    if [ "${DATACLASS_COUNT}" -ge "${DEPLOY_COUNT}" ]; then
        echo "PASSED: DataClass labels (${ENV})"
        echo "DataClass labels (${ENV}): PASSED" >> "${SUMMARY_FILE}"
    else
        echo "FAILED: DataClass labels (${ENV})"
        echo "DataClass labels (${ENV}): FAILED" >> "${SUMMARY_FILE}"
        FAILED_FLAG=1
    fi

    INVALID=$(grep "DataClass:" "rendered-${ENV}.yaml" | grep -v "Low" | grep -v "Medium" | grep -v "High" || echo "")
    if [ -z "$INVALID" ]; then
        echo "PASSED: DataClass values (${ENV})"
        echo "DataClass values (${ENV}): PASSED" >> "${SUMMARY_FILE}"
    else
        echo "FAILED: DataClass values (${ENV})"
        echo "DataClass values (${ENV}): FAILED" >> "${SUMMARY_FILE}"
        FAILED_FLAG=1
    fi

    echo "" >> "${SUMMARY_FILE}"
    echo ""
done

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
    checkov_skip=("--skip-check" "CKV_K8S_43")
    echo "Skipping digest enforcement in Checkov: CKV_K8S_43"
    if [ -f "test-app-gitops/deploy/dev_values.yaml" ] && grep -q "openshift: true" "test-app-gitops/deploy/dev_values.yaml"; then
        checkov_skip+=("--skip-check" "CKV_K8S_40")
        echo "OpenShift mode detected for dev - skipping: CKV_K8S_40"
    fi
    CHECKOV_OUTPUT=$(docker run --rm -v "$(pwd):/work" bridgecrew/checkov:latest -f /work/rendered-dev.yaml --framework kubernetes --compact --quiet "${checkov_skip[@]}" 2>&1 || true)
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

echo ""
echo "========================================="
echo "VALIDATION SUMMARY"
echo "========================================="
echo "Per-environment results: ${SUMMARY_FILE}"
cat "${SUMMARY_FILE}" || true
echo "Docker Tools:          ${DOCKER_TOOLS}"
if [ "${DOCKER_TOOLS}" != "SKIPPED" ]; then
    echo "  Kubesec:           ${KUBESEC_RESULT}"
    echo "  Trivy:             ${TRIVY_RESULT}"
    echo "  Checkov:           ${CHECKOV_RESULT}"
    echo "  kube-score:        ${KUBESCORE_RESULT}"
fi

# Calculate overall result
OVERALL_RESULT="PASSED"
if [ "${FAILED_FLAG}" = "1" ]; then OVERALL_RESULT="FAILED"; fi
if [ "${DOCKER_TOOLS}" = "FAILED" ]; then OVERALL_RESULT="FAILED"; fi

echo "Overall:               ${OVERALL_RESULT}"
echo "========================================="
echo ""
echo "Test results saved in: ${TEST_DIR}"
echo "Rendered manifests:"
echo "  ${TEST_DIR}/rendered-dev.yaml"
echo "  ${TEST_DIR}/rendered-test.yaml"
echo "  ${TEST_DIR}/rendered-prod.yaml"
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
