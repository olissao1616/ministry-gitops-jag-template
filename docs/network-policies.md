# Network Policy Guide

## Overview

This template implements **data classification-based network policies** to control pod-to-pod communication. Network access is determined by the **data classification level** assigned to each service.

## Data Classification Levels

BC Government Justice applications use three data classification levels:

| Level | Description | Access Control |
|-------|-------------|----------------|
| **Low** | Public or non-sensitive data | Can communicate with: Low only |
| **Medium** | Confidential data | Can communicate with: Low, Medium |
| **High** | Highly sensitive/protected data | Can communicate with: Low, Medium, High |

### Default Deny Rule

**IMPORTANT:** Pods without a data classification tag are **denied all communication by default**.

## How It Works

### 1. Data Classification Labels

Every deployed pod receives a `DataClass` label:

```yaml
metadata:
  labels:
    DataClass: "Medium"    # Applied to pod
    data-class: "medium"   # Lowercase variant for selectors
```

### 2. Network Policy Creation

The template automatically generates network policies that:
- **Allow** communication based on data classification rules
- **Deny** communication from higher classification to lower classification
- **Deny** communication from/to pods without classification

### 3. Communication Matrix

```
┌─────────────┬──────────────────────────────────┐
│ Source →    │ Can Communicate With             │
│ Target ↓    │                                  │
├─────────────┼──────────────────────────────────┤
│ No Label    │ DENIED (all communication)       │
│ Low         │ Low only                         │
│ Medium      │ Low, Medium                      │
│ High        │ Low, Medium, High (all)          │
└─────────────┴──────────────────────────────────┘
```

## Configuration

### Setting Data Classification

In your values file (`dev_values.yaml`, `prod_values.yaml`):

```yaml
frontend:
  enabled: true
  dataClass: "medium"    # Set classification level
  podLabels:
    DataClass: "Medium"  # Applied as pod label

backend:
  enabled: true
  dataClass: "high"      # Backend handles sensitive data
  podLabels:
    DataClass: "High"
```

### Valid Values

```yaml
dataClass: "low"     # or "Low"
dataClass: "medium"  # or "Medium"
dataClass: "high"    # or "High"
```

**Case Insensitive:** The template handles both lowercase and capitalized versions.

## Network Policy Templates

### Frontend Network Policy

**Location:** `templates/frontend-networkpolicy.yaml`

Generated network policy for frontend:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-frontend
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: frontend
  policyTypes:
    - Ingress
    - Egress

  ingress:
    # Allow traffic from pods with same or lower classification
    - from:
      - podSelector:
          matchExpressions:
            - key: data-class
              operator: In
              values:
                - low           # Frontend=Medium allows Low
                - medium        # Frontend=Medium allows Medium
      ports:
        - protocol: TCP
          port: 8000

    # Allow traffic from ingress controller/routes
    - from:
      - namespaceSelector:
          matchLabels:
            network.openshift.io/policy-group: ingress

  egress:
    # Allow traffic to pods with same or higher classification
    - to:
      - podSelector:
          matchExpressions:
            - key: data-class
              operator: In
              values:
                - medium        # Frontend=Medium can call Medium
                - high          # Frontend=Medium can call High

    # Allow external API calls (if needed)
    - to:
      - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443  # HTTPS
        - protocol: TCP
          port: 80   # HTTP
```

### Backend Network Policy

**Location:** `templates/backend-networkpolicy.yaml`

Similar structure but tailored for backend services:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-backend
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: backend
  policyTypes:
    - Ingress
    - Egress

  ingress:
    # Allow from frontend (if frontend classification allows)
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: frontend
      ports:
        - protocol: TCP
          port: 8080

  egress:
    # Allow to database
    - to:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: postgresql
      ports:
        - protocol: TCP
          port: 5432
```

## Common Scenarios

### Scenario 1: Frontend (Medium) → Backend (High)

```yaml
frontend:
  dataClass: "medium"

backend:
  dataClass: "high"
```

**Result:** ✅ **ALLOWED**
- Medium can communicate with High (higher classification)
- Backend accepts traffic from Medium

### Scenario 2: Backend (High) → External API (Medium)

```yaml
backend:
  dataClass: "high"
```

**Result:** ✅ **ALLOWED**
- High can communicate with everything
- Egress to external services allowed

### Scenario 3: Frontend (Low) → Backend (High)

```yaml
frontend:
  dataClass: "low"

backend:
  dataClass: "high"
```

**Result:** ✅ **ALLOWED**
- Low can communicate upward to High
- But backend cannot initiate communication back to frontend

### Scenario 4: Backend (High) → Frontend (Low)

