# Developer Cookbook (Emerald / Zero-Trust GitOps)

## Table of contents

- What you’re building
- The Golden Path (day-to-day)
- Cookbook recipes
  - Change an image tag
  - Add a new service (internal-only)
  - Add a new service (externally reachable via Route)
  - Create a NetworkPolicy (DNS + router ingress + HTTPS egress)
  - Create a NetworkPolicy (service → service, service → Postgres)
  - Add a one-off Job for connectivity testing
  - Use Secrets (without committing credentials)
  - Use ConfigMaps/files
  - Promote dev → test → prod (branch-based)
  - Troubleshoot “nothing can talk to anything”

## Who this is for

This cookbook is for application developers onboarding to **Emerald** (OpenShift/Kubernetes) where the environment is **zero trust / deny-by-default**:

- **No implicit network access**: pods cannot talk to anything unless explicitly allowed.
- **No implicit ingress**: external access must be explicit (Routes/Ingress + NetworkPolicy allowing router ingress).
- **No implicit secrets**: credentials must come from Secrets (or ExternalSecrets) rather than being committed into values.

This repository is a **cookiecutter template** used to generate a standardized GitOps repository for each application (or each tenant license plate). The generated repo contains:

- Helm chart(s) for frontend + backend + PostgreSQL examples
- Environment-specific values (dev/test/prod)
- Argo CD Application manifests pointing at the tenant GitOps repo
- Shared library usage (`ag-helm`) and validation pipelines

## TL;DR quick start

### Local (developer laptop) validation

Run the full validation suite (renders manifests, then scans them):

- Windows + Git Bash:
  - `bash ./test-all-validations.sh`

This script generates output under `test-output/` and produces a `test-output/rendered-dev.yaml` file that all tools scan.

### Generate a GitOps repo locally (cookiecutter)

From the template repository:

1) Generate the repo:

```bash
cookiecutter ./gitops-repo --no-input \
  app_name=myapp \
  licence_plate=abc123 \
  github_org=bcgov-c
```

2) Render and inspect:

```bash
cd myapp-gitops/charts/gitops
helm dependency update
helm template myapp . --values ../../deploy/dev_values.yaml --namespace abc123-dev > rendered.yaml
```

## How the repo is intended to be used

There are two supported patterns:

### Pattern A — Platform team auto-scaffolds the tenant GitOps repo (recommended)

The workflow in .github/workflows/repository-setup.yml can reinitialize a repository by running cookiecutter across multiple template folders.

Key behavior:

- It scaffolds charts + deploy + application + app code
- It repackages Helm charts (`webapi-core`, `react-baseapp`) into `charts/gitops/charts/`
- It pushes branches: `main`, `test`, `develop`
- It removes the repository setup workflows from the scaffolded repo after generation

This is the “developer shows up and everything is ready” path.

### Pattern B — Developers generate locally and commit to a repo

This is useful for experimentation, or if you want a prototype before the platform-run scaffold.

## Repo map (what each folder does)

- `charts/`: cookiecutter template that generates the Helm chart tree (the “GitOps chart”).
- `deploy/`: cookiecutter template that generates `dev_values.yaml`, `test_values.yaml`, `prod_values.yaml`.
- `application/`: cookiecutter template that generates Argo CD Application YAML for dev/test/prod.
- `appcode/`: cookiecutter templates for sample application code (frontend + backend) used as reference.
- `rbac/`: cookiecutter template for RoleBindings (often platform-owned; see notes below).
- `shared-lib/ag-helm/`: reusable Helm library chart functions used by the generated charts.
- `docs/`: human docs.
- `scripts/`: helper scripts for local testing.

## Zero-trust networking model (the most important concept)

### Data classification labels drive networking

This template implements **data classification-based network policies**. Every workload should have a DataClass label, and each workload should have a NetworkPolicy.

- If a pod does **not** have an appropriate label, assume it is **isolated**.
- If a workload does not have a NetworkPolicy, assume it is **non-compliant** (and may not work).

The detailed model and examples are documented in:

- `docs/network-policies.md`

### Common “explicit allow” building blocks

In a deny-by-default cluster, most apps need explicit rules for:

1) **Ingress from the OpenShift router** (Route/Ingress traffic)
2) **Backend → Database** (TCP 5432 to Postgres pods)
3) **Egress to HTTPS** (TCP 443) for calling external APIs

When you see “it deploys but it can’t reach X”, it’s almost always missing one of these.

## GitOps flow (Argo CD)

### Argo CD Applications

Argo CD Application manifests are generated under:

- `application/{{cookiecutter.application_dir}}/argocd/`

They point to a tenant repo named like:

- `git@github.com:bcgov-c/tenant-gitops-{{cookiecutter.licence_plate}}.git`

and they map branches to environments:

