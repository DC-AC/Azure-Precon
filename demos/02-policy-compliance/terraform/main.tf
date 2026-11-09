###############################################################################
# Demo 02 — Policy & Compliance
#
# Slide: "Demonstration — Policy & Compliance" (Section 3, Governance)
#   - Assign a policy / initiative
#   - View non-compliant resources and remediate
#
# ---------------------------------------------------------------------------
# REPORT-ONLY BY DEFAULT
#
# As shipped, this stack cannot block a deployment or change a resource:
#
#   enforce_policies    = false  -> assignment runs in DoNotEnforce mode.
#                                   Compliance is evaluated and reported; Deny
#                                   and Modify effects do not fire.
#   enable_remediation  = false  -> no Modify policy, no managed identity on the
#                                   assignment, no role assignment at all.
#   audit_effect        = Audit  -> the custom policies report, they don't deny.
#
# The assignment scope is this stack's own resource group. Nothing is ever
# assigned to a subscription or a management group.
#
# Set create_policy_assignment = false to go further still: definitions and the
# initiative are created but attached to no scope whatsoever.
# ---------------------------------------------------------------------------
#
# What this stack builds:
#   * A demo resource group.
#   * Two custom AUDIT policies (custom JSON, parameterised effect).
#   * One BUILT-IN policy whose effect is Deny — included on purpose, because
#     watching a Deny policy report what it *would* have blocked is the whole
#     argument for report-only mode.
#   * An initiative (policy set) grouping them.
#   * The initiative assigned at resource group scope, DoNotEnforce.
#   * Two storage accounts: one compliant, one deliberately non-compliant.
#   * Optionally (enable_remediation) a Modify policy plus the identity and role
#     assignment it needs.
###############################################################################

data "azurerm_subscription" "current" {}

data "azurerm_role_definition" "tag_contributor" {
  name  = "Tag Contributor"
  scope = data.azurerm_subscription.current.id
}

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

  rg_tags = merge(var.tags, { (var.required_tag_name) = var.required_tag_value })

  # The identity and role assignment only exist when remediation is opted into
  # AND there is an assignment to attach them to.
  remediation_active = var.create_policy_assignment && var.enable_remediation
}

resource "azurerm_resource_group" "this" {
  name     = "rg-demo02-policy-${local.region_code}"
  location = var.location
  tags     = local.rg_tags
}

###############################################################################
# Sample resources — one compliant, one not
###############################################################################

resource "azurerm_storage_account" "compliant" {
  name                     = replace("stgood${var.prefix}${random_string.suffix.result}", "-", "")
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  # Compliant: public blob access off, required tag present.
  allow_nested_items_to_be_public = false

  tags = local.rg_tags
}

resource "azurerm_storage_account" "noncompliant" {
  name                     = replace("stbad${var.prefix}${random_string.suffix.result}", "-", "")
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  # Deliberately non-compliant: public blob access allowed, required tag absent.
  # It is only ever reported on — nothing in this stack modifies it unless you
  # turn on both enable_remediation and enforce_policies.
  allow_nested_items_to_be_public = true

  tags = var.tags

  lifecycle {
    # Relevant only in the opt-in remediation path, where policy adds the tag
    # out of band. Harmless otherwise.
    ignore_changes = [tags]
  }
}

# Deliberately in the wrong region. Tagged and locked down, so the only thing
# wrong with it is where it lives — which is exactly what the built-in Deny
# policy objects to. DoNotEnforce lets it exist; the compliance report shows
# that, with enforcement on, Azure would have refused to create it.
resource "azurerm_storage_account" "wrong_region" {
  name                     = replace("stwrong${var.prefix}${random_string.suffix.result}", "-", "")
  resource_group_name      = azurerm_resource_group.this.name
  location                 = var.out_of_policy_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  allow_nested_items_to_be_public = false

  tags = local.rg_tags
}

###############################################################################
# Custom policy definitions (subscription scope)
#
# Creating a definition changes nothing on its own. A definition is inert until
# it is assigned to a scope — which is a useful thing to say out loud, because
# it is why the definitions here are unconditional and the assignment is not.
###############################################################################

resource "azurerm_policy_definition" "audit_public_blob" {
  name         = "audit-storage-public-blob-${random_string.suffix.result}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "[Precon] Storage accounts must disable public blob access"
  description  = "Storage accounts that allow anonymous blob access are flagged. The deck treats public storage exposure as a finding."

  metadata = jsonencode({
    category = "Storage"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
      metadata = {
        displayName = "Effect"
        description = "Audit to report, Deny to block at create time."
      }
    }
  })

  policy_rule = file("${path.module}/policies/audit-storage-public-blob-access.json")
}

resource "azurerm_policy_definition" "audit_required_tag" {
  name         = "audit-required-tag-${random_string.suffix.result}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "[Precon] Resources must carry the chargeback tag"
  description  = "Tags drive cost reporting, automation and ownership — this is the audit half of enforcing them."

  metadata = jsonencode({
    category = "Tags"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
      metadata = {
        displayName = "Effect"
      }
    }
    tagName = {
      type         = "String"
      defaultValue = "CostCenter"
      metadata = {
        displayName = "Tag name"
      }
    }
  })

  policy_rule = file("${path.module}/policies/audit-required-tag.json")
}