```yaml
backend:
  dataClass: "high"

frontend:
  dataClass: "low"
```

**Result:** ❌ **DENIED**
- High cannot push data to Low (data leakage prevention)
- Frontend must initiate the connection

### Scenario 5: No Data Classification

```yaml
frontend:
  enabled: true
  # dataClass not set
```

**Result:** ❌ **DENIED ALL**
- Pod without classification cannot communicate
- Must set dataClass explicitly

## Advanced Configuration

### Custom Network Policies

To add custom rules, create additional network policy templates:

**Example:** Allow frontend to call external API

```yaml
# templates/frontend-external-api-policy.yaml
{{- if .Values.frontend.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ printf "%s-frontend-external-api" .Release.Name }}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: frontend
  policyTypes:
    - Egress
  egress:
    # Allow HTTPS to specific external API
    - to:
      - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
      # Optional: Add IP block for specific API
      # - to:
      #   - ipBlock:
      #       cidr: 142.34.0.0/16
{{- end }}
```

### Allowing Cross-Namespace Communication

To allow communication with services in another namespace:

```yaml
egress:
  - to:
    # Allow to SSO service in gold cluster
    - namespaceSelector:
        matchLabels:
          name: e27db1-dev    # SSO namespace
      podSelector:
        matchLabels:
          app: sso-service
    ports:
      - protocol: TCP
        port: 8080
```

### Allowing Specific IP Ranges

To allow traffic from/to specific IP ranges:

```yaml
ingress:
  - from:
    # Allow from on-premise network
    - ipBlock:
        cidr: 142.34.0.0/16
        except:
          - 142.34.1.0/24    # Except this subnet
```

## Data Classification Guidelines

### When to Use Each Level

#### Low (Public Data)
- Public-facing web content
- Static assets (images, CSS, JS)
- Non-authenticated APIs
- Public documentation

**Example:**
```yaml
static-content:
  dataClass: "low"
```

#### Medium (Confidential Data)
- User-authenticated applications
- Business data
- Internal APIs
- User profiles (non-sensitive)

**Example:**
```yaml
frontend:
  dataClass: "medium"
backend:
  dataClass: "medium"
```

#### High (Sensitive/Protected Data)
- Personal information (PII)
- Financial data
- Health records
- Legal documents
- Administrative functions

**Example:**
```yaml
admin-api:
  dataClass: "high"
database:
  dataClass: "high"
```

## Troubleshooting

### Issue: Pods Cannot Communicate

**Diagnosis:**
```bash
# Check network policies
kubectl get networkpolicies -n abc123-dev

# Describe specific policy
kubectl describe networkpolicy app-frontend -n abc123-dev

# Check pod labels
kubectl get pods -n abc123-dev --show-labels
```

**Common Causes:**

**1. Missing dataClass label**
```yaml
# Fix: Add dataClass to values
frontend:
  dataClass: "medium"
  podLabels:
    DataClass: "Medium"
```

**2. Incorrect classification level**
```yaml
# Problem: Frontend (High) trying to send to Backend (Low)
frontend:
  dataClass: "high"   # Cannot send data to lower classification
backend:
  dataClass: "low"

# Fix: Adjust classification levels appropriately
frontend:
  dataClass: "medium"
backend:
  dataClass: "high"
```

**3. Network policy not created**
```bash
# Check if network policy exists
kubectl get networkpolicy -n abc123-dev

# If missing, check values
frontend:
  networkPolicy:
    enabled: true  # Ensure enabled
```

### Issue: External API Calls Blocked

**Diagnosis:**
```bash
# Test from pod
kubectl exec -it myapp-frontend-xxx -n abc123-dev -- curl https://api.external.com

# Check egress rules
kubectl describe networkpolicy app-frontend -n abc123-dev | grep -A 10 "Egress"
```

**Solution:** Add egress rule for external traffic:

```yaml
# In values file
frontend:
  networkPolicy:
    allowExternalEgress: true
```

Or create custom network policy (see Advanced Configuration above).

### Issue: Database Connection Blocked

**Diagnosis:**
```bash
# Test database connection from backend
kubectl exec -it myapp-backend-xxx -n abc123-dev -- nc -zv myapp-postgresql 5432
```

**Solution:** Ensure proper egress/ingress rules:

```yaml
backend:
  dataClass: "high"      # Backend classification
  networkPolicy:
    enabled: true

postgresql:
  dataClass: "high"      # Database same or higher
  networkPolicy:
    enabled: true
```

## Testing Network Policies

### Test Communication Between Pods

