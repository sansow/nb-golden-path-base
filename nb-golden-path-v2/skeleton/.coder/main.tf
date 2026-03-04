terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# ──────────────────────────────────────────────
# VARIABLES — Populated by RHDH template wizard
# ──────────────────────────────────────────────
variable "namespace" {
  type        = string
  description = "OpenShift namespace for the workspace pod"
  default     = "${{ values.target_namespace }}-dev"
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  type         = "number"
  default      = "${{ values.workspace_cpu }}"
  mutable      = true
  validation {
    min = 2
    max = 8
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  type         = "number"
  default      = "${{ values.workspace_memory }}"
  mutable      = true
  validation {
    min = 4
    max = 16
  }
}

data "coder_parameter" "disk" {
  name         = "disk"
  display_name = "Persistent Storage (GB)"
  type         = "number"
  default      = "${{ values.workspace_disk }}"
  mutable      = true
}

data "coder_parameter" "repo_url" {
  name    = "repo_url"
  display_name = "Git Repository URL"
  type    = "string"
  default = ""
}

data "coder_parameter" "dotfiles_url" {
  name    = "dotfiles_url"
  display_name = "Dotfiles Repository"
  type    = "string"
  default = ""
}

data "coder_parameter" "image" {
  name    = "image"
  display_name = "Workspace Image"
  type    = "string"
  default = "registry.apps.cluster-cnhmj.dynamic.redhatworkshops.io/devtools/java-workspace:21"
  option {
    name  = "Java 21"
    value = "registry.apps.cluster-cnhmj.dynamic.redhatworkshops.io/devtools/java-workspace:21"
  }
  option {
    name  = "Python 3.12"
    value = "registry.apps.cluster-cnhmj.dynamic.redhatworkshops.io/devtools/python-workspace:3.12"
  }
  option {
    name  = ".NET 8.0"
    value = "registry.apps.cluster-cnhmj.dynamic.redhatworkshops.io/devtools/dotnet-workspace:8.0"
  }
  option {
    name  = "Node.js 20"
    value = "registry.apps.cluster-cnhmj.dynamic.redhatworkshops.io/devtools/node-workspace:20"
  }
}

# ──────────────────────────────────────────────
# CODER AGENT — IDE, terminal, apps
# ──────────────────────────────────────────────
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/coder/project"

  display_apps {
    vscode          = true
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = true
  }

  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Clone repo if provided
    if [ -n "${data.coder_parameter.repo_url.value}" ]; then
      if [ ! -d /home/coder/project/.git ]; then
        git clone "${data.coder_parameter.repo_url.value}" /home/coder/project
      else
        cd /home/coder/project && git pull --ff-only || true
      fi
    fi

    # Apply dotfiles
    if [ -n "${data.coder_parameter.dotfiles_url.value}" ]; then
      coder dotfiles -y "${data.coder_parameter.dotfiles_url.value}" || true
    fi

    # Install VS Code extensions
    if command -v code-server &> /dev/null; then
      code-server --install-extension redhat.vscode-yaml
      code-server --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
      code-server --install-extension Continue.continue
    fi

    echo "Workspace ready — ${{ values.component_id }}"
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "Memory Usage"
    key          = "mem"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "Disk Usage"
    key          = "disk"
    script       = "coder stat disk --path /home/coder"
    interval     = 600
    timeout      = 1
  }
}

# ──────────────────────────────────────────────
# KUBERNETES POD — Runs on OpenShift
# ──────────────────────────────────────────────
resource "kubernetes_pod" "workspace" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "coder-workspace"
      "app.kubernetes.io/instance"   = data.coder_workspace.me.name
      "app.kubernetes.io/managed-by" = "coder"
      "app.kubernetes.io/part-of"    = "${{ values.system }}"
      "backstage.io/component"       = "${{ values.component_id }}"
    }
  }

  spec {
    security_context {
      run_as_non_root = true
      run_as_user     = 1000
      fs_group        = 1000
    }

    container {
      name              = "dev"
      image             = data.coder_parameter.image.value
      image_pull_policy = "IfNotPresent"
      command           = ["sh", "-c", coder_agent.main.init_script]

      security_context {
        allow_privilege_escalation = false
        capabilities {
          drop = ["ALL"]
        }
        seccomp_profile {
          type = "RuntimeDefault"
        }
      }

      resources {
        requests = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
        limits = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
      }

      volume_mount {
        name       = "home"
        mount_path = "/home/coder"
      }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      env {
        name  = "NB_SYSTEM"
        value = "${{ values.system }}"
      }
      env {
        name  = "NB_COMPONENT"
        value = "${{ values.component_id }}"
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-home"
      }
    }

    image_pull_secrets {
      name = "nb-registry-pull-secret"
    }
  }
}

# ──────────────────────────────────────────────
# PVC — Persistent home directory
# ──────────────────────────────────────────────
resource "kubernetes_persistent_volume_claim" "home" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "coder"
    }
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp3-csi"
    resources {
      requests = {
        storage = "${data.coder_parameter.disk.value}Gi"
      }
    }
  }
  wait_until_bound = false
}
