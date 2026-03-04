# ${{ values.component_id }}

> ${{ values.description }}

| | |
|---|---|
| **Owner** | ${{ values.owner }} |
| **System** | ${{ values.system }} |
| **Language** | ${{ values.language }} |

## Quick Start

### Open in Coder

Your workspace is pre-configured:
```
https://coder-coder.apps.cluster-cnhmj.dynamic.redhatworkshops.io/@me/${{ values.component_id }}
```

## Whats Included (Golden Path)

- **Coder Workspace** - Remote IDE on OpenShift with persistent storage
- **Helm Chart** - Production deployment via chart/
- **ArgoCD GitOps** - Auto-sync from main branch
- **ACS Security** - Image scanning + deployment checks in CI
- **SBOM Generation** - Software bill of materials on every build
- **Network Policy** - Default deny with explicit ingress/egress rules
- **ServiceMonitor** - Prometheus metrics scraping enabled
- **CI Pipeline** - Build, Scan, Push, GitOps trigger