```bash
# Get pod names
kubectl get pods -n abc123-dev

# Test frontend → backend
kubectl exec -it myapp-frontend-xxx -n abc123-dev -- \
  curl -v http://myapp-backend:8080/api/health

# Test backend → database
kubectl exec -it myapp-backend-xxx -n abc123-dev -- \
  nc -zv myapp-postgresql 5432

# Should return: Connection to myapp-postgresql 5432 port [tcp/postgresql] succeeded!
```

### Test Blocked Communication

```bash
# Try to access from pod without proper classification
# Should fail or timeout

kubectl run test-pod --image=curlimages/curl --rm -it -- \
  curl http://myapp-backend:8080
```

### Verify Network Policy Rules

```bash
# View all network policies
kubectl get networkpolicies -n abc123-dev -o yaml

# Check specific policy rules
kubectl describe networkpolicy app-backend -n abc123-dev
```

## Best Practices

### 1. Always Set Data Classification

```yaml
# Good
frontend:
  enabled: true
  dataClass: "medium"

# Bad - will be denied by default
frontend:
  enabled: true
```

### 2. Use Appropriate Classification

```yaml
# Good - backend handles sensitive data
backend:
  dataClass: "high"
database:
  dataClass: "high"

# Bad - exposing high classification data through low classification frontend
frontend:
  dataClass: "low"
backend:
  dataClass: "high"   # Frontend can't receive responses!
```

### 3. Document Classification Decisions

```yaml
frontend:
  # Classification: Medium - handles user authentication and personal data
  dataClass: "medium"

backend:
  # Classification: High - processes financial transactions
  dataClass: "high"
```

### 4. Test Network Policies in Dev First

```bash
# Deploy to dev
helm install myapp . --values dev_values.yaml -n abc123-dev

# Test all communication paths
bash scripts/test-network-policies.sh abc123-dev myapp
```

### 5. Review Network Policies Regularly

- Audit network policies quarterly
- Review classification levels when adding features
- Update policies when integrating new services

## Network Policy Creation - DOs and DON'Ts

### ✅ DO's - Best Practices

#### DO: Use Specific Label Selectors

```yaml
# ✅ GOOD - Specific label selector
ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: backend
          app.kubernetes.io/instance: myapp
```

**Why:** Precise targeting prevents unintended access.

#### DO: Specify Both Ingress and Egress

```yaml
# ✅ GOOD - Explicit about both directions
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: myapp-frontend
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: frontend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from: [...]
  egress:
    - to: [...]
```

**Why:** Makes intent clear and prevents accidental open policies.

#### DO: Use Port Restrictions

```yaml
# ✅ GOOD - Specific ports only
ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
      - protocol: TCP
        port: 8080
```

**Why:** Limits attack surface to only necessary ports.

#### DO: Use CIDR Blocks for External Access

```yaml
# ✅ GOOD - Specific IP ranges
egress:
  - to:
    - ipBlock:
        cidr: 142.34.0.0/16
        except:
          - 142.34.1.0/24
    ports:
      - protocol: TCP
        port: 443
```

**Why:** Restricts external access to known networks.

#### DO: Document Business Justification

```yaml
# ✅ GOOD - Documented policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-external-api
  annotations:
    purpose: "Allow OAuth authentication to Keycloak"
    approvedBy: "security-team@justice.gov.bc.ca"
    expiryDate: "2027-02-10"
spec:
  # ...
```

**Why:** Makes auditing and reviews easier.

#### DO: Use matchExpressions for Complex Logic

```yaml
# ✅ GOOD - Flexible matching
ingress:
  - from:
    - podSelector:
        matchExpressions:
          - key: data-class
            operator: In
            values:
              - low
              - medium
          - key: environment
            operator: NotIn
            values:
              - test
```

**Why:** More powerful than simple label matching.

#### DO: Test Policies Before Production

```bash
# ✅ GOOD - Test in dev first
helm install myapp . --values dev_values.yaml -n abc123-dev
kubectl exec test-pod -n abc123-dev -- curl myapp-backend:8080
```

**Why:** Prevents production outages.

### ❌ DON'T's - Anti-Patterns

#### DON'T: Use Empty PodSelector (Wildcard)

```yaml
# ❌ BAD - Applies to ALL pods in namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all
spec:
  podSelector: {}  # DANGEROUS - matches everything
  ingress:
    - {}
```

**Why:** This creates a blanket allow rule affecting all pods, bypassing data classification.

**Fix:**
```yaml
# ✅ GOOD - Specific pod selector
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: frontend
```

#### DON'T: Allow All Ingress Traffic

```yaml
# ❌ BAD - Allows everything
ingress:
  - {}  # DANGEROUS - allows all sources
```

**Why:** Defeats the purpose of network policies.

