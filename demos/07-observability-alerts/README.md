# Demo 07 — Observability & Cost Guardrails

**Deck slide:** *Demonstration — Observability & Cost Guardrails* (Section 8 — Operations: Observability & Cost)

> - Diagnostic settings deployed by policy, not by hand
> - Generate denied requests, find them in KQL, and get the alert on your phone
> - A budget routed to the same action group

**Runs after:** *FinOps — Make Cost Somebody's Job* — but beat 0 starts at *Alerts That Wake the Right Person*
**Length:** 10–12 minutes live (plus pre-flight)
**WAF pillars on screen:** Operational Excellence, Security, Cost Optimization

---

## ⚠️ This stack enforces one policy — in its own resource group only

Unlike demo 02, this assignment is **enforced**. DeployIfNotExists in DoNotEnforce
mode does nothing at create time, and "at create time" is the point of the demo.
What that means in practice:

| Control | Value | Effect |
|---|---|---|
| Policy | Built-in *Enable logging by category group for Key vaults (microsoft.keyvault/vaults) to Log Analytics* | Adds a diagnostic setting to a Key Vault that doesn't have one |
| Scope | This stack's own resource group | Never a subscription, never a management group |
| Identity | System-assigned on the assignment, `Log Analytics Contributor` on this resource group | Enough to write a diagnostic setting; nothing else |

The only thing this assignment can ever do is add a diagnostic setting to a Key
Vault in this resource group. Set `diagnostics_via_policy = false` to skip the
policy entirely — Terraform then creates the same setting directly.

---

## The one thing they should leave with

> **Telemetry is a decision you make before the incident, and you make it at scale
> with policy, not diligence.** The vault in this demo was logging from the moment
> it existed and nobody configured it. The metric tells you *fast* that something
> is wrong; the log tells you *who*. Both page the same people — and so does the
> budget.

---

## What the Terraform builds

| Resource | Why it's there |
|---|---|
| Log Analytics workspace + three saved queries (category **Precon**) | One destination; nobody types KQL live |
| Policy assignment (DeployIfNotExists) + identity + role assignment | Diagnostics at birth, the landing-zone way |
| Remediation task (`ReEvaluateCompliance`) | Belt and braces — a new assignment can take a while to become effective |
| Key Vault, RBAC mode, **no data-plane role assignments for anyone** | Every secret read is a 403, including yours. That's the signal |
| Action group: email and/or SMS | Where every alert *and* the budget go |
| Metric alert: `ServiceApiResult`, `StatusCode = 403`, 1-minute frequency | Fast. Knows *that*, not *who* |
| Log alert: KQL on `AzureDiagnostics`, split by caller and IP, 5-minute frequency | Slower. Knows *who* and *from where* |
| Resource-group budget: 50% actual, 100% forecasted | Cost is an operational signal — same action group |

**Fallback** (`diagnostics_via_policy = false`): no assignment, identity, role or
remediation; one `azurerm_monitor_diagnostic_setting` instead. Same table, same
queries, same alerts.

---

## Pre-flight — start this 60 minutes before you present

Policy remediation and log ingestion both take minutes. Deploy early.

```bash
cd demos/07-observability-alerts/terraform
cp terraform.tfvars.example terraform.tfvars   # set alert_email and/or alert_sms_number

az login
az account set --subscription "<your-subscription-id>"

terraform init
terraform apply            # ~3 minutes, including a deliberate 60 s RBAC wait

terraform output alert_routing
```

Azure sends a *"You've been added to an action group"* email/SMS. **Check you got
it** — that proves routing to your phone works before you rely on it on stage.

At **T-30**, prime the workspace so the table exists and the queries have data:

```bash
eval "$(terraform output -raw generate_denied_requests_command)"
```

Yes, that fires both alerts. That's your rehearsal. They auto-resolve.

At **T-15**, confirm everything landed:

```bash
eval "$(terraform output -raw check_diagnostic_setting_command)"   # expect setByPolicy-LogAnalytics
eval "$(terraform output -raw remediation_status_command)"
eval "$(terraform output -raw query_command)"                      # expect rows
```

The first `az monitor log-analytics query` may offer to install a CLI extension.
Accept it now, not on stage.

**Requires:** `Owner` or `User Access Administrator` (one role assignment for the
policy identity) — `Owner` also covers creating the policy assignment.

---

## Run of show

### 0. Set it off *(30 seconds — at the "Alerts That Wake the Right Person" slide)*

```bash
cd demos/07-observability-alerts/terraform
eval "$(terraform output -raw generate_denied_requests_command)"
```

> "I just tried to read secrets from a vault fifteen times and got refused fifteen
> times. I'm Owner on this subscription. Hold that thought — and when my phone
> goes off in a few minutes, that's why."

Go back to the slides. When the phone buzzes mid-section, call it out.

### 1. Nobody configured this *(2 min)*

Portal → the vault → **Monitoring** → **Diagnostic settings** → `setByPolicy-LogAnalytics`.

> "I didn't create this. Nothing in my Terraform creates this."

