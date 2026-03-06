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

variable "namespace" {
  type        = string
  description = "OpenShift namespace for the workspace pod"
  default     = "coder"
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  type         = "number"
  default      = "4"
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
  default      = "8"
  mutable      = true
  validation {
    min = 4
    max = 16
  }
}

data "coder_parameter" "image" {
  name         = "image"
  display_name = "Workspace Image"
  type         = "string"
  default      = "registry.access.redhat.com/ubi9/ubi:latest"
  option {
    name  = "Red Hat UBI(Default)"
    value = "registry.access.redhat.com/ubi9/ubi:latest"
  }
  option {
    name  = "Java 21"
    value = "registry.access.redhat.com/ubi9/openjdk-21:latest"
  }
  option {
    name  = "Node.js"
    value = "registry.access.redhat.com/ubi9/nodejs-20:latest"
  }
  option {
    name  = "Python 3.12"
    value = "registry.access.redhat.com/ubi9/python-312:latest"
  }
}

data "coder_parameter" "repo_url" {
  name         = "repo_url"
  display_name = "Git Repository URL"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/coder"

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
    REPO_URL="${data.coder_parameter.repo_url.value}"
    if [ -n "$REPO_URL" ]; then
      if [ ! -d /home/coder/project/.git ]; then
        git clone "$REPO_URL" /home/coder/project
      fi
    fi

    echo "Workspace ready"
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
}

resource "kubernetes_pod_v1" "workspace" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "coder-workspace"
      "app.kubernetes.io/instance"   = data.coder_workspace.me.name
      "app.kubernetes.io/managed-by" = "coder"
    }
  }

  spec {
    container {
      name              = "dev"
      image             = data.coder_parameter.image.value
      image_pull_policy = "IfNotPresent"
      command           = ["sh", "-c", coder_agent.main.init_script]

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
	
  	name  = "CODER_AGENT_URL"
  	value = "https://coder-coder.apps.cluster-cnhmj.dynamic.redhatworkshops.io"
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-home"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
  wait_until_bound = false
}
