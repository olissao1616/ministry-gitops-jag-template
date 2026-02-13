#!/bin/bash
set -o pipefail

# Scan-only harness: runs validators against existing rendered YAML.
# This script does NOT run cookiecutter and does NOT run helm template.
#
# Usage (single file):
#   RENDERED_YAML=/path/to/rendered-dev.yaml bash ./scripts/scan-rendered.sh
#
# Usage (dev/test/prod):
#   RENDERED_DEV_YAML=... RENDERED_TEST_YAML=... RENDERED_PROD_YAML=... bash ./scripts/scan-rendered.sh
#
# Optional:
#   VALUES_YAML=/path/to/dev_values.yaml   # only used for OpenShift-mode heuristics
#   POLICY_DIR=/path/to/policies
#   RUN_DATREE=0
#   NO_DOCKER=1

RUN_DATREE="${RUN_DATREE:-0}"
NO_DOCKER="${NO_DOCKER:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POLICY_DIR="${POLICY_DIR:-${REPO_ROOT}/policies}"
TOOLS_DIR="${REPO_ROOT}/test-output/.scan-tools"
mkdir -p "${TOOLS_DIR}" 2>/dev/null || true

if [ ! -d "${POLICY_DIR}" ]; then
  echo "✗ ERROR: POLICY_DIR not found: ${POLICY_DIR}" >&2
  exit 1
fi

# Inputs
scan_labels=()
scan_files=()

if [ -n "${RENDERED_YAML:-}" ]; then
  scan_labels+=("custom")
  scan_files+=("${RENDERED_YAML}")
else
  if [ -n "${RENDERED_DEV_YAML:-}" ]; then scan_labels+=("dev"); scan_files+=("${RENDERED_DEV_YAML}"); fi
  if [ -n "${RENDERED_TEST_YAML:-}" ]; then scan_labels+=("test"); scan_files+=("${RENDERED_TEST_YAML}"); fi
  if [ -n "${RENDERED_PROD_YAML:-}" ]; then scan_labels+=("prod"); scan_files+=("${RENDERED_PROD_YAML}"); fi
fi

