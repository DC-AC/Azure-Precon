# Demo Summary — *Azure: From Admin to Architect*

One page per demo: what it proves, what to do before you go on, and the beats in
order. The full talk track, troubleshooting tables and costs are in each demo's
own README — this is the version you glance at between sections.

All commands run from the demo's `terraform/` folder, e.g.
`cd demos/01-azure-sql-private/terraform`.

| # | Demo | Section | Length | The point |
|---|---|---|---|---|
| [01](#01--azure-sql-locked-down) | Azure SQL, Locked Down | 2 — Azure SQL, Fabric & Data Platform | 12–15 min | No password, no public address — and the app still works |
| [02](#02--policy--compliance) | Policy & Compliance | 3 — Governance | 8–10 min | See exactly what a Deny policy *would* block before it blocks anything |
| [03](#03--vnet-peering--hub-and-spoke) | VNet Peering | 4 — Networking | 10–12 min | Peering is non-transitive — watch the ping fail |
| [04](#04--key-vault-certificate-auto-rotation) | Key Vault Cert Rotation | 6 — Identity, Secrets & Security Posture | 8–10 min | A certificate that renews itself and tells you it did |
| [05](#05--function-app) | Function App | 7 — Automation & Serverless | 8–10 min | Find the storage connection string. There isn't one |
| [06](#06--logic-app-workflow) | Logic App Workflow | 7 — Automation & Serverless | 8–10 min | Low-code is not un-architected |
| [07](#07--observability--cost-guardrails) | Observability & Cost | 8 — Operations | 10–12 min | Logging from birth by policy; an alert on your phone |

### When to deploy

| When | What |
|---|---|
| **Day before** | **01** (restore needs a first backup, ~18 min after creation) · **03** with the VPN gateway (~32 min) · **01** and **05** code publish |
| **T-60** | **02**, **04**, **06**, **07** — 2–9 min each (07 is slowest); 07's policy then needs 15–30 min |
| **T-45** | **02**: trigger the compliance scan |
| **T-30** | **01**: update `client_ip_address` to the venue IP · **07**: generate denied requests once |
| **T-15** | Wake **01**'s database · run each demo's verification command |

Before anything: an MFA-backed `az login`. If Terraform gets
`RequestDisallowedByAzure … MFA`, see the *Mandatory MFA* note in
[README.md](README.md#prerequisites).

---

## 01 — Azure SQL, Locked Down

**Folder:** [`01-azure-sql-private`](01-azure-sql-private/) · **Slide:** after *Vectors in Azure SQL* · **Length:** 12–15 min

**The point:** Identity replaces the password, Private Link replaces the public
path, and the only permission you type by hand is one line of T-SQL. Your RTO is
a number you measure, not one from a slide.

**What's deployed:** an Entra-only Azure SQL server with a serverless database
(AdventureWorksLT), a private endpoint and private DNS zone, and a
VNet-integrated Flex Consumption function that queries it as a managed identity.

**Before you go on**
- Deployed the day before, code published (`eval "$(terraform output -raw deploy_command)"`)
- `client_ip_address` in `terraform.tfvars` set to the venue IP, then `terraform apply`
- Database woken at T-15: `eval "$(terraform output -raw connect_command)"`
- **Don't** run the grant in pre-flight — the 500 is beat 3

**Steps**
0. **Start the clock** — at the *top of Section 2*, in a second terminal:
   `eval "$(terraform output -raw restore_command)"`. Leave it running.
1. **The server with no password** — `main.tf` → `azuread_authentication_only = true`,
   no `administrator_login`. Portal → SQL server → **Microsoft Entra ID**.
2. **Connect as yourself** — `eval "$(terraform output -raw connect_command)"` →
   your UPN and your laptop's public IP.
3. **Authentication is not authorization** —
   - Call `whoami` → **500**: Entra knows the function, the database doesn't
   - `eval "$(terraform output -raw grant_command)"` (one `CREATE USER … FROM EXTERNAL PROVIDER`)
   - Call `whoami` again → **200**, `client_address` **10.60.1.x** (the private path); then `products`
4. **Close the front door** — `terraform apply -var 'public_network_access_enabled=false'`
   (~75 s). Laptop: *"Deny Public Network Access is set to Yes."* Function: still 200.
5. **The RTO you actually have** — read the elapsed time in the second terminal
   (~10 minutes in testing). Note `backup_storage_redundancy = Local` means no geo-restore.

**Reset afterwards:** `terraform apply` (public access back on) → `DROP USER` for
the function (command in the README) → delete `sqldb-adventureworks-restored`.

---

## 02 — Policy & Compliance

**Folder:** [`02-policy-compliance`](02-policy-compliance/) · **Slide:** after *Azure Policy — Compliance as Code* · **Length:** 8–10 min

**The point:** RBAC controls who can act; Policy controls what may exist. Run a
guardrail in DoNotEnforce first and Azure lists everything it *would* have
blocked — before it blocks anything.

**What's deployed:** an initiative (two custom audit policies plus the built-in
*Allowed locations*, a Deny policy) assigned to the demo resource group in
**DoNotEnforce** mode, and three storage accounts: `stgood` (compliant),
`stbad` (no `CostCenter` tag, public blob access), `stwrong` (wrong region).

**Before you go on**
- Applied at T-60, scan triggered at T-45:
  `az policy state trigger-scan --resource-group "$(terraform output -raw resource_group_name)"`
- `terraform output mode` says **REPORT-ONLY**
- `eval "$(terraform output -raw compliance_command)"` returns rows

**Steps**
1. **The guardrail as code** — open `policies/audit-storage-public-blob-access.json`:
   an `if` and a `then`, nothing else.
2. **Definitions are inert, assignments are the live wire** — Portal → **Policy** →
   **Definitions** (`[Precon]`), then **Assignments** → enforcement *Disabled*.
3. **View non-compliant resources** — `eval "$(terraform output -raw compliance_command)"`
   → `stbad` (tag, public blob) and `stwrong` (location). `stgood` is clean.
4. **The report-only payoff** — `eval "$(terraform output -raw would_have_blocked_command)"`
   → the **`deny`** row on `stwrong`: it exists only because enforcement is off.
   Show `enforce = var.enforce_policies` — one boolean in a PR.
5. **Close the loop** — definition (free) → initiative → assign report-only →
   flip enforcement. The risky step is last and reversible.

**Reset afterwards:** nothing — it's report-only.

---

## 03 — VNet Peering & Hub-and-Spoke

**Folder:** [`03-vnet-peering`](03-vnet-peering/) · **Slide:** after *VNet Peering & Hub-and-Spoke* · **Length:** 10–12 min

**The point:** Peering is non-transitive. Both spokes reach the hub; the spokes
don't reach each other until you build that route.

**What's deployed:** a hub and two spoke VNets, hub↔spoke peerings (two
resources per link), an NSG using service tags, three Ubuntu VMs with no public
IPs, and optionally a `VpnGw1AZ` gateway with gateway transit.

**Before you go on**
- Deployed the day before with `deploy_vpn_gateway = true` (~32 min)
- `eval "$(terraform output -raw test_hub_to_spoke1)"` returns 3 replies

**Steps**
1. **The shape** — Portal → resource group → **Resource visualizer**.
2. **Peering is two resources** — `vnet-hub` → **Peerings**, then the spoke's side.
   Same in `main.tf`: one resource per direction.
3. **Hub ↔ spoke works** — `eval "$(terraform output -raw test_hub_to_spoke1)"` →
   3 replies. `eval "$(terraform output -raw effective_routes_command)"` → a
   peering route to the hub only.
4. **The failure** — `eval "$(terraform output -raw test_spoke1_to_spoke2)"` →
   **100% packet loss**. That's the point.
5. **Fix it live** — `terraform apply -var 'enable_spoke_to_spoke_peering=true' -auto-approve`
   (~80 s) → ping again → 3 replies. At scale the answer is a hub firewall or
   Virtual WAN, not a mesh.
6. **Gateway transit** — hub peering: *Allow gateway transit*; spoke peering:
   *Use remote gateway*. One gateway, every spoke borrows it.
7. *(Optional, if `deploy_bastion = true`)* **Bastion** — connect to `vm-spoke1`
   with no public IP.

**Reset afterwards:** `terraform apply` (tfvars has spoke-to-spoke off).

---

## 04 — Key Vault Certificate Auto-Rotation

**Folder:** [`04-keyvault-cert-rotation`](04-keyvault-cert-rotation/) · **Slide:** after *Azure Key Vault — Secrets, Keys, Certificates* · **Length:** 8–10 min

**The point:** Every certificate outage was a calendar reminder someone missed.
Key Vault renews on a schedule, issues a new key pair, and raises an event.

**What's deployed:** an RBAC-mode Key Vault, a self-signed certificate with an
auto-renew lifetime action at 80%, an app identity holding roles (not secrets),
and Event Grid delivering certificate events to a storage queue.

**Before you go on**
- Applied at T-60 (~5 min)
- `eval "$(terraform output -raw peek_events_command)"` shows one event (your
  queue-reader role takes 1–2 min to apply after deploy)

**Steps**
1. **Frame the failure mode** — certificate outages are a process failure.
2. **How access works now** — Portal → vault → **Access configuration** → Azure
   RBAC; **Access control (IAM)** → roles, not access policies.
3. **The rotation policy** — **Certificates** → `app-tls-cert` → **Issuance Policy**
   → *Lifetime Action*: auto-renew at 80%.
4. **Rotate it live** — thumbprint before → `eval "$(terraform output -raw rotate_now_command)"`
   → thumbprint after → `az keyvault certificate list-versions …`: new thumbprint,
   two versions, new expiry.
5. **The event nobody has to watch for** — `eval "$(terraform output -raw peek_events_command)"`
   → one decoded line per event: a second `CertificateNewVersionCreated`, timestamped
   a minute ago.

**Reset afterwards:** nothing — extra versions are harmless.

---

## 05 — Function App

**Folder:** [`05-function-app`](05-function-app/) · **Slide:** after *Azure Functions — Event-Driven Compute* · **Length:** 8–10 min

**The point:** The interesting part isn't the code — it's that there's no
credential in it. Storage access is a managed identity with a role, and the bill
starts when a request arrives.

**What's deployed:** a Flex Consumption (FC1) Python function app with
`hello`, `heartbeat` (timer) and `load`; a storage account reached only by
managed identity; Application Insights.

**Before you go on**
- Applied and code published the day before (`eval "$(terraform output -raw deploy_command)"`)
- `hello` returns 200 (see step 3 for the command)

**Steps**
1. **The plan is the architecture decision** — function app → plan **FC1**;
   `instance_memory_in_mb` and `maximum_instance_count` set on purpose.
2. **Find the secret** — **Settings** → **Environment variables**: only
   `AzureWebJobsStorage__accountName` (plus an *empty* `AzureWebJobsStorage` — a
   provider workaround). **Identity** tab; storage **IAM** → four role
   assignments, zero secrets.
3. **Verify it runs** —
   `FUNC_URL=$(terraform output -raw function_app_url); KEY=$(eval "$(terraform output -raw function_key_command)")`
   then `curl -s "$FUNC_URL/api/hello?name=$USER&code=$KEY"` → a fresh `instance`.
   The `heartbeat` timer proves keyless storage (it needs a blob lock).
4. **Scale on demand** — Application Insights → **Live metrics**, then 60
   concurrent `load` calls (loop in the README) → instance count climbs
   (55 instances for 60 requests in testing).
5. *(Optional)* **The cold-start trade-off** — `terraform apply -var 'always_ready_instance_count=1' -auto-approve`:
   no cold start, billed 24×7.

**Reset afterwards:** `terraform apply` (always-ready back to 0 — it costs money otherwise).

---

## 06 — Logic App Workflow

**Folder:** [`06-logic-app`](06-logic-app/) · **Slide:** after *Azure Logic Apps — Workflow Orchestration* · **Length:** 8–10 min

**The point:** Low-code changes who can author the flow, not who owns the
governance. The workflow is Terraform, the business rule is a reviewable
variable, the connector uses a managed identity.

**What's deployed:** a Consumption Logic App — HTTP trigger → compose →
*If amount > threshold* → 200 auto-approved or 202 escalated — with a managed
identity pre-authorized to send to a storage queue.

**Before you go on**
- Applied at T-60 (~2½ min); both curls in step 2 return 200 and 202

**Steps**
1. **Trigger-driven** — Portal → Logic App → **Logic app designer**: the HTTP
   trigger and its schema.
2. **Run it** — `eval "$(terraform output -raw curl_auto_approved)"` → **200**;
   `eval "$(terraform output -raw curl_escalated)"` → **202**.
3. **Run history** — **Overview** → **Runs history** → the escalated run: every
   input and output.
4. **The governance point** — `terraform apply -var 'approval_threshold=100' -auto-approve`,
   post the small order again → now **202**. The business rule is a diff.
5. *(Optional)* **Managed identity on a connector** — designer → *Azure Queues* →
   *Put a message on a queue* → authenticate with the managed identity. Fire the
   escalated order again, then show the message in the portal: storage account →
   **Queues** → `escalations`. Don't peek from the CLI as yourself — only the
   workflow has a queue role, so it's refused (control plane vs data plane).

**Reset afterwards:** `terraform apply` (threshold back to 5000).

---

## 07 — Observability & Cost Guardrails

**Folder:** [`07-observability-alerts`](07-observability-alerts/) · **Slide:** after *FinOps — Make Cost Somebody's Job* · **Length:** 10–12 min

**The point:** Telemetry is a decision you make before the incident, and you
make it at scale with policy. The metric tells you fast; the log tells you who.
The budget pages the same people.

**What's deployed:** an enforced DeployIfNotExists policy (this resource group
only) that wires Key Vault audit logs to Log Analytics; a vault nobody has a
data role on; a metric alert and a log alert on 403s; an action group; a
resource-group budget.

**Before you go on**
- `alert_email` and/or `alert_sms_number` set in `terraform.tfvars` — without
  them the alerts fire but reach nobody. You'll get an *"added to an action group"*
  message when routing works
- Applied at T-60 (6–9 min); denied requests generated once at T-30
- At T-15: `check_diagnostic_setting_command` shows `setByPolicy-LogAnalytics`;
  `query_command` returns rows

**Steps**
0. **Set it off** — at the *"Alerts That Wake the Right Person"* slide:
   `eval "$(terraform output -raw generate_denied_requests_command)"` (15 denied reads).
1. **Nobody configured this** — vault → **Diagnostic settings** →
   `setByPolicy-LogAnalytics`. Policy → **Assignments** → the built-in definition.
   Demo 02 was Audit and Deny; this is the third verb — *fix it*.
2. **Control plane vs data plane** — vault → **Secrets**: unauthorized, even as
   subscription Owner.
3. **The fast signal** — **Monitor** → **Alerts** → the metric alert (fired ~2½ min
   after the requests). Why 403, not 4xx: every client's first call is a 401 challenge.
4. **The rich signal** — workspace → **Logs** → **Queries** → *Precon* → *denied
   requests by caller*: who, from where, what. The log alert fired at ~5 min.
5. **A budget is an alert too** — resource group → **Cost Management** →
   **Budgets**: 50% actual, 100% forecast, same action group.

**Reset afterwards:** nothing.