Show [`terraform/main.tf`](terraform/main.tf): the only `azurerm_monitor_diagnostic_setting`
has `count = var.diagnostics_via_policy ? 0 : 1`.

Portal → **Policy** → **Assignments** → `[Precon] Key Vault audit logs…` → the
built-in definition, then the **Remediation** tab.

> "Microsoft wrote this policy; I assigned it. Assign it at the landing zone and
> that's every vault in the company — including the ones created next year by
> people who've never heard of a diagnostic setting. That's the difference between
> a standard and a hope."

Callback to demo 02:

> "Demo 02 was Audit and Deny — tell me what's wrong, or stop it happening. This
> is the third verb: *fix it*."

And the cost choice hiding in the parameters:

> "`categoryGroup = audit`, not `allLogs`. Which logs you collect is a cost
> decision — make it on purpose."

### 2. Control plane vs data plane *(1 min)*

Portal → the vault → **Objects** → **Secrets**: *"You are unauthorized to view these contents."*
Then **Access control (IAM)** → **Role assignments**: no Key Vault data roles.

> "Owner on the subscription lets me manage this vault — I could delete it. It
> doesn't let me read a secret in it. On an RBAC vault, control plane and data
> plane are separate grants, and that's exactly what you want."

### 3. The fast signal *(2 min)*

Your phone should have gone off already. Portal → **Monitor** → **Alerts** →
`alert-kv-forbidden-…` → **Fired**. Open the rule: `ServiceApiResult`, `StatusCode = 403`.

> "Why 403 and not 4xx? Because every Key Vault client's *first* request is a 401
> — that's the authentication challenge, by design. Alert on 4xx and you page
> someone for every login. Knowing what normal looks like is half of alert design."

> "This alert knows *that* something is being denied. It doesn't know who.
> Platform metrics are fast and free — and thin."

### 4. The rich signal *(3 min)*

Workspace → **Logs** → **Queries** → **Precon** → *Key Vault — denied requests by caller* → **Run**.

Point at `Caller` (your UPN), `CallerIPAddress`, `OperationName` (`SecretList`).

> "Now I know who, from where, and what they tried. That's the second alert — one
> per caller — and it's slower, because the log has to be exported, ingested and
> then queried on a schedule. Minutes, not seconds."

Open the log alert rule: 5-minute frequency, split by `Caller` and `CallerIPAddress`.

> "Two alerts on one event isn't redundancy, it's design. The metric wakes you up;
> the log tells you what to do once you're awake."

Then *Which resources are actually sending logs*:

> "Run this one monthly. It finds the things policy missed."

### 5. A budget is an alert too *(2 min)*

Portal → the resource group → **Cost Management** → **Budgets** → `budget-…`.
Show the two thresholds — 50% actual, 100% forecasted — and where they go.

> "Cost data lags by hours, so this won't fire on stage. But look where it's
> routed: the same action group as the security alert. The runaway resource and
> the attacker both show up as *something changed* — and both should reach a
> person who owns it."

---

## If it breaks on stage

| Symptom | Cause | Fix |
|---|---|---|
| No diagnostic setting on the vault | Remediation still running | `remediation_status_command`. If stuck, `terraform apply -var 'diagnostics_via_policy=false'` (~30 s) and say why |
| Remediation succeeded with 0 resources | Assignment not evaluated yet when it ran | `az policy remediation create -n precon-kv-diag-2 -g <rg> --policy-assignment precon-kv-diagnostics --resource-discovery-mode ReEvaluateCompliance` |
| Saved query: "Failed to resolve table AzureDiagnostics" | No log has ever reached this workspace | Prime it at T-30; logs take 2–10 minutes to arrive |
| Saved query returns nothing | Requests too recent, or no diagnostic setting | Check the setting; wait a few minutes; run the loop again |
| No email or SMS | Routing unset, or notification lag | `terraform output alert_routing`. **Monitor → Alerts** shows fired alerts regardless |
| Metric alert didn't fire | Fewer than 5 denials in the 5-minute window | Run the loop again; allow 1–3 minutes |
| `az keyvault secret list` *succeeds* | You hold a data-plane role from elsewhere (e.g. Key Vault Administrator inherited from the subscription) | `az role assignment list --scope <vault-id> --include-inherited -o table` — and that's a finding in itself |
| Budget apply fails: offer not supported | Some subscription types don't support budgets | `create_budget = false` |

---

## Teardown

```bash
cd demos/07-observability-alerts/terraform
terraform destroy
```

The diagnostic setting the policy created isn't in Terraform state. Diagnostic
settings can outlive their resource and reattach if a resource with the same name
is recreated — harmless here (random suffix, purged vault), worth knowing in production.

---

## Approximate cost

| Component | Cost |
|---|---|
| Log Analytics ingestion | ~$2.30/GB; this demo produces kilobytes |
| Key Vault operations | ~$0.03 per 10,000 |
| Metric alert rule | ~$0.10/month per monitored time series |
| Log alert rule, 5-minute frequency | ~$1.50/month, prorated |
| Email notifications | Free at this volume; SMS fractions of a cent each |
| Budget | Free |

**Pennies per day.**
