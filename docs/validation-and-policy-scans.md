# Validation & Policy Scans

This template repository (and the GitOps repos generated from it) are designed to be **render-first, scan-second**:

1) Cookiecutter generates a test GitOps repo
2) Helm renders manifests (dev/test/prod)
3) Multiple tools scan the rendered YAML (policy + security + best practices)

This keeps CI deterministic and makes failures easy to reproduce locally.

## Quick start (local)

There are two different ways to run validations locally:

1) **Full harness (CI-equivalent for this template repo)**
  - Generates a test GitOps repo via Cookiecutter
  - Renders dev/test/prod via Helm
  - Runs all scanners against `rendered-<env>.yaml`

2) **Scan-only (no Cookiecutter, no Helm render)**
  - Runs scanners against YAML you already have (usually a CI artifact)
  - This is the workflow added to support “scan rendered YAML without generation”

### Option 1 — Full harness (Cookiecutter + Helm + scan)

Windows (PowerShell/CMD) from repo root:

```bat
.\scripts\test-all-validations.bat
```

bash (Linux/macOS/Git Bash) from repo root:

```bash
bash ./scripts/test-all-validations.sh
```

Notes:

- Windows: Datree runs by default (`RUN_DATREE` defaults to `1`). Set `RUN_DATREE=0` to skip.
- bash: the harness intentionally skips Datree in offline mode (it’s slow). CI runs Datree separately.

### Option 2 — Scan-only (scan existing rendered YAML)

Scan-only scripts live here:

- `scripts/scan-rendered.bat`
- `scripts/scan-rendered.sh`

Windows (single file):

```bat
set RUN_DATREE=1
set NO_DOCKER=0
set RENDERED_YAML=C:\path\to\rendered-dev.yaml
call .\scripts\scan-rendered.bat
```

Windows (dev/test/prod files):

```bat
set RUN_DATREE=1
set NO_DOCKER=0
set RENDERED_DEV_YAML=C:\path\to\rendered-dev.yaml
set RENDERED_TEST_YAML=C:\path\to\rendered-test.yaml
set RENDERED_PROD_YAML=C:\path\to\rendered-prod.yaml
call .\scripts\scan-rendered.bat
```

Git Bash / bash (single file):

```bash
RUN_DATREE=1 NO_DOCKER=0 \
RENDERED_YAML=./rendered-dev.yaml \
bash ./scripts/scan-rendered.sh
```

Git Bash / bash (dev/test/prod files):

```bash
RUN_DATREE=1 NO_DOCKER=0 \
RENDERED_DEV_YAML=./rendered-dev.yaml \
RENDERED_TEST_YAML=./rendered-test.yaml \
RENDERED_PROD_YAML=./rendered-prod.yaml \
bash ./scripts/scan-rendered.sh
```

Scan-only toggles:

- `RUN_DATREE` (default `0` in scan-only): set to `1` to include Datree in the scan-only run.
- `NO_DOCKER` (default `0`): set to `1` to skip Docker-based tools.
- `VALUES_YAML`: optional; enables OpenShift-mode heuristics when you have the values file.
- `POLICY_DIR`: optional; override policies directory.

## What runs in CI

There are two common CI contexts:

1) **Template repo CI** (this repository): renders a generated test GitOps repo and scans it.
2) **Generated GitOps repo CI**: renders the tenant chart and scans it, often pulling “central” policies from this template repo.

### Template repo workflows

- `.github/workflows/validate-network-policies.yaml`
  - Renders dev/test/prod and runs: Conftest, kube-linter, Polaris, Datree
- `.github/workflows/validate-network-policies-comprehensive.yaml`
  - Renders dev/test/prod and runs: Conftest, Datree, Kubesec, Polaris, kube-score, kube-linter, Pluto, Trivy, Checkov

### Generated GitOps repo workflows (cookiecutter output)

- `gitops-repo/{{cookiecutter.app_name}}-gitops/.github/workflows/validate-policies-comprehensive.yaml`
  - Similar “render + scan” approach, but it downloads policy/config files from the central template repo at runtime.

### “Policy enforcement” workflow (Datree-only)

- `.github/workflows/policy-enforcement.yaml` (used in tenant repos)
  - Runs **Datree (Helm plugin)** against the chart, with policies downloaded from the template repo.

## Tools and their configuration

This repo keeps policy/config files in one place:

- `policies/*.rego` — Conftest (OPA/Rego) policies
  - `network-policies.rego`
  - `routes-edge-termination.rego`
  - `avi-infrasetting-annotation.rego`
- `policies/kube-linter.yaml` — kube-linter configuration
- `policies/polaris.yaml` — Polaris configuration
- `policies/datree-policies.yaml` — Datree policy set (offline/local mode)

Other scanners run with workflow defaults:

