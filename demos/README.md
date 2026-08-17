# Demos — *Azure: From Admin to Architect (2026 Edition)*

Run-of-show scripts and Terraform for every **Demonstration** slide in
[`../slides.md`](../slides.md).

Each demo is a self-contained stack: its own Terraform state, its own resource
group, its own teardown. Nothing here depends on anything else here, so you can
deploy one, all five, or whatever survives your timing.

---

## Slide map

| # | Demo | Deck slide | Section | Live time |
|---|---|---|---|---|
| 01 | [Policy & Compliance](01-policy-compliance/) † | *Demonstration — Policy & Compliance* | 3 — Governance | 8–10 min |
| 02 | [VNet Peering](02-vnet-peering/) | *Demonstration — VNet Peering* | 4 — Networking | 10–12 min |
| 03 | [Key Vault Cert Auto-Rotation](03-keyvault-cert-rotation/) | *Demonstration — Certificate Auto-Rotation in Key Vault* | 6 — Identity & Secrets | 8–10 min |
| 04 | [Function App](04-function-app/) | *Demonstration — Create a Function App* | 7 — Automation & Serverless | 8–10 min |
| 05 | [Logic App Workflow](05-logic-app/) | *Demonstration — Logic App Workflow* | 7 — Automation & Serverless | 8–10 min |

† **Report-only.** Demo 01 assigns its initiative in `DoNotEnforce` mode with
audit-only effects and no managed identity, so it cannot block a deployment or
change a resource. Deny and Modify are separate opt-in switches — and *showing a
Deny policy report what it would have blocked* is the strongest beat in that
demo. See [Blast radius](#blast-radius).

### Slides these demos also cover for free

The stacks were built so you can reach back to earlier slides without deploying
anything extra:

| Slide | Where it shows up |
|---|---|
| *Infrastructure as Code — The Architect's Default* | Every demo. Open the `.tf` next to the portal blade — that comparison is the argument |
| *CAF Landing Zones* / *Management Groups* | Demo 01 — the assignment scope conversation |
| *NSGs & Application Security Groups* | Demo 02 — the NSG uses service tags, not CIDR lists |
| *Azure Bastion* | Demo 02 — set `deploy_bastion = true` |
| *Connectivity Options* (site-to-site, ExpressRoute) | Demo 02 — set `deploy_vpn_gateway = true` |
| *Managed Identities — Eliminate Credentials in Code* | Demos 03, 04, 05 — all three, three different services |
| *Securing Storage — Move Past Keys and SAS* | Demo 04 — find the connection string; there isn't one |
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
└── 05-logic-app/
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
| [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local) | v4 | Demo 04 only |
| `jq` | any | Nicer output in a few commands |

Provider versions are pinned in each stack's `.terraform.lock.hcl` — committed on
purpose, so the stack you rehearsed is the stack you present.

### Azure permissions

| Demo | Minimum role |
|---|---|
| 01 — Policy | `Resource Policy Contributor` + `Contributor` (defaults create no role assignment). **Owner**/UAA only if you opt into `enable_remediation` |
| 02 — VNet Peering | `Contributor` |
| 03 — Key Vault | **Owner** or `User Access Administrator` (Terraform grants itself Key Vault Administrator) |
| 04 — Function App | **Owner** or `User Access Administrator` (four role assignments) |
| 05 — Logic App | `Contributor`, or **Owner** if `enable_queue_target = true` |

> Anything that creates a **role assignment** needs `User Access Administrator` or
> `Owner`. Plain `Contributor` will get most of the way through an apply and then
> fail — which is itself a decent aside for the RBAC slide, but not one you want
> to discover ten minutes before you go on.

---

## Blast radius

Nothing here reaches outside its own resource group, and nothing enforces or
mutates by default. Worth knowing before you point any of it at a subscription
you share with other people.

| Demo | What it can affect | Can it block or change anything? |
|---|---|---|
| 01 — Policy | Its own resource group | **No.** Report-only: assignment is `DoNotEnforce`, effects are `Audit`, and no managed identity or role assignment is created. Deny and Modify are separate opt-ins |
| 02 — VNet Peering | Its own VNets, NSGs and VMs | No. NSG rules apply only to the subnets this stack creates |
| 03 — Key Vault | Its own vault | Role assignments are scoped to the vault it created — one for you, one for a demo identity |
| 04 — Function App | Its own storage account | Role assignments are scoped to the storage account it created |
| 05 — Logic App | Its own storage account | One role assignment, scoped to the storage account it created |

Demo 01 is the only stack that could affect resources it didn't create, which is
why it ships with three independent safety switches. Check what you deployed:

```bash
terraform -chdir=01-policy-compliance/terraform output mode
# => REPORT-ONLY — assigned at resource group scope in DoNotEnforce mode...
```

The other four create role assignments because a managed identity with a scoped
role is the *point* of those demos — that's the deck's "eliminate credentials in
code" story. Each grant is on a resource the same stack created and disappears
with `terraform destroy`.

---

## Quick start

```bash
az login
az account set --subscription "<your-subscription-id>"

cd demos
./scripts/deploy-all.sh              # all five
./scripts/deploy-all.sh 01 05        # or just the ones you need
```

Or one at a time, which is what the per-demo READMEs assume:

```bash
cd demos/01-policy-compliance/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

---

## Suggested schedule for a full-day precon

| When | Do this | Why |
|---|---|---|
| **Day before** | Demo 02 with `deploy_vpn_gateway = true` | A VPN gateway takes 30–45 minutes |
| **Day before** | Demo 04 `terraform apply` + `func publish` | First publish does a remote build; it's slow and boring |
| **Day before** | Rehearse each demo once, end to end | Every failure in the "if it breaks" tables is one somebody hit |
| **T-60 min** | Demos 01, 03, 05 `terraform apply` | All fast (1–3 min each) |
| **T-45 min** | `az policy state trigger-scan` for demo 01 | Compliance data takes minutes to appear, and the blade is empty without it |
| **T-15 min** | Run every verification command in the pre-flight sections | Catch expired logins and quota errors while you can still fix them |
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
is on purpose and it is worth saying out loud on stage.

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
| 02 — VNet Peering | ~$1/day | 3 × B1s VMs. **+$4.50/day** each for the optional VPN gateway and Bastion |
| 03 — Key Vault | ~$0 | Vault operations are ~$0.03 per 10,000 |
| 04 — Function App | ~$0 | Flex Consumption scales to zero. `always_ready_instance_count = 1` costs ~$0.30/day |
| 05 — Logic App | ~$0 | Billed per action execution, ~$0.000025 each |

**All five, defaults, one day: under $2.** The two things that actually cost money
are the VPN gateway and Bastion in demo 02 — both off by default, and both worth
turning off again the moment you're done.

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
- **Key Vault purge protection** is `false` in demo 03 for exactly this reason —
  with it on, a destroyed vault occupies its name for the full 7-day retention
  window. Production should still have it on.
- Anything you created **by hand in the portal** during a demo isn't in Terraform
  state and will block `destroy` on a non-empty resource group. Delete it first.

---

## A note on scope

These five stacks cover the five slides in the deck that are explicitly marked
**Demonstration**. Several other slides are demo-able but aren't scripted here,
because they need tenant-level configuration rather than deployable infrastructure
— Conditional Access, PIM activation, and Entra ID Access Reviews all change
tenant state that you probably don't want a `terraform apply` touching before a
live session. If you want any of those as scripted demos, they're worth building
against a dedicated demo tenant rather than this repo's pattern.
