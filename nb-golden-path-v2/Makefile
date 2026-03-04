# ──────────────────────────────────────────────
# NB Golden Path — GitOps Renderer
# ──────────────────────────────────────────────
# Usage:
#   1. Edit config/cluster-config.env
#   2. make render
#   3. git add . && git commit && git push
# ──────────────────────────────────────────────

CONFIG := config/cluster-config.env

# Resolve variable references in config
include $(CONFIG)
export

# Files that contain __PLACEHOLDER__ tokens
TEMPLATE_FILES := template.yaml \
                  skeleton/catalog-info.yaml \
                  skeleton/README.md \
                  skeleton/.coder/main.tf \
                  skeleton/chart/values.yaml \
                  skeleton/argocd-app.yaml \
                  skeleton/.github/workflows/ci.yaml

.PHONY: render validate clean

render: validate
	@echo "Rendering templates with cluster config..."
	@for f in $(TEMPLATE_FILES); do \
		if [ -f "$$f" ]; then \
			sed -i.bak \
				-e 's|__CLUSTER_DOMAIN__|$(CLUSTER_DOMAIN)|g' \
				-e 's|__CODER_HOST__|$(CODER_HOST)|g' \
				-e 's|__ARGOCD_HOST__|$(ARGOCD_HOST)|g' \
				-e 's|__ACS_HOST__|$(ACS_HOST)|g' \
				-e 's|__RHDH_HOST__|$(RHDH_HOST)|g' \
				-e 's|__GRAFANA_HOST__|$(GRAFANA_HOST)|g' \
				-e 's|__IMAGE_REGISTRY__|$(IMAGE_REGISTRY)|g' \
				-e 's|__GITHUB_ORG__|$(GITHUB_ORG)|g' \
				-e 's|__STORAGE_CLASS__|$(STORAGE_CLASS)|g' \
				-e 's|__CODER_NAMESPACE__|$(CODER_NAMESPACE)|g' \
				"$$f"; \
			rm -f "$$f.bak"; \
			echo "  Rendered $$f"; \
		fi; \
	done
	@echo "Done. Review changes, then: git add . && git commit && git push"

validate:
	@if [ ! -f $(CONFIG) ]; then \
		echo "ERROR: $(CONFIG) not found. Copy from config/cluster-config.example.env"; \
		exit 1; \
	fi
	@echo "Config validated: $(CONFIG)"

# Reset to placeholders (for sharing/forking)
clean:
	@echo "Resetting to placeholders..."
	@git checkout -- $(TEMPLATE_FILES) 2>/dev/null || true
	@echo "Done. Templates reset to __PLACEHOLDER__ tokens."

# Show current config
info:
	@echo "=== Cluster Config ==="
	@echo "CLUSTER_DOMAIN:  $(CLUSTER_DOMAIN)"
	@echo "CODER_HOST:      $(CODER_HOST)"
	@echo "ARGOCD_HOST:     $(ARGOCD_HOST)"
	@echo "ACS_HOST:        $(ACS_HOST)"
	@echo "RHDH_HOST:       $(RHDH_HOST)"
	@echo "GRAFANA_HOST:    $(GRAFANA_HOST)"
	@echo "IMAGE_REGISTRY:  $(IMAGE_REGISTRY)"
	@echo "GITHUB_ORG:      $(GITHUB_ORG)"
	@echo "STORAGE_CLASS:   $(STORAGE_CLASS)"
	@echo "CODER_NAMESPACE: $(CODER_NAMESPACE)"
