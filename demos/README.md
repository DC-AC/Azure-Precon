# Demos — *Azure: From Admin to Architect (2026 Edition)*

Run-of-show scripts and Terraform for every **Demonstration** slide in
[`../slides.md`](../slides.md).

Each demo is a self-contained stack: its own Terraform state, its own resource
group, its own teardown. Nothing here depends on anything else here, so you can
deploy one, all seven, or whatever survives your timing.

---

## Slide map

Numbered in the order they were built, not the order they're presented. In
delivery order: **06**, 01, 02, 03, 04, 05, **07**.

| # | Demo | Deck slide | Section | Live time |
|---|---|---|---|---|
| 06 | [Azure SQL, Locked Down](06-azure-sql-private/) | *Demonstration — Azure SQL, Locked Down* | 2 — Azure SQL & Data Platform | 12–15 min |
| 01 | [Policy & Compliance](01-policy-compliance/) † | *Demonstration — Policy & Compliance* | 3 — Governance | 8–10 min |
| 02 | [VNet Peering](02-vnet-peering/) | *Demonstration — VNet Peering* | 4 — Networking | 10–12 min |
| 03 | [Key Vault Cert Auto-Rotation](03-keyvault-cert-rotation/) | *Demonstration — Certificate Auto-Rotation in Key Vault* | 6 — Identity, Secrets & Security Posture | 8–10 min |
| 04 | [Function App](04-function-app/) | *Demonstration — Create a Function App* | 7 — Automation & Serverless | 8–10 min |
| 05 | [Logic App Workflow](05-logic-app/) | *Demonstration — Logic App Workflow* | 7 — Automation & Serverless | 8–10 min |
| 07 | [Observability & Cost Guardrails](07-observability-alerts/) ‡ | *Demonstration — Observability & Cost Guardrails* | 8 — Operations: Observability & Cost | 10–12 min |

