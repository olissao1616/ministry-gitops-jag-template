# Using ag-helm from GitHub Container Registry

## ✅ Setup Complete!

The `ag-helm-templates` Helm library chart is now published to GitHub Container Registry (GHCR). This eliminates the need to copy `shared-lib` folders around.

## 📦 Published Package Location

```
oci://ghcr.io/olissao1616/helm/ag-helm-templates:1.0.3
```

## 🚀 Quick Start for Users

### 1. Update Your Chart.yaml

Instead of using file references, use the OCI registry:

```yaml
# charts/myapp-charts/gitops/Chart.yaml
apiVersion: v2
name: myapp-gitops
description: GitOps deployment chart for myapp
type: application
version: 0.1.0

dependencies:
  - name: ag-helm-templates
    version: "1.0.3"
    repository: "oci://ghcr.io/olissao1616/helm"
  
  - name: postgresql
    version: "14.1.1"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

### 2. Update Dependencies

```bash
cd charts/myapp-charts/gitops
helm dependency update
```

This will download `ag-helm-templates-1.0.3.tgz` to the `charts/` directory.

### 3. Deploy

```bash
helm install myapp . \
  --values ../../deploy/dev_values.yaml \
  --namespace abc123-dev \
  --create-namespace
```

## 🔄 How It Works

### Automatic Publishing

**On every push to `main`:**
- GitHub Actions builds and publishes a dev version
- Format: `1.0.3-dev.abc1234` (includes short commit SHA)
- Available at: `oci://ghcr.io/olissao1616/helm/ag-helm-templates:1.0.3-dev.abc1234`

**On version tags (e.g., `v1.0.4`):**
- GitHub Actions builds and publishes a stable release
- Format: `1.0.4`
- Available at: `oci://ghcr.io/olissao1616/helm/ag-helm-templates:1.0.4`

### Workflow Files

- [.github/workflows/ci.yml](.github/workflows/ci.yml) - Builds and publishes dev versions
- [.github/workflows/release.yml](.github/workflows/release.yml) - Builds and publishes stable releases
- [.github/workflows/publish-on-tag.yml](.github/workflows/publish-on-tag.yml) - Creates GitHub releases

## 📋 Benefits

✅ **No more copying `shared-lib`** - Download from registry automatically  
✅ **Version control** - Lock to specific versions in Chart.yaml  
✅ **Automatic updates** - Easy to upgrade by changing version number  
✅ **CI/CD friendly** - Works seamlessly in pipelines  
✅ **Caching** - Helm caches downloaded packages

## 🔍 Verify Published Package

Check the package exists:

```bash
helm show chart oci://ghcr.io/olissao1616/helm/ag-helm-templates --version 1.0.3
```

Pull the package manually:

```bash
helm pull oci://ghcr.io/olissao1616/helm/ag-helm-templates --version 1.0.3
```

## 🔐 Authentication (if needed)

For public packages (recommended), no authentication is required.

For private packages:

```bash
export GITHUB_TOKEN=your_personal_access_token
echo $GITHUB_TOKEN | helm registry login ghcr.io -u your-github-username --password-stdin
```

## 📚 Next Steps

1. ✅ Repository pushed to GitHub
2. ✅ Tag v1.0.3 created and pushed
3. ⏳ Wait for GitHub Actions to complete (check: https://github.com/olissao1616/ministry-gitops-jag-template/actions)
4. ✅ Package will be available at: https://github.com/olissao1616?tab=packages
5. 🎯 Update cookiecutter templates to use OCI registry (already done!)

## 🛠️ Making a New Release

To publish a new version:

```bash
# 1. Update version in shared-lib/ag-helm/Chart.yaml
# version: 1.0.4

# 2. Commit and push
git add shared-lib/ag-helm/Chart.yaml
git commit -m "chore: bump ag-helm to 1.0.4"
git push origin main

# 3. Create and push tag
git tag v1.0.4 -m "Release v1.0.4"
git push origin v1.0.4

# 4. GitHub Actions will automatically publish to GHCR
```

## 🎉 Success!

Your Helm chart is now published and ready to use! Users can reference it via OCI without needing local copies of `shared-lib`.