# Opt-in only. This is the one definition in the stack whose effect can write to
# a resource, so it is not created unless you ask for it.
resource "azurerm_policy_definition" "modify_inherit_tag" {
  count = var.enable_remediation ? 1 : 0

  name         = "modify-inherit-tag-${random_string.suffix.result}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "[Precon] Inherit the chargeback tag from the resource group"
  description  = "Modify effect — adds the tag from the parent resource group when it is missing. Requires a managed identity on the assignment."

  metadata = jsonencode({
    category = "Tags"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    tagName = {
      type         = "String"
      defaultValue = "CostCenter"
      metadata = {
        displayName = "Tag name"
      }
    }
  })

  policy_rule = templatefile("${path.module}/policies/modify-inherit-tag.json.tftpl", {
    tag_contributor_role_definition_id = data.azurerm_role_definition.tag_contributor.role_definition_id
  })
}

###############################################################################
# One built-in policy, to show you do not write everything yourself
#
# "Allowed locations" has a hardcoded Deny effect. It is safe here precisely
# because the assignment runs in DoNotEnforce mode — and demonstrating that is
# more valuable than picking a policy that could never bite.
###############################################################################

data "azurerm_policy_definition_built_in" "allowed_locations" {
  display_name = "Allowed locations"
}

###############################################################################
# Initiative (policy set definition)
###############################################################################

resource "azurerm_policy_set_definition" "guardrails" {
  name         = "precon-guardrails-${random_string.suffix.result}"
  policy_type  = "Custom"
  display_name = "[Precon] Admin to Architect baseline guardrails"
  description  = "Location, tagging and public-exposure guardrails — the initiative you would attach to a landing zone."

  metadata = jsonencode({
    category = "Precon Demo"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    auditEffect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
      metadata = {
        displayName = "Effect for the audit policies"
      }
    }
    tagName = {
      type         = "String"
      defaultValue = "CostCenter"
      metadata = {
        displayName = "Chargeback tag name"
      }
    }
    allowedLocations = {
      type         = "Array"
      defaultValue = ["eastus2"]
      metadata = {
        displayName = "Allowed locations"
        strongType  = "location"
      }
    }
  })

  policy_definition_reference {
    reference_id         = "auditPublicBlob"
    policy_definition_id = azurerm_policy_definition.audit_public_blob.id
    parameter_values = jsonencode({
      effect = { value = "[parameters('auditEffect')]" }
    })
  }

  policy_definition_reference {
    reference_id         = "auditRequiredTag"
    policy_definition_id = azurerm_policy_definition.audit_required_tag.id
    parameter_values = jsonencode({
      effect  = { value = "[parameters('auditEffect')]" }
      tagName = { value = "[parameters('tagName')]" }
    })
  }

  dynamic "policy_definition_reference" {
    for_each = var.enable_remediation ? [1] : []
    content {
      reference_id         = "modifyInheritTag"
      policy_definition_id = azurerm_policy_definition.modify_inherit_tag[0].id
      parameter_values = jsonencode({
        tagName = { value = "[parameters('tagName')]" }
      })
    }
  }

  policy_definition_reference {
    reference_id         = "allowedLocations"
    policy_definition_id = data.azurerm_policy_definition_built_in.allowed_locations.id
    parameter_values = jsonencode({
      listOfAllowedLocations = { value = "[parameters('allowedLocations')]" }
    })
  }
}

###############################################################################
# Assignment — resource group scope, DoNotEnforce by default
###############################################################################

resource "azurerm_resource_group_policy_assignment" "guardrails" {
  count = var.create_policy_assignment ? 1 : 0

  name                 = "precon-guardrails"
  display_name         = "[Precon] Baseline guardrails${var.enforce_policies ? "" : " (report-only)"}"
  description          = "Scoped to one demo resource group. ${var.enforce_policies ? "Enforcing." : "Enforcement mode is DoNotEnforce: compliance is evaluated and reported, effects do not fire."}"
  resource_group_id    = azurerm_resource_group.this.id
  policy_definition_id = azurerm_policy_set_definition.guardrails.id

  # false => DoNotEnforce. This is the report-only switch.
  enforce = var.enforce_policies

  # A location is only required when the assignment carries a managed identity,
  # and it only carries one on the opt-in remediation path.
  location = local.remediation_active ? var.location : null

  dynamic "identity" {
    for_each = local.remediation_active ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  parameters = jsonencode({
    auditEffect      = { value = var.audit_effect }
    tagName          = { value = var.required_tag_name }
    allowedLocations = { value = [var.location] }
  })

  non_compliance_message {
    content = "This resource violates the Admin-to-Architect baseline: check location, the ${var.required_tag_name} tag, and public blob access."
  }

  # Create the sample resources first so they land non-compliant and the
  # compliance blade has something to show.
  depends_on = [
    azurerm_storage_account.compliant,
    azurerm_storage_account.noncompliant,
    azurerm_storage_account.wrong_region,
  ]
}

# Only created on the opt-in remediation path. Scoped to the demo resource
# group, and to the single least-privileged role that can write a tag.
resource "azurerm_role_assignment" "remediation" {
  count = local.remediation_active ? 1 : 0

  scope                = azurerm_resource_group.this.id
  role_definition_name = "Tag Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.guardrails[0].identity[0].principal_id
}
