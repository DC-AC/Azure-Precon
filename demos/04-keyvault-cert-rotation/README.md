# Demo 04 — Certificate Auto-Rotation in Key Vault

**Deck slide:** *Demonstration — Certificate Auto-Rotation in Key Vault* (Section 6 — Identity, Secrets & Security Posture)

> - Configure automated certificate rotation to remove manual renewal risk

**Runs after:** *Azure Key Vault — Secrets, Keys, Certificates*
**Length:** 8–10 minutes live
**WAF pillars on screen:** Security, Operational Excellence, Reliability

---

## The one thing they should leave with

> **Every certificate outage you have ever had was a calendar reminder someone
> missed.** Key Vault will renew the certificate on a schedule, issue a fresh key
> pair, and raise an event when it does. Nobody has to remember anything.

---

## What the Terraform builds

```
Key Vault (RBAC authorization, soft-delete on)
     │
     ├── you ─────────── Key Vault Administrator      (needed to create the cert)
     │
     ├── certificate ─── lifetime_action { AutoRenew @ 80% }   <── the demo
     │                   reuse_key = false                     <── new key each renewal
     │
     ├── user-assigned identity ── Certificate User + Secrets User
     │        (stands in for App Service / App Gateway — holds no secret)
     │
     └── Event Grid system topic ──> storage queue
              CertificateNewVersionCreated / NearExpiry / Expired
```

| Design choice | Why |
|---|---|
| `rbac_authorization_enabled = true` | Access policies are the legacy model; they don't compose with PIM or Conditional Access |
| `reuse_key = false` | Rotating the cert but reusing the key rotates half the problem |
| `time_sleep` before the certificate | Entra role assignments are eventually consistent — without it the first apply 403s |
| `purge_protection_enabled = false` | Production-correct is `true`, but it can never be turned off and would block teardown for 7 days |
| `public_network_access_enabled = true` | Demo only. Real vaults get a private endpoint — call this out on stage |
| `Storage Queue Data Reader` for you on the events account | So `peek_events_command` works with `--auth-mode login` — reading messages is a data-plane grant, like Key Vault's |

---

## Pre-flight

```bash
cd demos/04-keyvault-cert-rotation/terraform
cp terraform.tfvars.example terraform.tfvars

az login
az account set --subscription "<your-subscription-id>"

terraform init
terraform apply          # ~5 minutes: the vault takes ~2½, then a deliberate 60 s RBAC wait
```

Verify:

```bash
terraform output certificate_thumbprint
eval "$(terraform output -raw list_versions_command)"     # expect exactly one version
eval "$(terraform output -raw peek_events_command)"       # works once your queue role applies (1–2 min)
```

**Requires:** `Owner` or `User Access Administrator` — Terraform grants itself
Key Vault Administrator and Storage Queue Data Reader, and those are role assignments.

> **Write the starting thumbprint on the whiteboard.** The before/after comparison
> in step 4 is the moment the demo lands, and squinting at a terminal scroll-back
> kills it.

---

## Run of show

### 1. Frame the failure mode *(1 min)*

Before touching the portal:

> "Show of hands — who has had an outage caused by an expired certificate?
> Keep it up if you found out from a customer rather than from a monitor."

> "That is not an operational failure. It is an *architectural* one. You built a
> system whose availability depends on a human remembering a date eleven months
> from now."

### 2. The vault, and how access works now *(2 min)*

Portal → Key Vault → **Access configuration**. Show **Azure role-based access control**
is selected.

> "Not access policies. Access policies were a separate, parallel permission system
> that only Key Vault understood — so your PIM setup, your Conditional Access, your
> access reviews all stopped at the vault door. RBAC means the vault obeys the same
> identity control plane as everything else in this deck."

**Access control (IAM)** → show two assignments:

- you → **Key Vault Administrator**
- `id-app-…` → **Key Vault Certificate User** + **Key Vault Secrets User**

> "That second one is a managed identity — an App Service, an Application Gateway,
> a container. Notice what I did not create: a client secret, a connection string,
> a password in a pipeline variable. There is nothing to rotate because there is
> nothing to leak."

### 3. The rotation policy *(2 min)*

Portal → **Certificates** → `app-tls-cert` → **Issuance Policy**. Show **Lifetime Action**:
*Automatically renew at a given percentage lifetime — 80%*.