† **Report-only.** Demo 01 assigns its initiative in `DoNotEnforce` mode with
audit-only effects and no managed identity, so it cannot block a deployment or
change a resource. Deny and Modify are separate opt-in switches — and *showing a
Deny policy report what it would have blocked* is the strongest beat in that
demo. See [Blast radius](#blast-radius).

‡ **Enforced, but only inside its own resource group.** Demo 07's
DeployIfNotExists assignment is enforced because "wired at birth" is the point.
The only thing it can do is add a diagnostic setting to a Key Vault in that one
resource group. `diagnostics_via_policy = false` skips the policy entirely.

### Slides these demos also cover for free

The stacks were built so you can reach back to earlier slides without deploying
anything extra:

| Slide | Where it shows up |
|---|---|
| *Infrastructure as Code — The Architect's Default* | Every demo. Open the `.tf` next to the portal blade — that comparison is the argument |
| *Azure Landing Zones* / *Management Groups* | Demo 01 — the assignment scope conversation. Demo 07 — "assign it at the landing zone" |
| *Serverless vs. Provisioned Compute* | Demo 06 — the database pauses itself; `service_objective` shows `GP_S_Gen5_1` |
| *Business Continuity for Azure SQL* | Demo 06 — the timed point-in-time restore, and the `Local` backup redundancy trade-off |
| *Outbound Is Now a Design Decision* | Demo 06 — one subnet with default outbound explicitly on, one explicitly off |
| *Private Endpoints over Service Endpoints over Public* | Demo 06 — the same FQDN refused from the laptop, accepted from the VNet |
| *NSGs & Application Security Groups* | Demo 02 — the NSG uses service tags, not CIDR lists |
| *Azure Bastion* | Demo 02 — set `deploy_bastion = true` |
| *Connectivity Options* (site-to-site, ExpressRoute) | Demo 02 — set `deploy_vpn_gateway = true` |
| *RBAC — Identity as the Control Plane* | Demo 07 — subscription Owner, refused by the vault: control plane vs data plane |
| *Managed Identities — Eliminate Credentials in Code* | Demos 03, 04, 05, 06 — four different services |
| *Securing Storage — Move Past Keys and SAS* | Demo 04 — find the connection string; there isn't one |
| *Azure Policy — Compliance as Code* | Demo 07 — the third verb after Audit and Deny: DeployIfNotExists |
| *VM Deployment Checklist* ("no public IP by default") | Demo 02 — three VMs, zero public IPs |

---

## Layout

```
demos/
├── README.md                      ← you are here
├── scripts/
│   ├── deploy-all.sh              ← deploy some or all stacks
│   └── destroy-all.sh             ← tear them down (prompts for confirmation)
├── 01-policy-compliance/
│   ├── README.md                  ← run-of-show script
│   └── terraform/
│       ├── main.tf variables.tf outputs.tf versions.tf
│       ├── terraform.tfvars.example
│       └── policies/*.json        ← the custom policy definitions
├── 02-vnet-peering/
├── 03-keyvault-cert-rotation/
├── 04-function-app/
│   ├── README.md
│   ├── src/                       ← Python sample functions
│   └── terraform/
├── 05-logic-app/
├── 06-azure-sql-private/
│   ├── README.md
│   ├── sql/                       ← the one T-SQL grant, run live
│   ├── src/                       ← Python functions using the SQL input binding
│   └── terraform/
└── 07-observability-alerts/
```

Every demo README follows the same structure:

1. **The one thing they should leave with** — the single sentence the demo exists to earn
2. **What the Terraform builds** — and *why* each design choice is what it is
3. **Pre-flight** — what to run before you're on stage, and how long it takes
4. **Run of show** — numbered beats with the talk track and the exact commands
5. **If it breaks on stage** — symptom → cause → fix
6. **Teardown** and **approximate cost**

---

## Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.6 | All demos |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | ≥ 2.60 | All demos |
| [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local) | v4 | Demos 04 and 06 |
| [go-sqlcmd](https://learn.microsoft.com/sql/tools/sqlcmd/go-sqlcmd-utility) | any recent | Demo 06 (`brew install sqlcmd`) |
| `jq` | any | Nicer output in a few commands |

Provider versions are pinned in each stack's `.terraform.lock.hcl` — committed on
purpose, so the stack you rehearsed is the stack you present.

> **Mandatory MFA.** Azure now requires MFA for create/update/delete calls from the
> CLI and IaC tools. Run these stacks after an interactive, MFA-backed `az login`.
> In a pipeline, use a managed identity or workload identity federation — that's
> the *Workload Identity Federation* slide.

### Azure permissions

| Demo | Minimum role |
|---|---|
| 01 — Policy | `Resource Policy Contributor` + `Contributor` (defaults create no role assignment). **Owner**/UAA only if you opt into `enable_remediation` |
| 02 — VNet Peering | `Contributor` |
| 03 — Key Vault | **Owner** or `User Access Administrator` (Terraform grants itself Key Vault Administrator) |
| 04 — Function App | **Owner** or `User Access Administrator` (four role assignments) |
| 05 — Logic App | `Contributor`, or **Owner** if `enable_queue_target = true` |
| 06 — Azure SQL | **Owner** or `User Access Administrator` (four role assignments). You become the server's Entra admin |
| 07 — Observability | **Owner**, or `User Access Administrator` + `Resource Policy Contributor` (policy assignment plus one role assignment for its identity) |

> Anything that creates a **role assignment** needs `User Access Administrator` or
> `Owner`. Plain `Contributor` will get most of the way through an apply and then
> fail — which is itself a decent aside for the RBAC slide, but not one you want
> to discover ten minutes before you go on.

---

## Blast radius

Nothing here reaches outside its own resource group. Only one stack — demo 07 —
enforces anything by default, and only inside its own resource group. Worth
knowing before you point any of it at a subscription you share with other people.

| Demo | What it can affect | Can it block or change anything? |
|---|---|---|
| 01 — Policy | Its own resource group | **No.** Report-only: assignment is `DoNotEnforce`, effects are `Audit`, and no managed identity or role assignment is created. Deny and Modify are separate opt-ins |
| 02 — VNet Peering | Its own VNets, NSGs and VMs | No. NSG rules apply only to the subnets this stack creates |
| 03 — Key Vault | Its own vault | Role assignments are scoped to the vault it created — one for you, one for a demo identity |
| 04 — Function App | Its own storage account | Role assignments are scoped to the storage account it created |
| 05 — Logic App | Its own storage account | One role assignment, scoped to the storage account it created |
| 06 — Azure SQL | Its own server, VNet and storage account | Role assignments are scoped to the storage account it created. The one database permission is granted in T-SQL, inside the demo database |
| 07 — Observability | Key Vaults in its own resource group | **Yes, narrowly.** An enforced DeployIfNotExists assignment adds a diagnostic setting to Key Vaults *in its own resource group*. Its identity holds `Log Analytics Contributor` on that resource group only |

Demo 01 is the only stack that could evaluate resources it didn't create, which is
why it ships with three independent safety switches. Check what you deployed:

```bash
terraform -chdir=01-policy-compliance/terraform output mode
# => REPORT-ONLY — assigned at resource group scope in DoNotEnforce mode...

terraform -chdir=07-observability-alerts/terraform output diagnostics_mode
# => POLICY — DeployIfNotExists assignment 'precon-kv-diagnostics' on this resource group...
```

The others create role assignments because a managed identity with a scoped role
is the *point* of those demos — that's the deck's "eliminate credentials in code"
story. Each grant is on a resource the same stack created and disappears with
`terraform destroy`.

---

## Quick start

```bash
az login
az account set --subscription "<your-subscription-id>"

cd demos
./scripts/deploy-all.sh              # all seven
./scripts/deploy-all.sh 01 05        # or just the ones you need
```

Or one at a time, which is what the per-demo READMEs assume:

```bash
cd demos/01-policy-compliance/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

Demos 06 and 07 need values in `terraform.tfvars` before they're useful —
`client_ip_address` for 06, `alert_email` and/or `alert_sms_number` for 07.
`deploy-all.sh` will deploy them without, but the live beats won't land.

---

## Suggested schedule for a full-day precon

| When | Do this | Why |
|---|---|---|
| **Day before** | Demo 02 with `deploy_vpn_gateway = true` | A VPN gateway takes 30–45 minutes |
| **Day before** | Demos 04 and 06 `terraform apply` + `func publish` | First publish does a remote build; it's slow and boring |
| **Day before** | Demo 06 deployed and left overnight | Point-in-time restore needs history; a brand-new database has none |
| **Day before** | Rehearse each demo once, end to end — then reset demo 06 (see its README) | Every failure in the "if it breaks" tables is one somebody hit |
| **T-60 min** | Demos 01, 03, 05, 07 `terraform apply` | All fast (1–3 min each); demo 07's remediation then needs 15–30 min |
| **T-45 min** | `az policy state trigger-scan` for demo 01 | Compliance data takes minutes to appear, and the blade is empty without it |
| **T-30 min** | Demo 06: update `client_ip_address` to the venue IP. Demo 07: generate denied requests once | Venue Wi-Fi isn't your rehearsal network; the workspace needs its first logs |
| **T-15 min** | Run every verification command in the pre-flight sections; wake demo 06's database | Catch expired logins, quota errors and paused databases while you can still fix them |
| **End of day** | `./scripts/destroy-all.sh` | See cost note below |

---

## Conventions

**Naming.** Every stack takes `prefix` (default `azpre`) and generates a random
6-character suffix, so you can deploy the same demo twice — one rehearsal copy,
one live copy — without collisions.

**Tagging.** Every resource is tagged `Environment`, `Workload`, `Demo` and
`CostCenter`. That's not decoration: demo 01's Modify policy inherits `CostCenter`
from the resource group, and it's how you find leftovers in Cost Analysis:

```bash
az resource list --tag Workload=AzurePrecon -o table
```

**No secrets in the repo.** `terraform.tfvars` is gitignored;
`terraform.tfvars.example` is the committed template. Nothing in these stacks
requires you to supply a password, key or connection string — where a credential
would normally go, there's a managed identity and a role assignment instead. That
is on purpose and it is worth saying out loud on stage. Demo 06 takes it one step
further: the SQL server has no SQL logins at all.

**State is local.** Each stack keeps `terraform.tfstate` in its own directory,
which is right for a throwaway demo and wrong for anything else. If somebody asks
— and somebody always asks — the production answer is a remote backend with state
locking, and that's a good 30-second detour into the Operational Excellence pillar.

---

## Cost

Everything defaults to the cheapest thing that still demonstrates the point.

| Demo | Idle cost | Notes |
|---|---|---|
| 01 — Policy | ~$0 | Two empty storage accounts; policy itself is free |
| 02 — VNet Peering | ~$1/day | 3 × B2ats_v2 VMs. **+$4.50/day** each for the optional VPN gateway and Bastion |
| 03 — Key Vault | ~$0 | Vault operations are ~$0.03 per 10,000 |
| 04 — Function App | ~$0 | Flex Consumption scales to zero. `always_ready_instance_count = 1` costs ~$0.30/day |
| 05 — Logic App | ~$0 | Billed per action execution, ~$0.000025 each |
| 06 — Azure SQL | ~$0.50/day | Serverless database pauses when idle; private endpoint ~$0.24/day. **Delete the restored copy** after the demo |
| 07 — Observability | ~$0 | Log alert ~$1.50/month prorated; ingestion is kilobytes |

**All seven, defaults, one day: under $5.** The things that actually cost money
are the VPN gateway and Bastion in demo 02 — both off by default — and anything
left running in demo 06, including a restored database you forgot about.

---

## Teardown

```bash
cd demos
./scripts/destroy-all.sh          # prompts; type DESTROY to confirm
```

Per stack:

```bash
terraform -chdir=demos/02-vnet-peering/terraform destroy
```

Known slow or sharp edges:

- A **VPN gateway** takes 10–20 minutes to delete. Start early.
- **Key Vault purge protection** is `false` in demos 03 and 07 for exactly this
  reason — with it on, a destroyed vault occupies its name for the full 7-day
  retention window. Production should still have it on.
- Demo 06's **restored database** isn't in Terraform state. It's deleted with the
  server, but deleting it first is cleaner.
- Anything you created **by hand in the portal** during a demo isn't in Terraform
  state and will block `destroy` on a non-empty resource group. Delete it first.

---

## A note on scope

These seven stacks cover the seven slides in the deck that are explicitly marked
**Demonstration**. Several other slides are demo-able but aren't scripted here,
because they need tenant-level configuration rather than deployable infrastructure
— Conditional Access, PIM activation, Entra ID Access Reviews and workload identity
federation all change tenant or repo state that you probably don't want a
`terraform apply` touching before a live session. If you want any of those as
scripted demos, they're worth building against a dedicated demo tenant rather than
this repo's pattern.