- **Trivy**: config scan via `aquasecurity/trivy-action` (outputs SARIF)
- **Checkov**: Kubernetes framework via `bridgecrewio/checkov-action` (outputs CLI + SARIF)
- **Pluto**: Kubernetes API deprecation scan (target versions set in workflow)
- **kube-score**: best-practice heuristics (CI output format is `ci`)
- **Kubesec**: security risk scanning (CI filters to workload kinds before scanning)

## What policies we enforce (high level)

The exact rules are the policy/config files above, but conceptually we enforce:

- **Zero-trust networking**
  - Workloads should have NetworkPolicies and explicit ingress/egress intent
- **Data classification labeling**
  - Workloads must carry a valid `DataClass` label (e.g., Low/Medium/High)
- **Route/Ingress safety defaults**
  - Route termination choices may be constrained by policy (environment/platform rules)
- **Kubernetes best practices**
  - Probes, resources, security context expectations, etc.
- **Misconfiguration and security scanning**
  - Trivy/Checkov/Kubesec catch risky patterns in the rendered YAML

## How to reproduce a CI failure locally

1) Identify which environment failed (`dev`, `test`, or `prod`).
2) Render the chart with the *exact* values file CI used.
3) Run the same validator locally.

Fastest way (recommended): run the full harness and inspect the rendered output:

- `test-output/rendered-dev.yaml`
- `test-output/rendered-test.yaml`
- `test-output/rendered-prod.yaml`

If you need to run a tool directly:

### Conftest

```bash
conftest test rendered-dev.yaml --policy policies/ --all-namespaces --output table --fail-on-warn
```

### Datree (CI-style, Helm plugin)

CI uses the Helm plugin so it evaluates the chart templates with values:

```bash
helm plugin install https://github.com/datreeio/helm-datree
helm datree config set offline local
helm datree test --ignore-missing-schemas \
  --policy-config ./policies/datree-policies.yaml \
  --include-tests ./charts/gitops \
  -- --namespace abc123-dev --values ./deploy/dev_values.yaml gitops-app-dev
```

### kube-linter / Polaris

```bash
kube-linter lint rendered-dev.yaml --config policies/kube-linter.yaml
polaris audit --audit-path rendered-dev.yaml --config policies/polaris.yaml --format pretty --set-exit-code-below-score 100
```

### Trivy / Checkov / kube-score / Kubesec

These typically run in Docker/Actions.

- If the harness skipped Docker tools, install Docker and re-run the harness.
- In CI, check the job artifacts (SARIF/JSON) for precise findings.

## Troubleshooting guide (when CI fails)

## CI failure triage checklist (fast path)

When a PR is red, the quickest way to fix it is:

1) Identify the workflow + job that failed
2) Download the rendered manifests artifact for the failing environment
3) Re-run the same tool locally against the rendered YAML
4) Fix templates/values, then re-run the local harness until green

### 1) Find the failing job and environment

In GitHub Actions:

- Open the failing workflow run
- The job name usually includes the environment, e.g. `Conftest (dev)` or `Trivy (prod)`

If the workflow uses a matrix, the same tool runs 3 times (dev/test/prod). Fix the environment that failed first.

### 2) Download artifacts (when available)

Many workflows upload artifacts. In the workflow run page, scroll to **Artifacts** and download:

- `rendered-dev`, `rendered-test`, `rendered-prod`
  - Contains `rendered-<env>.yaml` (the exact input scanned by most tools)
  - Some workflows also include `values-<env>.yaml`

In the comprehensive workflows you may also see:

- `polaris-report-<env>` (JSON)
- `trivy-results-<env>` (SARIF)
- `checkov-results-<env>` (SARIF)
- `kubesec-results-<env>` (JSON)

Tip: if the job produced SARIF, you can also view results under **Security → Code scanning alerts** (repo setting dependent).

### 3) Re-run the exact tool locally

If you want the quickest **CI-equivalent** check for this template repo, use the full harness:

- Windows: `scripts/test-all-validations.bat` (runs Cookiecutter + Helm render + scans)
- bash: `scripts/test-all-validations.sh` (runs Cookiecutter + Helm render + scans)

If you want the quickest **scan-only** rerun (no Cookiecutter), use the scan-only scripts against the downloaded rendered YAML artifacts:

- Windows:

```bat
set RENDERED_DEV_YAML=C:\path\to\rendered-dev.yaml
set RENDERED_TEST_YAML=C:\path\to\rendered-test.yaml
set RENDERED_PROD_YAML=C:\path\to\rendered-prod.yaml
call .\scripts\scan-rendered.bat
```

- bash:

```bash
RENDERED_DEV_YAML=./rendered-dev.yaml \
RENDERED_TEST_YAML=./rendered-test.yaml \
RENDERED_PROD_YAML=./rendered-prod.yaml \
bash ./scripts/scan-rendered.sh
```

