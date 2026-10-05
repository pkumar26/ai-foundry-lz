# Frontend + backend Container Apps on the environment created by the pattern
# module. The module only provisions the Container Apps *environment*, so the two
# apps are defined here directly. Both use a system-assigned identity for
# passwordless access to downstream services (SQL, AI Search).
#
# Connectivity (all private, same BYO VNet as the environment subnet):
#   - backend -> SQL        : via the SQL private endpoint + privatelink.database.windows.net (sql.tf)
#   - backend -> AI Search  : via the Search private endpoint + privatelink.search.windows.net (module)
#   - frontend -> backend   : app-to-app over the environment's internal ingress
#   - Front Door -> frontend: managed Private Link to the ACA environment (frontdoor.tf)
#
# Toggle with deploy_container_app_environment. The backend's SQL/Search env vars
# and the Search role assignments only populate when those services are deployed.

locals {
  # Mirrors the module's naming: the environment name defaults to
  # "<name_prefix>-container-app-env" when aca_name is null.
  aca_env_name = coalesce(var.aca_name, "${var.name_prefix}-container-app-env")

  # Mirrors the search name expression used in main.tf's ks_ai_search_definition.
  aca_search_service_name = coalesce(var.search_service_name, "${var.name_prefix}-search-${random_string.search_suffix.result}")
  aca_search_endpoint     = var.deploy_ai_search ? "https://${local.aca_search_service_name}.search.windows.net" : ""

  aca_sql_server_fqdn = var.deploy_sql_database ? try(module.sql_server[0].resource.fully_qualified_domain_name, "") : ""
}

# The pattern module doesn't output the environment id, so look it up by name.
data "azurerm_container_app_environment" "aca" {
  count               = var.deploy_container_app_environment ? 1 : 0
  name                = local.aca_env_name
  resource_group_name = var.resource_group_name

  depends_on = [module.ai_lz]
}

# Search service id (RBAC scope for the backend identity).
data "azurerm_search_service" "search" {
  count               = var.deploy_container_app_environment && var.deploy_ai_search ? 1 : 0
  name                = local.aca_search_service_name
  resource_group_name = var.resource_group_name

  depends_on = [module.ai_lz]
}

# --- Backend: internal ingress only, reachable from the frontend app. ---
resource "azurerm_container_app" "backend" {
  count                        = var.deploy_container_app_environment ? 1 : 0
  name                         = var.aca_backend_app_name
  container_app_environment_id = data.azurerm_container_app_environment.aca[0].id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type = "SystemAssigned"
  }

  ingress {
    external_enabled = false
    target_port      = var.aca_backend_target_port
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = var.aca_backend_app_name
      image  = var.aca_placeholder_image
      cpu    = var.aca_cpu
      memory = var.aca_memory

      # Passwordless: the app authenticates to SQL and Search with its managed
      # identity. Only endpoints are passed; no secrets/connection strings.
      env {
        name  = "SQL_SERVER_FQDN"
        value = local.aca_sql_server_fqdn
      }
      env {
        name  = "SQL_DATABASE"
        value = var.sql_database_name
      }
      env {
        name  = "SEARCH_ENDPOINT"
        value = local.aca_search_endpoint
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = "system-assigned"
      }
    }
  }
}

# --- Frontend: external ingress (exposed through the environment's internal LB,
# then published to the internet by Front Door via Private Link). ---
resource "azurerm_container_app" "frontend" {
  count                        = var.deploy_container_app_environment ? 1 : 0
  name                         = var.aca_frontend_app_name
  container_app_environment_id = data.azurerm_container_app_environment.aca[0].id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type = "SystemAssigned"
  }

  ingress {
    external_enabled = true
    target_port      = var.aca_frontend_target_port
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = var.aca_frontend_app_name
      image  = var.aca_placeholder_image
      cpu    = var.aca_cpu
      memory = var.aca_memory

      env {
        name  = "BACKEND_URL"
        value = "https://${azurerm_container_app.backend[0].ingress[0].fqdn}"
      }
    }
  }
}

# --- Backend identity -> AI Search (data-plane, passwordless). ---
# Read/write documents and manage indexes. Requires local_authentication to be
# disabled / RBAC enabled on the Search service to take effect.
resource "azurerm_role_assignment" "backend_search_index_data" {
  count                = var.deploy_container_app_environment && var.deploy_ai_search ? 1 : 0
  scope                = data.azurerm_search_service.search[0].id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_container_app.backend[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "backend_search_service_contributor" {
  count                = var.deploy_container_app_environment && var.deploy_ai_search ? 1 : 0
  scope                = data.azurerm_search_service.search[0].id
  role_definition_name = "Search Service Contributor"
  principal_id         = azurerm_container_app.backend[0].identity[0].principal_id
}

# NOTE: SQL access for the backend's managed identity is NOT a control-plane RBAC
# grant. After deploy, connect to the database and create a contained user, e.g.:
#   CREATE USER [<backend-app-name>] FROM EXTERNAL PROVIDER;
#   ALTER ROLE db_datareader ADD MEMBER [<backend-app-name>];
#   ALTER ROLE db_datawriter ADD MEMBER [<backend-app-name>];
# Run it as the SQL AAD admin against the private endpoint (e.g. from the jumpbox).