**Fix:**
```yaml
# ✅ GOOD - Specific sources
ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    - namespaceSelector:
        matchLabels:
          name: monitoring
```

#### DON'T: Allow All Egress Traffic

```yaml
# ❌ BAD - Unrestricted egress
egress:
  - {}  # DANGEROUS - allows all destinations
```

**Why:** Data exfiltration risk.

**Fix:**
```yaml
# ✅ GOOD - Specific destinations
egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
      - protocol: TCP
        port: 8080
```

#### DON'T: Use 0.0.0.0/0 Without Justification

```yaml
# ❌ BAD - Allows entire internet
egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0  # DANGEROUS - entire internet
```

**Why:** Massive security risk, allows data exfiltration.

**Fix:**
```yaml
# ✅ GOOD - Specific external services
egress:
  - to:
    - ipBlock:
        cidr: 142.34.208.0/24  # Specific service IP range
    ports:
      - protocol: TCP
        port: 443
```

**Exception:** If you must allow all external access, document it:
```yaml
# ⚠️ USE WITH CAUTION - Document justification
egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
          - 10.0.0.0/8      # Block internal networks
          - 172.16.0.0/12
          - 192.168.0.0/16
    ports:
      - protocol: TCP
        port: 443  # HTTPS only
metadata:
  annotations:
    justification: "Service requires access to multiple third-party APIs"
    approvedBy: "security-team@justice.gov.bc.ca"
```

#### DON'T: Forget Port Restrictions

```yaml
# ❌ BAD - No port restriction
ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
  # Missing: ports section
```

**Why:** Allows access to ALL ports.

**Fix:**
```yaml
# ✅ GOOD - Specific ports
ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
      - protocol: TCP
        port: 8080
```

#### DON'T: Mix Label Operators Incorrectly

```yaml
# ❌ BAD - Contradictory logic
podSelector:
  matchLabels:
    app: frontend
  matchExpressions:
    - key: app
      operator: NotIn
      values:
        - frontend
# This will NEVER match anything!
```

**Why:** matchLabels and matchExpressions are AND'd together.

**Fix:**
```yaml
# ✅ GOOD - Consistent logic
podSelector:
  matchExpressions:
    - key: app
      operator: In
      values:
        - frontend
        - backend
    - key: tier
      operator: NotIn
      values:
        - test
```

#### DON'T: Create Overlapping Policies

```yaml
# ❌ BAD - Multiple policies targeting same pods
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-1
spec:
  podSelector:
    matchLabels:
      app: frontend
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: backend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-2
spec:
  podSelector:
    matchLabels:
      app: frontend  # Same selector!
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: database
```

