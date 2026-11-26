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
    key              = "foundation.tfstate"
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

variable "resource_group" {
  description = "Azure resource group created by scripts/bootstrap-azure.sh."
  type        = string
}

data "azurerm_resource_group" "app" {
  name = var.resource_group
}

locals {
  name_suffix = substr(sha256(lower(data.azurerm_resource_group.app.id)), 0, 12)
  tags        = { project = "research-brief-agents", managed-by = "terraform" }
}

resource "azurerm_container_registry" "app" {
  name                = "acrbrief${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_resource_group.app.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "pull" {
  name                = "research-brief-image-pull"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_resource_group.app.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "pull" {
  scope                            = azurerm_container_registry.app.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.pull.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_log_analytics_workspace" "app" {
  name                = "logs-brief-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_resource_group.app.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  tags                = local.tags
}

resource "azurerm_container_app_environment" "app" {
  name                       = "research-brief"
  resource_group_name        = data.azurerm_resource_group.app.name
  location                   = data.azurerm_resource_group.app.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.app.id
  logs_destination           = "log-analytics"
  tags                       = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

output "registry_name" {
  value = azurerm_container_registry.app.name
}

output "registry_server" {
  value = azurerm_container_registry.app.login_server
}

output "environment_id" {
  value = azurerm_container_app_environment.app.id
}

output "pull_identity_id" {
  value = azurerm_user_assigned_identity.pull.id
}
