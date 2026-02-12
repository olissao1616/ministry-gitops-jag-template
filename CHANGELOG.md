# Changelog

All notable changes to this GitOps template will be documented in this file.

## [2026-02-10] - Template Syntax Fixes

### Fixed

#### Cookiecutter Template Syntax Issues

Fixed Jinja2 template syntax errors in three critical files that were causing `jinja2.exceptions.TemplateSyntaxError: unexpected '.'` when generating charts with cookiecutter.

**Files Fixed:**
1. **`frontend-route.yaml`**
   - Fixed: Bare Helm syntax on line 1: `{{- if and .Values.frontend.enabled .Values.frontend.route.enabled }}`
   - Changed to: `{{ "{{" }}- if and .Values.frontend.enabled .Values.frontend.route.enabled {{ "}}" }}`
   - Added missing closing tag: `{{ "{{" }}- end {{ "}}" }}`

2. **`backend-hpa.yaml`**
   - Fixed: Bare Helm syntax on line 1: `{{- if and .Values.backend.enabled .Values.backend.autoscaling.enabled }}`
   - Changed to: `{{ "{{" }}- if and .Values.backend.enabled .Values.backend.autoscaling.enabled {{ "}}" }}`
   - Added missing closing tag: `{{ "{{" }}- end {{ "}}" }}`

3. **`frontend-hpa.yaml`**
   - Fixed: Bare Helm syntax on line 1: `{{- if and .Values.frontend.enabled .Values.frontend.autoscaling.enabled }}`
   - Changed to: `{{ "{{" }}- if and .Values.frontend.enabled .Values.frontend.autoscaling.enabled {{ "}}" }}`
   - Added missing closing tag: `{{ "{{" }}- end {{ "}}" }}`

**Root Cause:** Previous sed command incorrectly removed `{% raw %}` blocks without converting Helm syntax to escaped format, leaving bare `{{- if` statements that cookiecutter tried to interpret as Jinja2.

**Solution:** Use escaped syntax `{{ "{{" }}` and `{{ "}}" }}` throughout to ensure cookiecutter passes Helm syntax through unchanged.

#### Image Path Construction Issues

Fixed image name construction in deployment templates that was causing incorrect Docker image paths.

**Files Fixed:**
- **`frontend-deployment.yaml`**
  - Fixed: Hardcoded `"Name" "frontend"` causing image path: `repository/frontend:tag`
  - Changed to: `"Name" (default "frontend" .Values.frontend.image.name)`
  - Now supports custom image names via `frontend.image.name` value

- **`backend-deployment.yaml`**
  - Fixed: Hardcoded `"Name" "backend"` causing image path: `repository/backend:tag`
  - Changed to: `"Name" (default "backend" .Values.backend.image.name)`
  - Now supports custom image names via `backend.image.name` value

**Impact:** Developers can now specify correct image names in values:
```yaml
frontend:
  image:
    repository: docker.io/myorg
    name: my-frontend-app  # Used in image path
    tag: v1.0.0
# Results in: docker.io/myorg/my-frontend-app:v1.0.0
```

#### Security Context Issues

Fixed default security context that was preventing containers from starting.

**File Fixed:**
- **`shared-lib/ag-helm/templates/_helpers.tpl`**
  - Fixed: `runAsNonRoot: true` causing `CreateContainerConfigError` for standard Docker images
  - Changed to: `runAsNonRoot: false`
  - Changed: `readOnlyRootFilesystem: true` to `readOnlyRootFilesystem: false`

**Impact:** Containers using standard base images (that run as root by default) now start successfully.

#### PostgreSQL Image Issues

Fixed PostgreSQL image reference that was failing to pull.

**File Fixed:**
- **`deploy/{{cookiecutter.deploy_dir}}/dev_values.yaml`**
  - Fixed: `docker.io/bitnami/postgresql:16.2.0-debian-11-r1` (image not found)
  - Changed to: `postgres:16` (official PostgreSQL image)

**Impact:** PostgreSQL deployments now work out of the box.

### Added

#### Comprehensive Documentation

Added complete documentation suite in `docs/` directory:

1. **`getting-started.md`** - Quick start guide for developers
2. **`architecture.md`** - Deep dive into ag-helm shared library and how to add components
3. **`configuration-guide.md`** - Complete reference for all configuration values
4. **`template-structure.md`** - Understanding the template files and cookiecutter/Helm syntax
5. **`repository-structure.md`** - Naming standards and folder structure conventions
6. **`deployment-guide.md`** - Step-by-step deployment instructions
7. **`troubleshooting.md`** - Common issues and solutions

#### Test Script

Added **`scripts/test-complete-deployment.sh`** - End-to-end test that:
- Generates charts with cookiecutter
- Generates deploy configs with cookiecutter
- Deploys with Helm using dev_values.yaml
- Verifies all components are running:
  - Frontend (1/1 ready)
  - Backend (1/1 ready)
  - PostgreSQL (1/1 ready)
  - HPAs deployed
  - Services deployed

**Usage:**
```bash
cd ministry-gitops-jag-template-main
bash scripts/test-complete-deployment.sh
```

### Changed

#### Development Values Configuration

Updated **`deploy/{{cookiecutter.deploy_dir}}/dev_values.yaml`** to include:
- Image configuration (repository, name, tag)
- Container security context settings
- Autoscaling configuration
- All required values for immediate deployment

## Testing

All changes have been validated:

✅ **Cookiecutter Generation**
- Templates generate without Jinja2 syntax errors
- All files properly escaped
- Correct Helm syntax in output

✅ **Helm Deployment**
- Charts deploy successfully with `helm install`
- All resources created (deployments, services, HPAs, routes)
- Pods start and become ready

✅ **End-to-End Test**
- `test-complete-deployment.sh` passes all checks
- Frontend: Running and healthy
- Backend: Running and healthy
- PostgreSQL: Running and healthy
- HPAs: Configured and monitoring
- Services: Exposed correctly

## Migration Guide

If you generated a repository from the old template:

### Fix Template Syntax

Update these three files in your generated repository:

1. **frontend-route.yaml** - Line 1 and add closing tag
2. **backend-hpa.yaml** - Line 1 and add closing tag
3. **frontend-hpa.yaml** - Line 1 and add closing tag

### Fix Image Names

Update your `dev_values.yaml`:

```yaml
frontend:
  image:
    repository: docker.io/myorg
    name: your-actual-frontend-image  # Add this
    tag: latest

backend:
  image:
    repository: docker.io/myorg
    name: your-actual-backend-image   # Add this
    tag: latest
```

### Fix Security Context

If using a custom ag-helm library, update `shared-lib/ag-helm/templates/_helpers.tpl`:

```yaml
{{- define "ag-template.defaultSecurityContext" -}}
runAsNonRoot: false           # Change from true
allowPrivilegeEscalation: false
readOnlyRootFilesystem: false # Change from true
{{- end -}}
```

### Fix PostgreSQL Image

Update your `dev_values.yaml`:

```yaml
postgresql:
  image:
    repository: postgres
    tag: "16"
```

## Contributors

- Template fixes and enhancements
- Comprehensive documentation
- End-to-end testing

## Next Release

Planned improvements:
- Additional example configurations
- CI/CD integration guides
- Monitoring and observability templates
- Production-ready secrets management examples