- dev → `develop` branch + `deploy/dev_values.yaml`
- test → `test` branch + `deploy/test_values.yaml`
- prod → `main` branch + `deploy/prod_values.yaml`

What this means operationally:

- Merging to `develop` should update the **dev namespace** (`{licence_plate}-dev`).
- Promoting to `test` should update the **test namespace**.
- Merging to `main` should update **prod**.

## How to configure an app (values files)

The values files are the developer-facing API.

## How developers actually use the Helm templates

Think of the generated GitOps repo like this:

- The Helm chart under `charts/<something>/gitops/` is the “render engine”.
- The environment values under `deploy/<something>/{dev,test,prod}_values.yaml` are the “inputs”.
- Argo CD syncs one branch per environment and applies the rendered manifests to the matching namespace.

### Day-to-day GitOps workflow (recommended)

1) Update your environment values (usually images/tags, routes, config, secrets references)
2) Commit to the branch that maps to your environment:

- dev: `develop`
- test: `test`
- prod: `main`

3) Argo CD reconciles:

- Source: the tenant GitOps repo
- Path: `charts/gitops`
- Values: `deploy/<env>_values.yaml`

When something doesn’t work, debug by rendering locally with the exact same values file.

### Local render/debug loop (the fastest way to troubleshoot)

From the generated GitOps repo root:

```bash
cd charts/gitops
helm dependency update

helm template myapp . \
  --values ../../deploy/dev_values.yaml \
  --namespace abc123-dev \
  > /tmp/rendered.yaml
```

Then inspect:

```bash
grep -n "kind: NetworkPolicy" /tmp/rendered.yaml | head
grep -n "DataClass:" /tmp/rendered.yaml | head
```

If you can render cleanly and the policies look right, Argo CD will behave the same way.

## The Golden Path (what developers do most days)

This is the normal workflow for making changes safely in a deny-by-default cluster:

1) Make the smallest change you need (usually in `deploy/<your-deploy-dir>/*_values.yaml`)
2) Render locally to verify the manifests look right
3) Commit and open a PR to the right branch (or merge directly if your repo rules allow)
4) Let Argo CD sync; then validate behavior in-cluster

The key mindset: if a change requires new communication, you must add the NetworkPolicy for it in the chart.

## Cookbook recipes

### Recipe: Change an image tag (most common task)

Goal: deploy a new backend version to dev.

1) Edit `deploy/<your-deploy-dir>/dev_values.yaml`:

```yaml
backend:
  image:
    tag: "1.2.4"
```

2) Render locally (same values file) and sanity-check:

```bash
cd charts/gitops
helm template myapp . --values ../../deploy/dev_values.yaml --namespace abc123-dev > /tmp/rendered.yaml
```

3) Commit to `develop` (dev) and let Argo sync.

If it deploys but doesn’t work, jump to “Troubleshoot”.

### Recipe: Add a new service (internal-only)

Use this when your service is only called by other in-namespace workloads (no external Route).

Minimum set of files to add:

- Values: add a new `.Values.<service>` block
- Templates:
  - `<service>-deployment.yaml`
  - `<service>-service.yaml`
  - `<service>-networkpolicy.yaml`

Follow the “worker” example in “Adding a new component (service) safely”.

Decision checklist:

- Does it need to be called? If yes: add Service + ingress rule in NP
- Does it need outbound internet? If yes: add HTTPS egress (and ideally restrict via platform egress controls)

### Recipe: Add a new service (externally reachable via OpenShift Route)

Use this when you need an externally reachable entry point (still controlled by cluster + WAF + auth + NP).

You need:

1) A Service (ClusterIP)
2) A Route pointing to that Service
3) A NetworkPolicy allowing **router ingress** to your pods on the service port

#### Step 1 — Add values

```yaml
publicapi:
  enabled: true
  dataClass: medium
  podLabels:
    DataClass: "Medium"
  image:
    repository: ghcr.io/my-org
    name: myapp-publicapi
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  replicaCount: 1
  service:
    type: ClusterIP
    port: 8082
  route:
    enabled: true
    host: myapp-abc123-dev.apps.emerald.devops.gov.bc.ca
    annotations: {}
```

#### Step 2 — Deployment + Service

Copy the same pattern as `backend-*` templates and adjust names/ports.

#### Step 3 — Route template

Create `charts/<your-charts-dir>/gitops/templates/publicapi-route.yaml` using the same cookiecutter-safe escaping pattern as the existing frontend route:

```yaml
{% raw %}{{ "{{" }}- if and .Values.publicapi.enabled .Values.publicapi.route.enabled {{ "}}" }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: {{ "{{" }} printf "%s-publicapi" .Release.Name {{ "}}" }}
  labels:
    {{ "{{" }}- include "gitops.labels" . | nindent 4 {{ "}}" }}
  {{ "{{" }}- with .Values.publicapi.route.annotations {{ "}}" }}
  annotations:
    {{ "{{" }}- toYaml . | nindent 4 {{ "}}" }}
  {{ "{{" }}- end {{ "}}" }}
spec:
  host: {{ "{{" }} .Values.publicapi.route.host {{ "}}" }}
  to:
    kind: Service
    name: {{ "{{" }} printf "%s-publicapi" .Release.Name {{ "}}" }}
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
{{ "{{" }}- end {{ "}}" }}{% endraw %}
```

#### Step 4 — NetworkPolicy allowing router ingress

In OpenShift, router traffic typically comes from a namespace labeled like `network.openshift.io/policy-group: ingress`.

Add this ingress rule to your service’s NetworkPolicy:

```yaml
- from:
    - namespaceSelector:
        matchLabels:
          network.openshift.io/policy-group: ingress
  ports:
    - protocol: TCP
      port: 8082
```

Without this, your Route may exist but traffic will never reach your pods.

### Recipe: Keep microservices private (no Route) + use port-forward

Default rule of thumb in Emerald/zero-trust:

- **Most services should not have a Route** (APIs, workers, databases, internal admin endpoints).
- If you need developer access, use **port-forward** or a short-lived debug Job.

Port-forward examples:

```bash
# Forward a Service port to localhost
kubectl -n <ns> port-forward svc/<release>-backend 8080:8080

# Forward a Pod (useful if Service has no port you need)
kubectl -n <ns> port-forward pod/<pod-name> 8080:8080
```

Why this matters:

- In OpenShift, Routes are often reachable from outside the cluster (sometimes from the public internet).
- Route TLS settings can be modified at any time by anyone with access.
- “Convenient” under deadline pressure becomes “standard practice” over time.

### Recipe: If you truly need a public Route, make it explicit (approval + audit)

This repo includes a Conftest policy that **denies edge-terminated Routes by default** unless they’re allowlisted.

Policy location:

- `charts/<your-charts-dir>/policy/routes-edge-termination.rego`

Allow rules:

1) Frontend Routes are allowlisted by label (`app.kubernetes.io/component: frontend`).
2) Any Route can be allowed with an explicit approval annotation:

- `isb.gov.bc.ca/edge-termination-approval: "<ticket-or-approval-reference>"`

Recommended workflow:

1) Treat “public Route” as a security decision (threat model + approval)
2) Add the approval annotation to the Route
3) Ensure NetworkPolicy allows only router ingress to the intended pods/ports
4) Re-audit periodically (people change, configs drift)

### Recipe: Audit for risky Routes (cluster check)

If you have access to the cluster, periodically scan for edge-terminated Routes:

```bash
oc get route -A -o json | jq -r '
  .items[]
  | select(.spec.tls.termination == "edge")
  | [.metadata.namespace, .metadata.name, (.spec.host // ""), (.metadata.annotations["isb.gov.bc.ca/edge-termination-approval"] // "")]
  | @tsv'
```

Follow-up:

- If it’s not a true public entrypoint, delete the Route and rely on internal access patterns.
- If it is required, ensure there’s an approval annotation and tighten NetworkPolicy and app-level auth.

### Recipe: Harden a Route (if you must have one)

If a Route is genuinely required, reduce blast radius:

- Add an IP allowlist (router-enforced) when the audience is known
- Add an explicit approval annotation (see the Conftest policy)
- Keep `wildcardPolicy: None`

Common annotation pattern (HAProxy router):

```yaml
metadata:
  annotations:
    # Restrict who can reach the Route (comma-separated CIDRs)
    haproxy.router.openshift.io/ip_whitelist: "203.0.113.0/24,198.51.100.10/32"
    # Require explicit review/approval for edge termination
    isb.gov.bc.ca/edge-termination-approval: "ISB-1234"
```

### Recipe: Use internal TLS with OpenShift service serving certs

For service-to-service traffic inside the cluster, prefer TLS/mTLS patterns rather than relying only on NetworkPolicy.

OpenShift can generate a serving cert for a Service and write it into a Secret.

Service example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-backend
  annotations:
    service.beta.openshift.io/serving-cert-secret-name: myapp-backend-tls
spec:
  ports:
    - name: https
      port: 443
      targetPort: https
  selector:
    app.kubernetes.io/name: backend
```

Then mount `myapp-backend-tls` into the backend pod and configure the app to serve TLS on the `https` port.

### Recipe: Create a “debug client” pod for connectivity tests (instead of opening a Route)

When a team wants to “just check something quickly”, the safest pattern is a short-lived in-namespace client pod.

Example:

```bash
kubectl -n <ns> run curl --image=curlimages/curl:8.6.0 -it --rm --restart=Never -- \
  sh -lc 'curl -vk http://<release>-backend:8080/health/live'
