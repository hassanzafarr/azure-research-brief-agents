terraform {
  required_version = "~> 1.13.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.57.0"
    }
  }

  backend "azurerm" {
    container_name   = "tfstate"
    key              = "app.tfstate"
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

variable "resource_group" {
  description = "Azure resource group containing the app and its environment."
  type        = string
}

variable "environment_id" {
  description = "Container Apps environment resource ID from the foundation stack."
  type        = string
}

variable "pull_identity_id" {
  description = "User-assigned identity with AcrPull on the registry."
  type        = string
}

variable "registry_server" {
  description = "ACR login server from the foundation stack."
  type        = string
}

variable "image" {
  description = "Application image pinned to its published OCI digest."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+/research-brief@sha256:[0-9a-f]{64}$", var.image))
    error_message = "Use the registry/research-brief@sha256:<digest> image reference."
  }
}

resource "azurerm_container_app" "brief" {
  name                         = "research-brief"
  container_app_environment_id = var.environment_id
  resource_group_name          = var.resource_group
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = { project = "research-brief-agents", managed-by = "terraform" }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.pull_identity_id]
  }

  registry {
    server   = var.registry_server
    identity = var.pull_identity_id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 8501
    transport                  = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "streamlit"
      image  = var.image
      cpu    = 0.5
      memory = "1Gi"

      startup_probe {
        transport               = "HTTP"
        port                    = 8501
        path                    = "/_stcore/health"
        interval_seconds        = 2
        failure_count_threshold = 30
      }

      readiness_probe {
        transport               = "HTTP"
        port                    = 8501
        path                    = "/_stcore/health"
        interval_seconds        = 5
        success_count_threshold = 1
      }

      liveness_probe {
        transport = "HTTP"
        port      = 8501
        path      = "/_stcore/health"
      }
    }
  }
}

output "url" {
  value = "https://${azurerm_container_app.brief.ingress[0].fqdn}"
}