Then show the same thing in code — [`terraform/main.tf`](terraform/main.tf):

```hcl
lifetime_action {
  action  { action_type = "AutoRenew" }
  trigger { lifetime_percentage = 80 }
}
```

> "Six lines. A 90-day certificate renews itself on day 72 and leaves an 18-day
> margin. The other option in that dropdown is `EmailContacts` — which is a
> polite way of saying *go do it by hand*. That's the option that caused the
> outage you all just raised your hand about."

Point at `reuse_key = false`:

> "New key pair every renewal. If you reuse the key you have rotated the paperwork,
> not the cryptography."

And `issuer_parameters { name = "Self" }`:

> "Self-signed because this is a demo. Swap that one field for DigiCert or
> GlobalSign as an integrated CA and you get publicly trusted certificates on the
> same schedule. The rotation policy does not change at all."

### 4. Rotate it live *(3 min)*

Auto-renew fires on day 72, and you don't have 72 days. Trigger the same code path
by hand — re-issuing under the existing policy is exactly what auto-renew does:

```bash
cd demos/04-keyvault-cert-rotation/terraform
KV=$(terraform output -raw key_vault_name)
CERT=$(terraform output -raw certificate_name)

# Before
az keyvault certificate show --vault-name "$KV" -n "$CERT" --query "x509ThumbprintHex" -o tsv

# Rotate — identical to what the scheduled renewal does
eval "$(terraform output -raw rotate_now_command)"

# After
az keyvault certificate show --vault-name "$KV" -n "$CERT" --query "x509ThumbprintHex" -o tsv
az keyvault certificate list-versions --vault-name "$KV" -n "$CERT" \
  --query "[].{created:attributes.created, expires:attributes.expires}" -o table
```

New thumbprint. Two versions. New expiry date.

> "Different thumbprint, different key, new expiry — and the certificate *URI*
> never changed. That's the part that matters for the consumer: an app that binds
> to the versionless URI picks up the new certificate without a config change,
> without a redeploy, without a ticket."

### 5. The event nobody has to watch for *(2 min)*

```bash
eval "$(terraform output -raw peek_events_command)"
```

A `Microsoft.KeyVault.CertificateNewVersionCreated` event is sitting in the queue.

> "Key Vault told Event Grid the moment that happened. The queue is just where I
> parked it for the demo — in your environment that's a Logic App that reloads a
> binding, a Function that pushes the new cert to an appliance that can't read
> Key Vault, a Teams message to the platform channel."

Show the subscription's other event types in the portal (**Events** → the subscription):
`CertificateNearExpiry`, `CertificateExpired`.

> "`NearExpiry` fires 30 days out. If you are ever going to get an expiry outage
> again, you have to actively ignore a message that Azure sent you a month early."

*(Ties directly into Demo 06 — that Logic App is the handler.)*

---

## If it breaks on stage

| Symptom | Cause | Fix |
|---|---|---|
| `terraform apply` fails on the certificate with 403 | RBAC hadn't propagated | Re-run `terraform apply`; the `time_sleep` normally covers it |
| `az keyvault certificate show` → `Forbidden` | Your CLI login differs from the Terraform principal | `az account show` and confirm the object ID matches the role assignment |
| Rotation returns "pending" | Issuance is asynchronous | `az keyvault certificate pending show --vault-name $KV -n $CERT` — self-signed is usually instant |
| Event queue is empty | Event Grid delivery lag | Wait ~60s and peek again; delivery is at-least-once, not instantaneous |
| `az storage message peek` → `AuthorizationPermissionMismatch` / "required permissions" | The stack grants you **Storage Queue Data Reader** on the events account, but RBAC takes 1–2 minutes to apply | Wait and retry. Peek once in pre-flight so you know it works before you're on stage |
| `terraform destroy` hangs on the vault | Purge protection got enabled | It cannot be disabled — the vault clears after the 7-day retention window |

---

## Teardown

```bash
cd demos/04-keyvault-cert-rotation/terraform
terraform destroy
```

The provider is configured with `purge_soft_delete_on_destroy = true`, so the
soft-deleted vault is purged rather than left occupying its name. That is a
**demo-only** setting — never put it in a production provider block.

---

## Approximate cost

Under **$0.10/day**. Standard-tier Key Vault operations are ~$0.03 per 10,000;
one certificate, one storage queue, and a handful of Event Grid events round to nothing.