```

If this fails:

- It’s almost always NetworkPolicy (service-to-service ingress/egress)
- Or the Service selector/port

### Recipe: Run database migrations as a Job (GitOps-friendly)

If your service needs schema migrations, don’t do it manually and don’t depend on “someone ran it once”.

Pattern:

1) Create a Job template that runs migrations idempotently
2) Give it its own NetworkPolicy (DB egress)
3) Trigger on deploy (or on demand)

Tip: keep migrations in a dedicated image/command so they can be reviewed and audited separately.

### Recipe: Canary / blue-green for Routes (advanced)

OpenShift Routes can support weighted backends (depending on router/cluster version).

High-level idea:

- Primary backend gets most traffic
- Alternate backend gets a small percentage

If your platform supports it, use `spec.alternateBackends` with weights and keep both versions running simultaneously.

### Recipe: Break-glass exposure (time-boxed and discoverable)

If you ever need to temporarily expose a service via Route to unblock an incident:

- Add a clear “expires” annotation
- Add the ISB approval annotation
- Create a ticket and link it
- Delete the Route as part of the incident follow-up

Example:

```yaml
metadata:
  annotations:
    isb.gov.bc.ca/edge-termination-approval: "INC-98765"
    platform.gov.bc.ca/expires-at: "2026-02-11T17:00:00Z"