Important:

- `test-all-validations.*` is “same pipeline as CI in this template repo” (it generates and renders).
- `scan-rendered.*` is “same scanners against the same rendered YAML” (it does not generate or render).

If you need to rerun a single tool, point it at the downloaded `rendered-<env>.yaml`.

Examples (run from a folder containing `rendered-dev.yaml`):

Conftest:

```bash
conftest test rendered-dev.yaml --policy policies/ --all-namespaces --output table --fail-on-warn
```

kube-linter:

```bash
kube-linter lint rendered-dev.yaml --config policies/kube-linter.yaml
```

Polaris:

```bash
polaris audit --audit-path rendered-dev.yaml --config policies/polaris.yaml --format pretty --set-exit-code-below-score 100
```

Pluto:

```bash
pluto detect rendered-dev.yaml --target-versions k8s=v1.28.0
```

kube-score (CI ignores SCC UID/GID heuristic):

```bash
docker run --rm -v $(pwd):/project \
  zegl/kube-score:latest score \
  --output-format ci \
  --ignore-test container-security-context-user-group-id \
  /project/rendered-dev.yaml
```

### 4) Common “where do I look” mapping

- Conftest failures: look at `policies/*.rego`
- Datree failures: look at `policies/datree-policies.yaml`
- Polaris failures: look at `policies/polaris.yaml`
- kube-linter failures: look at `policies/kube-linter.yaml`
- Trivy/Checkov failures: download and open the SARIF artifact for the environment
- Kubesec failures: download `kubesec-results-<env>.json` and inspect the flagged object(s)

### 5) Sanity check: render output is what you expect

Before fixing any policy finding, confirm the manifest actually contains what you think it does:

- Does the workload exist in `rendered-<env>.yaml`?
- Is the label/annotation present at the right level (Deployment metadata vs Pod template metadata)?
- Is the NetworkPolicy selector matching the workload labels?

Most “mysterious” policy failures end up being one of:

- A value is set in `test_values.yaml` but not in `dev_values.yaml`
- A label was added to the Service but not to the Deployment template
- A NetworkPolicy exists but selects no pods due to label mismatch

### Step 0 — sanity checks (most common)

- Helm dependency is up to date (`helm dependency update`)
- You’re rendering with the right `*_values.yaml`
- Your manifest file is actually what the tool is scanning (CI uses the rendered artifact)

### Conftest failures

Conftest failures come from `policies/*.rego`.

Typical causes:

- Missing NetworkPolicy for a workload
- Missing/invalid `DataClass` label
- Route configuration violating an org rule

Fix approach:

- Render the manifest locally and find the specific resource named in the failure.
- Add/adjust the corresponding template/value to satisfy the rule.

### Datree failures

Datree uses `policies/datree-policies.yaml` (offline/local).

Typical causes:

- Missing required labels/annotations
- Missing probes/resources
- Container security-context expectations

Fix approach:

- Datree output shows the rule and the resource path.
- Render locally and confirm the missing field is present in the rendered YAML.

### kube-score failures

kube-score is heuristic-based.

Important OpenShift note:

- **OpenShift SCC assigns UIDs/GIDs at runtime**, so kube-score’s “low user/group id” check can be a false-positive.
- In CI we ignore `container-security-context-user-group-id` to avoid SCC noise.

If kube-score fails on other checks:

- Add resource requests/limits
- Add readiness/liveness probes
- Add PodDisruptionBudget/HPA (if required by your platform rules)

Also note:

- kube-score prints `[SKIPPED]` for checks that are not applicable (this is not a failure).

### Checkov failures

Checkov rules are identified as `CKV_K8S_*`.

- Some checks may be intentionally skipped in CI (see workflow `skip_check`).
- For OpenShift SCC scenarios, avoid hard-coding `runAsUser/runAsGroup` unless your cluster explicitly requires it.

### Trivy failures

Trivy config scan findings show up in SARIF (downloadable artifact in CI).

Fix approach:

- Use the SARIF finding to locate the resource path and rule.
- Fix the template/values to remove the misconfiguration.

### Kubesec failures

CI filters to workload kinds before scanning (Deployments/StatefulSets/Jobs/etc.).

If Kubesec reports “no schema” for non-workload kinds, that’s expected; focus on the scored workload objects.

### Pluto failures (deprecated APIs)

Pluto flags deprecated Kubernetes API versions.

Fix approach:

- Update the `apiVersion` to the supported version for your cluster target.

## Why we run these tools

- **Catch policy violations before deployment** (zero-trust + org rules)
- **Make changes safe and reviewable** (rendered YAML is the contract)
- **Shift-left security** (misconfig scanning in PRs)
- **Keep templates portable** (OpenShift SCC awareness, offline policy scanning)