if [ ${#scan_files[@]} -eq 0 ]; then
  echo "✗ ERROR: No input YAML provided." >&2
  echo "Set RENDERED_YAML or RENDERED_DEV_YAML/RENDERED_TEST_YAML/RENDERED_PROD_YAML." >&2
  exit 1
fi

for f in "${scan_files[@]}"; do
  if [ ! -f "${f}" ]; then
    echo "✗ ERROR: Rendered YAML not found: ${f}" >&2
    exit 1
  fi
done

# OpenShift mode detection (optional)
OPENSHIFT_MODE=0
if [ -n "${VALUES_YAML:-}" ] && [ -f "${VALUES_YAML}" ]; then
  if grep -q "openshift: true" "${VALUES_YAML}"; then
    OPENSHIFT_MODE=1
  fi
fi

is_windows_bash() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

infer_openshift_from_yaml() {
  local yaml="$1"
  # Heuristic: OpenShift Routes are a strong signal.
  if grep -qE '(^kind:[[:space:]]*Route[[:space:]]*$|route\.openshift\.io/)' "${yaml}" 2>/dev/null; then
    echo 1
  else
    echo 0
  fi
}

download_file() {
  local url="$1"
  local out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl --fail --show-error --location --http1.1 \
      --retry 5 --retry-delay 1 --retry-connrefused \
      --connect-timeout 15 --max-time 180 \
      "${url}" -o "${out}"
    return $?
  fi

  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command \
      "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri '${url}' -OutFile '${out}'"
    return $?
  fi

  echo "✗ ERROR: No downloader available (need curl or powershell.exe)" >&2
  return 1
}

ensure_tools_windows() {
  pushd "${TOOLS_DIR}" >/dev/null 2>&1

  if [ ! -f conftest.exe ]; then
    echo "Downloading Conftest (Windows)..."
    download_file "https://github.com/open-policy-agent/conftest/releases/download/v0.49.1/conftest_0.49.1_Windows_x86_64.zip" "conftest.zip" || return 1
    unzip -q conftest.zip conftest.exe || return 1
    rm -f conftest.zip
  fi

  if [ ! -f kube-linter.exe ]; then
    echo "Downloading kube-linter (Windows)..."
    download_file "https://github.com/stackrox/kube-linter/releases/download/v0.6.8/kube-linter-windows.zip" "kube-linter.zip" || return 1
    unzip -q kube-linter.zip kube-linter.exe || return 1
    rm -f kube-linter.zip
  fi

  if [ ! -f polaris.exe ]; then
    echo "Downloading Polaris (Windows)..."
    download_file "https://github.com/FairwindsOps/polaris/releases/download/8.5.0/polaris_windows_amd64.tar.gz" "polaris.tar.gz" || return 1
    tar -xzf polaris.tar.gz polaris.exe || return 1
    rm -f polaris.tar.gz
  fi

  if [ "${RUN_DATREE}" = "1" ] && [ ! -f datree.exe ]; then
    echo "Downloading Datree CLI (Windows)..."
    if download_file "https://github.com/datreeio/datree/releases/download/1.9.19/datree-cli_1.9.19_windows_x86_64.zip" "datree.zip"; then
      unzip -q datree.zip datree.exe || true
      rm -f datree.zip
    else
      echo "WARNING: Datree download failed; Datree will be skipped." >&2
    fi
  fi

  popd >/dev/null 2>&1
}

ensure_tools_linux() {
  pushd "${TOOLS_DIR}" >/dev/null 2>&1

  if [ ! -f conftest ]; then
    echo "Downloading Conftest (Linux)..."
    download_file "https://github.com/open-policy-agent/conftest/releases/download/v0.49.1/conftest_0.49.1_Linux_x86_64.tar.gz" "conftest.tar.gz" || return 1
    tar -xzf conftest.tar.gz conftest || return 1
    chmod +x conftest
    rm -f conftest.tar.gz
  fi

  if [ ! -f kube-linter ]; then
    echo "Downloading kube-linter (Linux)..."
    download_file "https://github.com/stackrox/kube-linter/releases/download/v0.6.8/kube-linter-linux.tar.gz" "kube-linter.tar.gz" || return 1
    tar -xzf kube-linter.tar.gz kube-linter || return 1
    chmod +x kube-linter
    rm -f kube-linter.tar.gz
  fi

  if [ ! -f polaris ]; then
    echo "Downloading Polaris (Linux)..."
    download_file "https://github.com/FairwindsOps/polaris/releases/download/8.5.0/polaris_linux_amd64.tar.gz" "polaris.tar.gz" || return 1
    tar -xzf polaris.tar.gz polaris || return 1
    chmod +x polaris
    rm -f polaris.tar.gz
  fi

  if [ "${RUN_DATREE}" = "1" ] && [ ! -f datree ]; then
    echo "Downloading Datree CLI (Linux)..."
    # Best-effort: if this fails, Datree will be skipped.
    if download_file "https://github.com/datreeio/datree/releases/download/1.9.19/datree-cli_1.9.19_linux_amd64.zip" "datree.zip"; then
      unzip -q datree.zip datree || true
      chmod +x datree 2>/dev/null || true
      rm -f datree.zip
    else
      echo "WARNING: Datree download failed; Datree will be skipped." >&2
    fi
  fi

  popd >/dev/null 2>&1
}

if is_windows_bash; then
  ensure_tools_windows || exit 1
  CONTEST_BIN="${TOOLS_DIR}/conftest.exe"
  KUBELINTER_BIN="${TOOLS_DIR}/kube-linter.exe"
  POLARIS_BIN="${TOOLS_DIR}/polaris.exe"
  DATREE_BIN="${TOOLS_DIR}/datree.exe"
else
  ensure_tools_linux || exit 1
  CONTEST_BIN="${TOOLS_DIR}/conftest"
  KUBELINTER_BIN="${TOOLS_DIR}/kube-linter"
  POLARIS_BIN="${TOOLS_DIR}/polaris"
  DATREE_BIN="${TOOLS_DIR}/datree"
fi

FAILED_FLAG=0

echo "========================================="
echo "SCAN-ONLY VALIDATION"
echo "========================================="
echo "Policy dir:   ${POLICY_DIR}"
echo "OpenShift:    ${OPENSHIFT_MODE}"
echo "Docker tools: ${NO_DOCKER}"
echo ""

for i in "${!scan_files[@]}"; do
  label="${scan_labels[$i]}"
  yaml="${scan_files[$i]}"

  # Per-env OpenShift inference: if VALUES_YAML isn't provided, infer from rendered YAML.
  openshift_for_env="${OPENSHIFT_MODE}"
  if [ "${OPENSHIFT_MODE}" = "0" ] && [ -z "${VALUES_YAML:-}" ]; then
    openshift_for_env="$(infer_openshift_from_yaml "${yaml}")"
  fi

  echo "========================================="
  echo "ENV: ${label}"
  echo "YAML: ${yaml}"
  echo "========================================="

  "${CONTEST_BIN}" test "${yaml}" --policy "${POLICY_DIR}" --all-namespaces --output table || FAILED_FLAG=1
  echo ""

  "${KUBELINTER_BIN}" lint "${yaml}" --config "${POLICY_DIR}/kube-linter.yaml" || true
  echo ""

  "${POLARIS_BIN}" audit --audit-path "${yaml}" --config "${POLICY_DIR}/polaris.yaml" --format pretty --set-exit-code-below-score 100 || FAILED_FLAG=1
  echo ""

  echo "NetworkPolicy/DataClass sanity checks (${label})..."
  np_count=$(grep -c "kind: NetworkPolicy" "${yaml}" 2>/dev/null || echo "0")
  deploy_count=$(grep -c "kind: Deployment" "${yaml}" 2>/dev/null || echo "0")
  dataclass_count=$(grep -c "DataClass:" "${yaml}" 2>/dev/null || echo "0")
  echo "NetworkPolicies found: ${np_count}"
  echo "Deployments found:    ${deploy_count}"
  echo "DataClass labels:     ${dataclass_count}"
  if [ "${np_count}" -lt "${deploy_count}" ]; then
    echo "FAILED: NetworkPolicy coverage (${label})"
    FAILED_FLAG=1
  else
    echo "PASSED: NetworkPolicy coverage (${label})"
  fi
  if [ "${dataclass_count}" -lt "${deploy_count}" ]; then
    echo "FAILED: DataClass labels (${label})"
    FAILED_FLAG=1
  else
    echo "PASSED: DataClass labels (${label})"
  fi
  if grep -q "DataClass:" "${yaml}" && grep "DataClass:" "${yaml}" | grep -v "Low" | grep -v "Medium" | grep -v "High" >/dev/null 2>&1; then
    echo "FAILED: DataClass values (${label})"
    FAILED_FLAG=1
  else
    echo "PASSED: DataClass values (${label})"
  fi
  echo ""

  if [ "${RUN_DATREE}" = "1" ] && [ -x "${DATREE_BIN}" ]; then
    echo "Datree (${label})..."
    "${DATREE_BIN}" config set offline local >/dev/null 2>&1 || true
    "${DATREE_BIN}" test "${yaml}" --ignore-missing-schemas --no-record --policy-config "${POLICY_DIR}/datree-policies.yaml" || FAILED_FLAG=1
    echo ""
  fi

  if [ "${NO_DOCKER}" = "0" ] && command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
    yaml_dir="$(cd "$(dirname "${yaml}")" && pwd)"
    yaml_name="$(basename "${yaml}")"

    pushd "${yaml_dir}" >/dev/null 2>&1

    # Git Bash/MSYS may auto-convert docker.exe arguments (both mounts and in-container paths).
    # Disable conversion and pass an explicit Windows path for the mount.
    docker_prefix=()
    docker_mount_src="$(pwd)"
    if is_windows_bash; then
      docker_prefix=(env MSYS2_ARG_CONV_EXCL='*')
      if pwd -W >/dev/null 2>&1; then
        docker_mount_src="$(pwd -W)"
      fi
      docker_mount_src="${docker_mount_src//\\//}"
    fi

    echo "Trivy (${label})..."
    "${docker_prefix[@]}" docker run --rm -v "${docker_mount_src}:/work" aquasec/trivy:latest config "/work/${yaml_name}" --severity HIGH,CRITICAL || FAILED_FLAG=1
    echo ""

    echo "Checkov (${label})..."
    checkov_skip=()
    if [ "${openshift_for_env}" = "1" ]; then
      checkov_skip+=("--skip-check" "CKV_K8S_40")
    fi
    "${docker_prefix[@]}" docker run --rm -v "${docker_mount_src}:/work" bridgecrew/checkov:latest -f "/work/${yaml_name}" --framework kubernetes --compact --quiet "${checkov_skip[@]}" || FAILED_FLAG=1
    echo ""

    echo "Kubesec (${label})..."
    # Kubesec returns non-zero for combined YAMLs that contain non-workload kinds (schema gaps).
    # Mirror the main harness behavior: write JSON for inspection, but don't fail the run.
    kubesec_out="./kubesec-results-${label}.json"
    "${docker_prefix[@]}" docker run --rm -v "${docker_mount_src}:/work" kubesec/kubesec:v2 scan "/work/${yaml_name}" >"${kubesec_out}" 2>/dev/null || true
    echo ""

    echo "kube-score (${label})..."
    kube_score_ignore=()
    if [ "${openshift_for_env}" = "1" ]; then
      kube_score_ignore+=("--ignore-test" "container-security-context-user-group-id")
    fi
    "${docker_prefix[@]}" docker run --rm -v "${docker_mount_src}:/project" zegl/kube-score:latest score --output-format ci "${kube_score_ignore[@]}" "/project/${yaml_name}" || FAILED_FLAG=1
    echo ""

    popd >/dev/null 2>&1
  fi

done

echo "========================================="
echo "SCAN-ONLY COMPLETE"
if [ "${FAILED_FLAG}" = "1" ]; then
  echo "Overall: FAILED"
  exit 1
fi

echo "Overall: PASSED"