```

### Recipe: Create a NetworkPolicy (router ingress + HTTPS egress)

This is the most common “web workload” policy shape.

Copy/paste template (full form):

```yaml
{{- if .Values.publicapi.enabled }}
{{- $np := dict "ApplicationGroup" (default .Values.project "app") "Name" "publicapi" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}
{{- $_ := set $np "PolicyTypes" (list "Ingress" "Egress") -}}
{{- $_ := set $np "IngressTemplate" "publicapi.np.ingress" -}}
{{- $_ := set $np "EgressTemplate" "publicapi.np.egress" -}}
{{ include "ag-template.networkpolicy" $np }}
{{- end }}

{{- define "publicapi.np.ingress" }}
- from:
    # Router ingress
    - namespaceSelector:
        matchLabels:
          network.openshift.io/policy-group: ingress
  ports:
    - protocol: TCP
      port: 8082
{{- end }}

{{- define "publicapi.np.egress" }}
- to:
    # HTTPS egress
    - ipBlock:
        cidr: 0.0.0.0/0
  ports:
    - protocol: TCP
      port: 443
{{- end }}
```

Important limitations:

- NetworkPolicy cannot restrict by DNS hostname; only IP/CIDR/namespace/pod selectors.
- If you need “only allow *.github.com”, that’s typically enforced with platform egress controls (EgressFirewall/EgressIP, proxy, or service mesh), not pure NetworkPolicy.

### Recipe: Create a NetworkPolicy (service → service, service → Postgres)

When your backend needs to call Postgres, you need explicit egress to the Postgres pods/service.

Typical rule shape:

```yaml
- to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: postgresql
  ports:
    - protocol: TCP
      port: 5432
```

If your Postgres chart labels differ, match what is actually on the rendered Postgres pods.

Render locally and check the labels on the Postgres StatefulSet/pods inside the rendered YAML.

### Recipe: Add a one-off Job for connectivity testing

Use a Job when you want a repeatable, disposable check like:

- “Can I reach https://example.gov.bc.ca?”
- “Can I reach the Postgres service on 5432?”

Use `ag-template.job` and pair it with a NetworkPolicy scoped to the job’s pod labels.

Reference patterns in this repo:

- Job usage: `shared-lib/example-app/templates/job.yaml`
- NP usage: `shared-lib/example-app/templates/networkpolicy.yaml`
- Existing job NP example: `charts/{{cookiecutter.charts_dir}}/gitops/templates/pg-job-networkpolicy.yaml`

Rule of thumb: the Job should have the minimum egress it needs (one target/namespace/CIDR), otherwise you’re testing with overly-permissive access.

### Recipe: Use Secrets (without committing credentials)

In zero-trust GitOps, **values files should reference secrets**, not contain secrets.

Patterns you can use:

1) “Existing Secret” values (best when your platform provisions secrets out-of-band)

```yaml
backend:
  database:
    existingSecret: myapp-database
    existingSecretKey: connection-string
```

2) `extraEnv` with `valueFrom.secretKeyRef`

```yaml
backend:
  extraEnv:
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: myapp-api-key
          key: api-key
```

3) Mounted secret file (when the app supports file-based config)

```yaml
backend:
  volumes:
    - name: secrets
      secret:
        secretName: myapp-secrets
  volumeMounts:
    - name: secrets
      mountPath: /var/run/secrets/myapp
      readOnly: true
```

Where the secret comes from depends on your platform:

- manually created Secret
- ExternalSecrets operator
- sealed-secrets

This repo intentionally doesn’t pick one—your platform standard should.

### Recipe: Use ConfigMaps/files

Use this when your app needs config files (JSON/YAML) instead of env vars.

1) Create a ConfigMap template (or rely on an existing one)
2) Mount it using `volumes` + `volumeMounts` in values

Example values:

```yaml
backend:
  volumes:
    - name: config
      configMap:
        name: myapp-config
  volumeMounts:
    - name: config
      mountPath: /app/config
      readOnly: true
```

### Recipe: Promote dev → test → prod (branch-based)

This template maps environments to branches:

- dev: `develop`
- test: `test`
- prod: `main`

Promotion flow:

1) Merge your change into `develop` (dev deploy)
2) If dev is good: merge/cherry-pick to `test`
3) If test is good: merge/cherry-pick to `main`

If your organization uses release tags, you can also pin Helm image tags/digests and promote the same artifact across environments.

### Recipe: Troubleshoot “nothing can talk to anything”

In a deny-by-default environment, assume NetworkPolicy first.

Checklist:

1) Do pods exist and are they Ready?

```bash
kubectl -n <ns> get pods -o wide
kubectl -n <ns> describe pod <pod>
```

2) Do pods have the expected labels?

```bash
kubectl -n <ns> get pod --show-labels
```

3) Does the NetworkPolicy select the pods you think it selects?

```bash
kubectl -n <ns> get networkpolicy
kubectl -n <ns> describe networkpolicy <name>
```

4) Is DNS allowed?

If DNS isn’t allowed, most apps look “down” even if they’re running.

5) If using Route: is router ingress allowed?

If router ingress isn’t allowed, your Route will be up but traffic won’t reach pods.

### Recipe: Add HPA autoscaling to a service

When a service is CPU/memory sensitive, add autoscaling.

1) In values:

```yaml
worker:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80
    # targetMemoryUtilizationPercentage: 80
```

2) Add `worker-hpa.yaml` (pattern matches existing backend/frontend HPAs):

```yaml
{{- if and .Values.worker.enabled .Values.worker.autoscaling.enabled }}
{{- $p := dict "Values" .Values.worker -}}
{{- $_ := set $p "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $p "Name" "worker" -}}
{{- $_ := set $p "ModuleValues" (dict
  "autoscaling" .Values.worker.autoscaling
) -}}
{{ include "ag-template.hpa" $p }}
{{- end }}
```

Notes:

- HPA requires resource requests to be set (CPU/memory requests).

### Recipe: Add a PodDisruptionBudget (PDB)

PDBs prevent voluntary disruptions (drains/evictions) from taking all replicas down.

Prefer the shared ag-helm helper (`ag-template.pdb`) instead of writing raw PDB YAML by hand.

1) Configure PDB behavior in values (per service):

```yaml
worker:
  pdb:
    disabled: false
    # Choose ONE of these:
    # minAvailable: 1
    maxUnavailable: "10%"
```

2) Add `worker-pdb.yaml` using the shared helper:

```yaml
{{- if .Values.worker.enabled }}
{{- $p := dict "Values" .Values.worker -}}
{{- $_ := set $p "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $p "Name" "worker" -}}
{{- $_ := set $p "Namespace" $.Release.Namespace -}}
{{- $_ := set $p "ModuleValues" (dict
  "pdb" (default (dict) .Values.worker.pdb)
) -}}
{{- $_ := set $p "LabelData" "worker.pod.labels" -}}
{{ include "ag-template.pdb" $p }}
{{- end }}
```

Minimum raw PDB example (only if you really can’t use the helper):

```yaml
{{- if and .Values.worker.enabled (gt (int (default 1 .Values.worker.replicaCount)) 1) }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ printf "%s-worker" .Release.Name }}
  labels:
    {{- include "gitops.labels" . | nindent 4 }}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: worker
      app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### Recipe: Use PriorityClass for “keep this up first” workloads

This repo already includes a PriorityClass template.

In values:

```yaml
priorityClass:
  enabled: true
  name: myapp-high
  value: 100000
```

Then set it on your workloads (check how your deployment template maps values into the library; many patterns expose `priorityClassName` or pod spec overrides via fragments).

### Recipe: Add topology spread constraints (avoid single-node pileups)

This improves availability during node drains.

Add to values (service-specific if the template supports it):

```yaml
worker:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: worker
          app.kubernetes.io/instance: myapp
```

If your template doesn’t wire this into the pod spec yet, add it via a pod-template fragment in the service’s deployment template (same “define + include” approach as ports/env).

### Recipe: Add liveness/readiness/startup probes (keep traffic safe)

Probes are the difference between “pod running” and “service healthy”.

Create a `publicapi.probes` fragment in your deployment template file and attach it via the library’s `Probes` hook (if used by your deployment template pattern).

Example fragment (HTTP):

```yaml
{{- define "publicapi.probes" }}
readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 15
  periodSeconds: 10
{{- end }}
```

If your app is not HTTP, use TCP probes.

### Recipe: Add a ServiceAccount (and keep token automount explicit)

In zero-trust environments, be explicit about whether pods need Kubernetes API access.

- If your service does NOT talk to the Kubernetes API: set `automountServiceAccountToken: false`.
- If it DOES: create a dedicated SA and RBAC.

ServiceAccount values pattern:

```yaml
worker:
  serviceAccount:
    create: true
    name: myapp-worker
    automount: false
    annotations: {}
```

### Recipe: Pull from a private registry (imagePullSecrets)

1) Create the pull secret in the namespace.
2) Reference it in values.

Example values:

```yaml
worker:
  imagePullSecrets:
    - name: regcred
```

If the deployment template doesn’t wire `imagePullSecrets` into the pod spec yet, add it via the library hook (many patterns support it).

### Recipe: Make external egress explicit (and safe)

If your service needs to call an external API:

- Add HTTPS egress in its NetworkPolicy.
- Prefer a platform egress gateway/proxy if you need destination restrictions.

Minimum NP egress rule (HTTPS):

```yaml
- to:
    - ipBlock:
        cidr: 0.0.0.0/0
  ports:
    - protocol: TCP
      port: 443
```

If you need to restrict destinations, do it with platform controls (egress firewall/proxy/service mesh), not plain NetworkPolicy.

### Recipe: Add a CronJob (scheduled work) + NetworkPolicy

Use this for periodic tasks (cleanup, reports, notifications).

Approach:

1) Create a CronJob template (or use a library helper if you have one)
2) Give it explicit pod labels
3) Add a NetworkPolicy that selects those labels and allows only what it needs