**Why:** Hard to understand cumulative effect (policies are OR'd, creating confusion).

**Fix:**
```yaml
# ✅ GOOD - Single comprehensive policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
spec:
  podSelector:
    matchLabels:
      app: frontend
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: backend
      - podSelector:
          matchLabels:
            app: database
```

#### DON'T: Use Only matchLabels for Complex Scenarios

```yaml
# ❌ BAD - Can't express "all except test"
podSelector:
  matchLabels:
    environment: production  # What about dev?
```

**Fix:**
```yaml
# ✅ GOOD - Use matchExpressions for exclusions
podSelector:
  matchExpressions:
    - key: environment
      operator: NotIn
      values:
        - test
        - sandbox
```

#### DON'T: Skip Data Classification

```yaml
# ❌ BAD - No data classification
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-frontend
spec:
  template:
    metadata:
      labels:
        app: frontend
        # Missing: DataClass label
```

**Why:** Pods without DataClass are denied all communication.

**Fix:**
```yaml
# ✅ GOOD - Data classification set
spec:
  template:
    metadata:
      labels:
        app: frontend
        DataClass: "Medium"
        data-class: "medium"
```

### Wildcard Usage Guidelines

#### When to Use `{}` (Empty Selector)

**✅ Acceptable use cases:**

1. **Allow all pods in namespace (rare)**
   ```yaml
   # Use only for monitoring/logging services
   ingress:
     - from:
       - namespaceSelector:
           matchLabels:
             name: monitoring
         podSelector: {}  # All pods in monitoring namespace
   ```

2. **Allow from any namespace**
   ```yaml
   # For shared services like DNS
   ingress:
     - from:
       - namespaceSelector: {}  # Any namespace
         podSelector:
           matchLabels:
             k8s-app: kube-dns
   ```

3. **Default deny policy**
   ```yaml
   # Creates default deny for all pods
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: default-deny-all
   spec:
     podSelector: {}  # Apply to all pods
     policyTypes:
       - Ingress
       - Egress
   # No ingress/egress rules = deny all
   ```

**❌ Never use:**

```yaml
# ❌ NEVER - Allows everything
spec:
  podSelector: {}
  ingress:
    - {}
  egress:
    - {}
```

### Port Wildcard Rules

#### DON'T: Omit Ports Section

```yaml
# ❌ BAD - Allows ALL ports
ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
  # Missing ports = all ports allowed
```

#### DO: Be Explicit About Ports

```yaml
# ✅ GOOD - Specific ports only
ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
      - protocol: TCP
        port: 8080
      - protocol: TCP
        port: 8443
```

### CIDR Block Best Practices

#### DON'T: Use Broad Ranges

```yaml
# ❌ BAD - Entire private network
egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8  # 16 million IPs!
```

#### DO: Use Narrow Ranges

```yaml
# ✅ GOOD - Specific subnet
egress:
  - to:
    - ipBlock:
        cidr: 10.1.2.0/24  # Only 256 IPs
```

### Namespace Selector Guidelines

#### DON'T: Allow All Namespaces Without Pod Selector

```yaml
# ❌ BAD - All pods in all namespaces
ingress:
  - from:
    - namespaceSelector: {}
  # Missing podSelector = all pods everywhere
```

#### DO: Combine Namespace and Pod Selectors

```yaml
# ✅ GOOD - Specific pods in specific namespaces
ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: production
      podSelector:
        matchLabels:
          app: frontend
```

### Exception Handling

#### DO: Use `except` in ipBlock

```yaml
# ✅ GOOD - Allow range but exclude specific IPs
egress:
  - to:
    - ipBlock:
        cidr: 142.34.0.0/16
        except:
          - 142.34.1.0/24    # Exclude management subnet
          - 142.34.255.0/24  # Exclude infrastructure
```

### Common Mistakes Summary

| Mistake | Risk | Fix |
|---------|------|-----|
| Empty podSelector with allow rules | Allows all pods | Use specific labels |
| Empty ingress/egress rules | Allows all traffic | Define specific sources/destinations |
| No port restrictions | Exposes all ports | Always specify ports |
| Using 0.0.0.0/0 | Internet-wide access | Use specific CIDR blocks |
| No data classification | Default deny blocks pod | Set DataClass label |
| Overlapping policies | Confusing cumulative effect | Use single comprehensive policy |
| Not testing policies | Production outages | Test in dev first |

### Policy Review Checklist

Before deploying a network policy:

- [ ] Specific podSelector (no empty `{}` unless intentional default deny)
- [ ] Both policyTypes specified (Ingress and Egress)
- [ ] Ingress sources explicitly defined (no empty rules)
- [ ] Egress destinations explicitly defined
- [ ] All ports explicitly specified
- [ ] No 0.0.0.0/0 without justification
- [ ] CIDR blocks as narrow as possible
- [ ] Namespace + pod selectors combined
- [ ] Data classification labels set
- [ ] Business justification documented
- [ ] Tested in dev environment
- [ ] Security team review completed

## Environment-Specific Configuration

### Development

```yaml
# dev_values.yaml - More permissive for testing
frontend:
  dataClass: "low"      # Allow broader access for testing
  networkPolicy:
    enabled: true       # Still enforce policies

backend:
  dataClass: "medium"
```

### Production

```yaml
# prod_values.yaml - Strict classification
frontend:
  dataClass: "medium"   # User data handling
  networkPolicy:
    enabled: true

backend:
  dataClass: "high"     # Sensitive operations
  networkPolicy:
    enabled: true

database:
  dataClass: "high"     # All data is sensitive
```

## Security Considerations

### Default Deny

The template enforces **default deny** behavior:
- All traffic is blocked unless explicitly allowed
- Pods without classification are isolated
- Only specified ports are allowed

### Principle of Least Privilege

Apply the lowest classification that allows functionality:

```yaml
# If service only reads public data - use Low
public-api:
  dataClass: "low"

# If service processes user data - use Medium
user-service:
  dataClass: "medium"

# If service handles sensitive data - use High
payment-service:
  dataClass: "high"
```

### Defense in Depth

Network policies are one layer:
- Also use service authentication (mTLS)
- Implement application-level authorization
- Use Kubernetes RBAC
- Enable audit logging

## Policy Scanning and Validation

### Overview

Network policies should be validated, scanned, and audited regularly to ensure they meet security requirements and don't introduce vulnerabilities.

### Pre-Deployment Validation

#### 1. Helm Template Validation

Validate network policies before deployment:

```bash
# Render templates to YAML
helm template myapp ./charts/myapp-charts/gitops \
  --values ./deploy/dev_values.yaml \
  > rendered-manifests.yaml

# Extract network policies
grep -A 100 "kind: NetworkPolicy" rendered-manifests.yaml > network-policies.yaml

# Review policies
cat network-policies.yaml
```

#### 2. Kubernetes Dry-Run

Test policies without applying:

```bash
# Dry-run deployment
helm install myapp ./charts/myapp-charts/gitops \
  --values ./deploy/dev_values.yaml \
  --namespace abc123-dev \
  --dry-run

# Validate against cluster
kubectl apply --dry-run=server -f network-policies.yaml
```

#### 3. Policy Syntax Validation

```bash
# Validate YAML syntax
yamllint network-policies.yaml

# Validate Kubernetes schema
kubectl apply --dry-run=client -f network-policies.yaml
```

### Policy Scanning Tools

#### Kubesec - Security Risk Analysis

Scan network policies for security issues:

```bash
# Install kubesec
curl -sSL https://github.com/controlplaneio/kubesec/releases/download/v2.13.0/kubesec_linux_amd64.tar.gz | tar xz

# Scan network policies
./kubesec scan network-policies.yaml

# Example output:
# [
#   {
#     "object": "NetworkPolicy/myapp-frontend",
#     "valid": true,
#     "message": "Passed with a score of 7 points",
#     "score": 7,
#     "scoring": {
#       "passed": [
#         {
#           "selector": ".spec.policyTypes | index(\"Ingress\")",
#           "reason": "Ingress network policy defined"
#         }
#       ]
#     }
#   }
# ]
```

#### Polaris - Best Practices

Audit policies against best practices:

```bash
# Install Polaris CLI
brew install FairwindsOps/tap/polaris

# Or download binary
curl -L https://github.com/FairwindsOps/polaris/releases/download/10.1.4/polaris_linux_amd64.tar.gz | tar xz

# Scan manifests
polaris audit --audit-path ./rendered-manifests.yaml

# Generate HTML report
polaris audit --audit-path ./rendered-manifests.yaml --format html > polaris-report.html
```

**Polaris checks:**
- Network policies are defined
- Default deny policies exist
- Ingress and egress rules are restrictive

#### Datree - Policy as Code

Validate against custom policies:

```bash
# Install datree
curl https://get.datree.io | /bin/bash

# Scan manifests
datree test ./rendered-manifests.yaml

# Example checks:
# ✅ Ensure NetworkPolicy is defined for each workload
# ✅ Ensure default deny policies exist
# ❌ Missing egress rule for DNS
```

**Custom policy example** (`.datree/policy.yaml`):

```yaml
apiVersion: v1
policies:
  - name: NetworkPolicy
    rules:
      - identifier: NETWORK_POLICY_REQUIRED
        messageOnFailure: Every deployment must have a network policy

      - identifier: DATA_CLASS_LABEL_REQUIRED
        messageOnFailure: Pods must have DataClass label set
```

#### OPA (Open Policy Agent) - Advanced Policy Enforcement

Define custom policies with Rego:

```bash
# Install OPA
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa

# Create policy file
cat > network-policy-rules.rego <<'EOF'
package kubernetes.admission

deny[msg] {
    input.request.kind.kind == "Deployment"
    not has_network_policy
    msg := sprintf("Deployment %v must have a corresponding NetworkPolicy", [input.request.object.metadata.name])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    not input.request.object.metadata.labels.DataClass
    msg := "All pods must have a DataClass label"
}

deny[msg] {
    input.request.kind.kind == "Pod"
    dataClass := input.request.object.metadata.labels.DataClass
    not dataClass in ["Low", "Medium", "High"]
    msg := sprintf("Invalid DataClass: %v. Must be Low, Medium, or High", [dataClass])
}
EOF

# Test policy
opa eval --data network-policy-rules.rego --input deployment.json "data.kubernetes.admission.deny"
```

### Compliance Scanning

#### CIS Kubernetes Benchmark

Check compliance with CIS benchmarks:

```bash
# Install kube-bench
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# Check results
kubectl logs -f job/kube-bench

# Relevant checks:
# 5.3.1 Ensure that the CNI in use supports Network Policies
# 5.3.2 Ensure that all Namespaces have Network Policies defined
```

#### Network Policy Coverage Check

Verify all workloads have network policies:

```bash
# Check deployments without network policies
kubectl get deployments -n abc123-dev -o json | \
  jq -r '.items[] | select(.metadata.labels."app.kubernetes.io/name") | .metadata.name' | \
  while read deploy; do
    if ! kubectl get networkpolicy -n abc123-dev | grep -q $deploy; then
      echo "WARNING: $deploy has no network policy"
    fi
  done
```

#### Data Classification Audit

Verify all pods have proper data classification:

```bash
# Check pods without DataClass label
kubectl get pods -n abc123-dev -o json | \
  jq -r '.items[] | select(.metadata.labels.DataClass == null) | .metadata.name'

# Expected output: (empty - all pods should have classification)

# Check invalid data classifications
kubectl get pods -n abc123-dev -o json | \
  jq -r '.items[] | select(.metadata.labels.DataClass) |
         select(.metadata.labels.DataClass != "Low" and
                .metadata.labels.DataClass != "Medium" and
                .metadata.labels.DataClass != "High") |
         .metadata.name + ": " + .metadata.labels.DataClass'
```

### Policy Testing

#### Automated Policy Testing

Create test script (`scripts/test-network-policies.sh`):

```bash
#!/bin/bash
set -e

NAMESPACE="abc123-dev"
echo "Testing network policies in $NAMESPACE"

# Test 1: Verify network policies exist
echo "✓ Test 1: Check network policies exist"
kubectl get networkpolicy -n $NAMESPACE | grep -q "myapp-frontend" || exit 1
kubectl get networkpolicy -n $NAMESPACE | grep -q "myapp-backend" || exit 1

# Test 2: Verify data classification labels
echo "✓ Test 2: Check DataClass labels"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].metadata.labels.DataClass}' | grep -q "Medium" || exit 1

# Test 3: Test allowed communication (Medium -> High)
echo "✓ Test 3: Test frontend -> backend (allowed)"
FRONTEND_POD=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec $FRONTEND_POD -n $NAMESPACE -- curl -s -o /dev/null -w "%{http_code}" http://myapp-backend:8080/health | grep -q "200" || exit 1

# Test 4: Test blocked communication (no DataClass)
echo "✓ Test 4: Test unlabeled pod blocked"
kubectl run test-curl --image=curlimages/curl --rm -i --restart=Never -n $NAMESPACE -- \
  curl -s --max-time 5 http://myapp-backend:8080 || echo "Blocked as expected"

# Test 5: Verify DNS works
echo "✓ Test 5: Check DNS resolution"
kubectl exec $FRONTEND_POD -n $NAMESPACE -- nslookup myapp-backend || exit 1

echo "✅ All network policy tests passed"
```

#### Integration Testing

Test network policies in CI/CD:

```yaml
# .github/workflows/test-network-policies.yaml
name: Test Network Policies

on: [push, pull_request]

jobs:
  test-policies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Render Helm templates
        run: |
          helm template test ./charts/myapp-charts/gitops \
            --values ./deploy/dev_values.yaml \
            > rendered.yaml

      - name: Scan with Kubesec
        run: |
          docker run -v $(pwd):/app kubesec/kubesec:v2 scan /app/rendered.yaml

      - name: Check with Polaris
        run: |
          docker run -v $(pwd):/app quay.io/fairwinds/polaris:10.1.4 \
            polaris audit --audit-path /app/rendered.yaml

      - name: Validate with Datree
        run: |
          curl https://get.datree.io | /bin/bash
          datree test rendered.yaml

      - name: Check network policy coverage
        run: |
          bash scripts/validate-network-policy-coverage.sh
```

### Network Policy Monitoring

#### Runtime Monitoring

Monitor network policy violations in real-time:

```bash
# View denied connections (if using Cilium)
kubectl logs -n kube-system -l k8s-app=cilium --tail=100 | grep "Policy denied"

# View network policy events
kubectl get events -n abc123-dev --field-selector reason=NetworkPolicyViolation

# Monitor with kubectl watch
kubectl get networkpolicies -n abc123-dev --watch
```

#### Policy Metrics

Collect metrics on network policy effectiveness:

```bash
# Count network policies
kubectl get networkpolicies -n abc123-dev --no-headers | wc -l

# Count pods with network policies
kubectl get pods -n abc123-dev -o json | \
  jq '[.items[] | select(.metadata.labels."app.kubernetes.io/name")] | length'

# Check policy coverage percentage
TOTAL_PODS=$(kubectl get pods -n abc123-dev --no-headers | wc -l)
PROTECTED_PODS=$(kubectl get pods -n abc123-dev -o json | \
  jq '[.items[] | select(.metadata.labels."data-class")] | length')
echo "Coverage: $((PROTECTED_PODS * 100 / TOTAL_PODS))%"
```

### Audit Logging

#### Enable Network Policy Audit Logs

Configure audit logging for network policy changes:

```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log network policy changes
  - level: RequestResponse
    resources:
      - group: "networking.k8s.io"
        resources: ["networkpolicies"]
    verbs: ["create", "update", "patch", "delete"]

  # Log pod creation with data classification
  - level: Metadata
    resources:
      - group: ""
        resources: ["pods"]
    verbs: ["create"]
```

#### Query Audit Logs

```bash
# Find network policy changes
kubectl logs -n kube-system kube-apiserver-xxx | \
  grep "networkpolicies" | \
  jq 'select(.objectRef.resource=="networkpolicies")'

# Check who modified policies
kubectl logs -n kube-system kube-apiserver-xxx | \
  jq 'select(.objectRef.resource=="networkpolicies") |
      {time: .requestReceivedTimestamp, user: .user.username, action: .verb, policy: .objectRef.name}'
```

### Policy Governance

#### Policy Review Checklist

Before deploying network policies:

- [ ] All pods have DataClass label (Low/Medium/High)
- [ ] No pods deployed without data classification
- [ ] Network policies exist for all deployments
- [ ] Ingress rules only allow necessary traffic
- [ ] Egress rules include DNS (port 53)
- [ ] External API egress is documented and justified
- [ ] Default deny policies are in place
- [ ] Policies follow least privilege principle
- [ ] Policies tested in dev environment
- [ ] Security team has reviewed policies
- [ ] Documentation updated

#### Regular Audit Schedule

**Weekly:**
- Review new deployments for network policy coverage
- Check for pods without DataClass labels
- Verify no unauthorized policy changes

**Monthly:**
- Full network policy audit
- Review data classification assignments
- Update policies for new services
- Run compliance scans (Polaris, Datree)

**Quarterly:**
- Security review of all network policies
- Update documentation
- Review and update custom OPA policies
- Penetration testing of network segmentation

### Policy Documentation Requirements

Every network policy should be documented with:

```yaml
# Example: frontend-networkpolicy.yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: myapp-frontend
  annotations:
    # Document purpose
    description: "Network policy for frontend application"

    # Document data classification
    dataClassification: "Medium"

    # Document allowed communications
    allowedIngress: "Ingress controller, load balancer"
    allowedEgress: "Backend API (Medium/High), DNS, External APIs"

    # Document business justification
    businessJustification: "Frontend needs to communicate with backend API and external OAuth provider"

    # Document owner
    owner: "platform-team@justice.gov.bc.ca"

    # Document review date
    lastReviewed: "2026-02-10"
    nextReview: "2026-05-10"
```

### Tools Summary

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **Helm dry-run** | Validate before deploy | Every deployment |
| **Kubesec** | Security risk analysis | CI/CD pipeline |
| **Polaris** | Best practices audit | Weekly/monthly |
| **Datree** | Policy as code enforcement | CI/CD pipeline |
| **OPA** | Custom policy enforcement | Advanced governance |
| **kube-bench** | CIS compliance | Quarterly |
| **kubectl audit** | Track policy changes | Continuous monitoring |

### CI/CD Integration Example

Complete pipeline for network policy validation:

```yaml
# .github/workflows/network-policy-validation.yaml
name: Network Policy Validation

on:
  pull_request:
    paths:
      - 'charts/**/templates/*networkpolicy*.yaml'
      - 'deploy/**_values.yaml'

jobs:
  validate-policies:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Setup Helm
        uses: azure/setup-helm@v3

      - name: Render Templates
        run: |
          helm template test ./charts/myapp-charts/gitops \
            --values ./deploy/dev_values.yaml > rendered.yaml

      - name: Extract Network Policies
        run: |
          grep -A 100 "kind: NetworkPolicy" rendered.yaml > network-policies.yaml || true

      - name: Validate Syntax
        run: |
          kubectl apply --dry-run=client -f network-policies.yaml

      - name: Scan with Kubesec
        run: |
          docker run kubesec/kubesec:v2 scan /dev/stdin < network-policies.yaml

      - name: Audit with Polaris
        run: |
          docker run quay.io/fairwinds/polaris:8.0 \
            polaris audit --audit-path rendered.yaml --format=pretty

      - name: Check Coverage (after deployment)
        run: |
          # Run after deploying to test environment
          bash scripts/validate-network-policy-coverage.sh abc123-dev

      - name: Validate Data Classification (after deployment)
        run: |
          # Run after deploying to test environment
          bash scripts/validate-data-classification.sh abc123-dev

      - name: Comment PR
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '⚠️ Network policy validation failed. Please review the checks above.'
            })
```

## Next Steps

- Read [Configuration Guide](configuration-guide.md) for all network policy options
- See [Deployment Guide](deployment-guide.md) for environment-specific policies
- Review [Troubleshooting](troubleshooting.md) for network connectivity issues
- Check [Architecture](architecture.md) for how policies are generated
