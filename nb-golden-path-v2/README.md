# NB Golden Path Template — RHDH + Coder

Production-ready RHDH (Backstage) template that scaffolds applications with Coder workspaces, ArgoCD GitOps, ACS security scanning, and full observability on OpenShift.

## Quick Start (GitOps Setup)

```bash
# 1. Fork or clone this repo
git clone git@github.com:__GITHUB_ORG__/nb-golden-path-base.git
cd nb-golden-path-base

# 2. Edit cluster config for your environment
cp config/cluster-config.example.env config/cluster-config.env
vi config/cluster-config.env

# 3. Render templates with your cluster values
make render

# 4. Review, commit, push
make info          # verify config
git add .
git commit -m "configure for our cluster"
git push

# 5. Register in RHDH — add to your app-config:
#    catalog:
#      locations:
#        - type: url
#          target: https://github.com/<org>/nb-golden-path-base/blob/main/template.yaml
```

## What Developers Get

When a developer clicks "Create" in RHDH, they get:

| Component | What It Does |
|-----------|-------------|
| **Coder Workspace** | Remote IDE on OpenShift, local VS Code via SSH |
| **Helm Chart** | Production deployment with Route, NetworkPolicy, ServiceMonitor |
| **ArgoCD App** | GitOps auto-sync from main branch |
| **ACS Scanning** | roxctl image check + scan in CI |
| **SBOM** | Software bill of materials on every build |
| **CI Pipeline** | Build, Scan, Push, GitOps tag update |

## Config Reference

All cluster-specific values live in `config/cluster-config.env`:

| Variable | Description | Example |
|----------|-------------|---------|
| `CLUSTER_DOMAIN` | OpenShift apps domain | `apps.ocp.nb.internal` |
| `CODER_HOST` | Coder route hostname | `coder-coder.apps.ocp.nb.internal` |
| `ARGOCD_HOST` | ArgoCD route | `argocd.apps.ocp.nb.internal` |
| `ACS_HOST` | StackRox/ACS route | `acs.apps.ocp.nb.internal` |
| `IMAGE_REGISTRY` | Container image registry | `registry.nb.internal` |
| `GITHUB_ORG` | GitHub org for repos | `neuberger-berman` |
| `STORAGE_CLASS` | PVC storage class | `ocs-storagecluster-ceph-rbd` |
| `CODER_NAMESPACE` | Coder workspace namespace | `coder` |

## Commands

```bash
make render   # Apply cluster config to templates
make clean    # Reset templates to placeholders
make info     # Show current config values
```

## Sharing / Forking

Before sharing, reset to placeholders:

```bash
make clean
git add . && git commit -m "reset to placeholders" && git push
```

The receiving team then edits `config/cluster-config.env` and runs `make render`.