Tip: treat CronJobs like production workloads (resources, labels, policies, secrets).

### Recipe: Add persistent storage (PVC)

Use PVCs for workloads that truly require persistence (most stateless services should not).

At a minimum:

1) Define a PVC (template)
2) Mount it using `volumes` and `volumeMounts`

Example values:

```yaml
worker:
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: myapp-worker-data
  volumeMounts:
    - name: data
      mountPath: /data
```

### Recipe: Add a new Conftest policy (organization rules)

If you need to enforce a rule (for example, “every workload must have a NetworkPolicy”), add a Rego policy under the policy folder used by the validation workflow.

Workflow uses Conftest with `--policy` pointing at the chart policy folder.

Suggested approach:

1) Add a new `.rego` file with a clear name (one rule per file is easier to maintain)
2) Add a short example and rationale in the header comment
3) Render manifests and run Conftest locally via `test-all-validations.sh`

### Recipe: Make your change “scanner-friendly” (avoid future pipeline pain)

Most failures come from a few categories:

- Missing labels (`owner`, `environment`, `project`)
- Missing NetworkPolicy per workload
- Missing resources requests/limits
- Secrets committed into values
- Router ingress not allowed for Route-exposed services

Before pushing, do a quick self-check on your rendered YAML:

```bash
helm template myapp charts/*/gitops --values deploy/*/dev_values.yaml > /tmp/rendered.yaml

# Workloads
grep -n "kind: Deployment\|kind: StatefulSet\|kind: Job\|kind: CronJob" /tmp/rendered.yaml | head

# Network policies exist
grep -n "kind: NetworkPolicy" /tmp/rendered.yaml | head

# Required labels often enforced by org policy
grep -n "owner:\|environment:\|project:" /tmp/rendered.yaml | head
```

### Minimum required “identity” values

Most org policies require consistent labels. At minimum, set these in each env values file:

```yaml
project: myapp
owner: myteam
environment: dev   # dev|test|prod
env: dev           # some org rules require a short env label
```

### Frontend example

```yaml
frontend:
  enabled: true
  image:
    repository: ghcr.io/my-org
    name: myapp-frontend
    tag: "1.2.3"
  route:
    enabled: true
    host: myapp-abc123-dev.apps.emerald.devops.gov.bc.ca
  dataClass: medium
  podLabels:
    DataClass: "Medium"
```

### Backend example + secret-based DB connection

Prefer Secret references. In this template, the backend supports referencing an existing Secret for the connection string (instead of committing it in git).

```yaml
backend:
  enabled: true
  image:
    repository: ghcr.io/my-org
    name: myapp-backend
    tag: "1.2.3"
  dataClass: high
  podLabels:
    DataClass: "High"
  database:
    existingSecret: myapp-database
    existingSecretKey: connection-string
```

