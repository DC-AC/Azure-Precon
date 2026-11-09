###############################################################################
# Demo 04 — Certificate Auto-Rotation in Key Vault
#
# Slide: "Demonstration — Certificate Auto-Rotation in Key Vault"
#        (Section 6, Identity & Secrets)
#   - Configure automated certificate rotation to remove manual renewal risk
#
# The point of the demo is the *lifetime_action* block: a certificate that
# renews itself on a schedule, emits an event when it does, and is consumed by
# a managed identity that holds no credential of its own.
#
#   Key Vault ──(RBAC)── you: Key Vault Administrator
#        │
#        ├── certificate  ── lifetime_action { AutoRenew @ 80% }
#        │
#        ├──(RBAC)── user-assigned identity: Certificate User + Secret User
#        │              (this is how an App Service / App Gateway consumes it)
#        │
#        └── Event Grid system topic ──> storage queue
#                 CertificateNewVersionCreated / NearExpiry / Expired
###############################################################################

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  # Resource group names follow rg-<demo>-<core tech>-<region>. Only globally
  # unique names (storage, Key Vault, SQL, function apps) carry the random suffix.
  region_codes = {
    eastus         = "eus"
    eastus2        = "eus2"
    centralus      = "cus"
    northcentralus = "ncus"
    southcentralus = "scus"
    westus         = "wus"
    westus2        = "wus2"
    westus3        = "wus3"
    canadacentral  = "cac"
    northeurope    = "neu"
    westeurope     = "weu"
    uksouth        = "uks"
  }
  region_code = lookup(local.region_codes, var.location, var.location)

  suffix = "${var.prefix}-${random_string.suffix.result}"
}

resource "azurerm_resource_group" "this" {
  name     = "rg-demo04-keyvault-${local.region_code}"
  location = var.location
  tags     = var.tags
}

###############################################################################
# Key Vault
###############################################################################

resource "azurerm_key_vault" "this" {
  name                = "kv-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC, not access policies. Access policies are the legacy model and they
  # do not compose with PIM, Conditional Access or role assignments elsewhere.
  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = var.enable_purge_protection

  # Demo-only. In production put a private endpoint in front of this and set
  # public_network_access_enabled = false — see the Private Link slide.
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = var.tags
}

###############################################################################
# RBAC — the operator (you) and the consumer (an app identity)
###############################################################################

# Terraform needs data-plane rights to create the certificate below.
resource "azurerm_role_assignment" "operator" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Entra role assignments are eventually consistent. Without this the very first
# apply usually fails on the certificate with a 403.
resource "time_sleep" "rbac_propagation" {
  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.operator]
}

# Stand-in for whatever consumes the certificate: App Service, Application
# Gateway, a container. It holds no secret — it holds a role assignment.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-app-${local.suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "app_certificate_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# The private key lives behind the secret plane, so a consumer that needs the
# full PFX needs this too. Narrow scope, one vault, read-only.
resource "azurerm_role_assignment" "app_secret_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

###############################################################################
# The certificate — this is the slide
###############################################################################

resource "azurerm_key_vault_certificate" "app" {
  name         = var.certificate_name
  key_vault_id = azurerm_key_vault.this.id
  tags         = var.tags

  certificate_policy {
    # "Self" = self-signed, issued by Key Vault itself. For a public cert you
    # swap this for an integrated CA (DigiCert / GlobalSign) — see the
    # commented azurerm_key_vault_certificate_issuer block below. Everything
    # else on this resource stays identical, including the rotation policy.
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"

      # false => a brand new key pair on every renewal. Rotating the certificate
      # but reusing the key only rotates half the problem.
      reuse_key = false
    }

    #########################################################################
    # AUTO-ROTATION. The entire demo is these six lines.
    #########################################################################
    lifetime_action {
      # The alternative action type is "EmailContacts" — a polite way of saying
      # "go renew it by hand", i.e. the exact risk this slide exists to remove.
      action {
        action_type = "AutoRenew"
      }

      trigger {
        lifetime_percentage = var.auto_renew_lifetime_percentage
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = var.certificate_subject
      validity_in_months = var.certificate_validity_months
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # serverAuth

      key_usage = [
        "digitalSignature",
        "keyEncipherment",
        "keyAgreement",
        "dataEncipherment",
        "keyCertSign",
      ]

      subject_alternative_names {
        dns_names = var.certificate_dns_names
      }
    }
  }

  depends_on = [time_sleep.rbac_propagation]
}

###############################################################################
# Integrated CA issuer — reference only
#
# Uncomment and supply real credentials to issue publicly trusted certificates
# instead of self-signed ones. The rotation policy above does not change.
#
# resource "azurerm_key_vault_certificate_issuer" "digicert" {
#   name          = "digicert"
#   key_vault_id  = azurerm_key_vault.this.id
#   provider_name = "DigiCert"
#   account_id    = var.ca_account_id
#   password      = var.ca_account_password
# }
###############################################################################

###############################################################################
# Event Grid — prove the rotation actually emits something you can act on
###############################################################################

resource "azurerm_storage_account" "events" {
  count = var.enable_event_grid ? 1 : 0

  name                     = replace("stkv${var.prefix}${random_string.suffix.result}", "-", "")
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_queue" "cert_events" {
  count = var.enable_event_grid ? 1 : 0

  name               = "certificate-events"
  storage_account_id = azurerm_storage_account.events[0].id
}

# So the presenter can peek at the queue with `--auth-mode login`. Owner on the
# subscription is control plane only — reading messages is a data-plane grant.
resource "azurerm_role_assignment" "operator_queue_reader" {
  count = var.enable_event_grid ? 1 : 0

  scope                = azurerm_storage_account.events[0].id
  role_definition_name = "Storage Queue Data Reader"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_eventgrid_system_topic" "kv" {
  count = var.enable_event_grid ? 1 : 0

  name                = "evgt-kv-${local.suffix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  source_resource_id  = azurerm_key_vault.this.id
  topic_type          = "Microsoft.KeyVault.vaults"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_eventgrid_system_topic_event_subscription" "cert_events" {
  count = var.enable_event_grid ? 1 : 0

  name                = "certificate-lifecycle"
  system_topic        = azurerm_eventgrid_system_topic.kv[0].name
  resource_group_name = azurerm_resource_group.this.name

  included_event_types = [
    "Microsoft.KeyVault.CertificateNewVersionCreated",
    "Microsoft.KeyVault.CertificateNearExpiry",
    "Microsoft.KeyVault.CertificateExpired",
  ]

  storage_queue_endpoint {
    storage_account_id = azurerm_storage_account.events[0].id
    queue_name         = azurerm_storage_queue.cert_events[0].name
  }
}