Create the Secret out-of-band (example):

```bash
kubectl -n abc123-dev create secret generic myapp-database \
  --from-literal=connection-string='Host=myapp-postgresql;Port=5432;Database=appdb;Username=appuser;Password=REDACTED'
```

### PostgreSQL example (Secret-based auth)

The Postgres chart is typically configured to use an existing Secret for credentials.

```yaml
postgresql:
  enabled: true
  fullnameOverride: myapp-postgresql
  auth:
    existingSecret: myapp-postgresql-auth
```

Create the Secret out-of-band (example):

```bash
kubectl -n abc123-dev create secret generic myapp-postgresql-auth \
  --from-literal=postgres-password='REDACTED' \
  --from-literal=password='REDACTED'
```

## Connectivity testing in a deny-by-default cluster

### Quick “is DNS working?” check

After Argo sync (or helm install), run:

```bash
bash scripts/test-network-policies.sh abc123-dev myapp
```

This verifies:

- NetworkPolicies exist
- Pods have DataClass labels
- DNS resolution works from a running pod (best-effort)

### Pattern: Add a dedicated connectivity-test Job + tight egress policy

If you need a repeatable connectivity check (e.g., “can I reach external HTTPS?”), create a one-off Job/Pod and pair it with a strict egress policy.

Reference examples in this repository:

- A Job pattern: `shared-lib/example-app/templates/job.yaml`
- A NetworkPolicy pattern: `shared-lib/example-app/templates/networkpolicy.yaml`
- A Postgres backup job egress policy: `charts/{{cookiecutter.charts_dir}}/gitops/templates/pg-job-networkpolicy.yaml`

Important: keep these tests explicit and minimal (only the required target ports). Don’t add `0.0.0.0/0` unless the purpose is specifically to validate outbound internet access.

## Adding a new component (service) safely

When adding a new component (worker, api-v2, scheduler), treat it as a checklist:

1) Values:
- `enabled: true`
- `image.repository/name/tag`
- `resources.requests/limits`
- `dataClass` + `podLabels.DataClass`

2) Templates:
- Deployment
- Service (if it needs to be reached)
- NetworkPolicy (always)
- Optional: HPA, PDB

3) Validate locally:
- `bash ./test-all-validations.sh`

For the library wiring pattern, see:

- `docs/architecture.md` (how `ag-template.deployment` is used)

### Recipe: Add a new service (example: `worker`)

This recipe shows the **minimum** you need to add a new component using the same patterns as the existing frontend/backend templates.

#### Step 1 — Add values (per environment)

In your env file (e.g., `deploy/<your-deploy-dir>/dev_values.yaml`):

```yaml
worker:
  enabled: true

  # Required labels/policy inputs
  dataClass: medium
  podLabels:
    DataClass: "Medium"

  image:
    repository: ghcr.io/my-org
    name: myapp-worker
    tag: "1.2.3"
    pullPolicy: IfNotPresent

  replicaCount: 1

  service:
    type: ClusterIP
    port: 8081

  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
```

#### Step 2 — Create `worker` Deployment template

Create `charts/<your-charts-dir>/gitops/templates/worker-deployment.yaml`:

```yaml
{{- define "worker.ports" }}
- name: http
  containerPort: {{ .Values.service.port }}
  protocol: TCP
{{- end }}

{{- define "worker.env" }}
- name: LOG_LEVEL
  value: "info"
{{- end }}

{{- if .Values.worker.enabled }}
{{- $p := dict "Values" .Values.worker -}}
{{- $_ := set $p "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $p "Name" (default "worker" .Values.worker.image.name) -}}
{{- $_ := set $p "Registry" .Values.worker.image.repository -}}
{{- $_ := set $p "ModuleValues" (dict
  "image" (dict
    "tag" .Values.worker.image.tag
    "pullPolicy" .Values.worker.image.pullPolicy
  )
  "replicas" .Values.worker.replicaCount
  "resources" .Values.worker.resources
  "dataClass" .Values.worker.dataClass
) -}}
{{- $_ := set $p "Ports" "worker.ports" -}}
{{- $_ := set $p "Env" "worker.env" -}}
{{ include "ag-template.deployment" $p }}
{{- end }}
```

Notes:

- `dataClass` is passed to the library so the pod gets the `data-class` label.
- Keep the port/env fragments in the same file so intent is close to usage.

#### Step 3 — Create `worker` Service template (if it needs to be reached)

Create `charts/<your-charts-dir>/gitops/templates/worker-service.yaml`:

```yaml
{{- if .Values.worker.enabled }}
{{- $p := dict "Values" .Values.worker -}}
{{- $_ := set $p "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $p "Name" "worker" -}}
{{- $_ := set $p "ModuleValues" (dict "service" .Values.worker.service) -}}
{{ include "ag-template.service" $p }}
{{- end }}
```

#### Step 4 — Create a NetworkPolicy (always)

Create `charts/<your-charts-dir>/gitops/templates/worker-networkpolicy.yaml`.

You have three options:

Option A: use the **simple inputs** (good for “same-namespace ingress + HTTPS egress”)

```yaml
{{- if .Values.worker.enabled }}
{{ include "ag-template.networkpolicy" (dict
  "ApplicationGroup" (default .Values.project "app")
  "Name" "worker"
  "Namespace" .Release.Namespace
  "IngressPorts" (list 8081)
  "EgressHTTPS" true
) }}
{{- end }}
```

Option B: use the **intent inputs** (recommended for app-to-app rules and allowlists)

```yaml
{{- if .Values.worker.enabled }}
{{- $np := dict "Values" .Values -}}
{{- $_ := set $np "ApplicationGroup" (default .Values.project "app") -}}
{{- $_ := set $np "Name" "worker" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}

{{- $_ := set $np "AllowIngressFrom" (dict
  "ports" (list 8081)
  "namespaces" (list (dict
    "namespaceSelector" (dict "matchLabels" (dict "kubernetes.io/metadata.name" $.Release.Namespace))
  ))
) -}}

{{- $_ := set $np "AllowEgressTo" (dict
  "apps" (list (dict "name" "postgresql" "ports" (list 5432)))
  "ipBlocks" (list (dict "cidr" "0.0.0.0/0" "ports" (list 443)))
) -}}

{{ include "ag-template.networkpolicy" $np }}
{{- end }}
```

Option C: use the **full template** (recommended once you need very specific selectors or raw NetworkPolicy features)

```yaml
{{- if .Values.worker.enabled }}
{{- $np := dict "ApplicationGroup" (default .Values.project "app") "Name" "worker" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}
{{- $_ := set $np "PolicyTypes" (list "Ingress" "Egress") -}}
{{- $_ := set $np "IngressTemplate" "worker.np.ingress" -}}
{{- $_ := set $np "EgressTemplate" "worker.np.egress" -}}
{{ include "ag-template.networkpolicy" $np }}
{{- end }}

{{- define "worker.np.ingress" }}
- from:
    # Allow from same namespace only (tight default)
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: {{ .Namespace }}
  ports:
    - protocol: TCP
      port: 8081
{{- end }}

{{- define "worker.np.egress" }}
- to:
    # Allow HTTPS egress (if your worker calls external APIs)
    - ipBlock:
        cidr: 0.0.0.0/0
  ports:
    - protocol: TCP
      port: 443
{{- end }}
```

#### Step 5 — Validate

Run the local suite:

```bash
bash ./test-all-validations.sh
```

If the suite is green and the rendered output includes your Deployment + NetworkPolicy, you’re aligned with the platform rules.

## Policy enforcement and “what will block my PR”

This repo contains GitHub Actions workflows that render Helm manifests and run policy/security tools.

Key workflows:

- `validate-network-policies.yaml` and `validate-network-policies-comprehensive.yaml`
  - Render + Conftest + Polaris + Kubesec + Trivy + Checkov + more
- `policy-enforcement.yaml`
  - Datree Helm policy enforcement (usually uses a token)

Local equivalence:

- `test-all-validations.sh` (Windows-friendly local runner)

## Troubleshooting (common zero-trust failures)

### Symptom: “Frontend Route exists but page won’t load”

Usually one of:

- Route points to wrong Service name/port
- NetworkPolicy blocks router ingress
- Pod not Ready

Start with:

```bash
kubectl -n abc123-dev get route,svc,endpoints,pods
kubectl -n abc123-dev describe networkpolicy
```

### Symptom: “Backend can’t connect to Postgres”

Usually:

- Missing egress from backend → Postgres
- Postgres Service name mismatch
- Secret missing / wrong key

Start with:

```bash
kubectl -n abc123-dev get svc | grep postgresql
kubectl -n abc123-dev get secret myapp-database -o yaml
kubectl -n abc123-dev logs deployment/myapp-backend
```

More troubleshooting examples:

- `docs/troubleshooting.md`

## Notes for platform maintainers (RBAC template)

The RBAC template under `rbac/` contains placeholder subjects and should be treated as an example only.

Before using in production:

- Replace users/groups with your org’s actual identity provider groups
- Consider generating RoleBindings per environment namespace as part of a platform pipeline

## Glossary

- **License Plate**: 6-character identifier used in namespaces and repo naming.
- **Tenant GitOps repo**: the per-license-plate GitOps repository Argo CD syncs from.
- **DataClass**: Low/Medium/High classification used to drive network policy behavior.
- **Deny-by-default**: you must explicitly allow ingress/egress.
