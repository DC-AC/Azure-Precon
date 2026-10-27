# Azure: From Admin to Architect — 2026 Edition

A full-day preconference session that reframes Azure infrastructure knowledge
through the **Azure Well-Architected Framework**, Zero Trust, and infrastructure
as code — plus deployable Terraform and run-of-show scripts for every live demo
in the deck.

The premise: an admin keeps services running, an architect makes deliberate
trade-offs across competing priorities. Every topic in the deck is presented as a
decision with a cost, not a feature with a checkbox.

**Audience:** experienced Azure and Windows/SQL administrators moving into
architecture or platform roles.
**Format:** 80 slides across 10 sections, with 7 scripted live demos — about
6½ hours of material for an 8:30–4:30 day.

---

## Repository layout

| Path | What it is |
|---|---|
| [slides.md](slides.md) | The deck — every slide, in delivery order, as speaker-ready bullets |
| [demos/](demos/) | Terraform + run-of-show scripts for the seven **Demonstration** slides |
| [demos/README.md](demos/README.md) | Demo index: slide map, prerequisites, blast radius, precon-day schedule, cost |

---

## The deck

[slides.md](slides.md) is the source of truth. It is written as bullets you speak
from, not sentences you read aloud.

| Section | Slides | What it covers |
|---|---|---|
| **Opening & Framing** | 6 | The mindset shift, the five WAF pillars as the language of trade-offs, why lift-and-shift carries on-prem assumptions forward, shared responsibility, and IaC (with Azure Verified Modules) as the architect's default |
| **1 — Reliability, High Availability & Recovery** | 7 | Start from RTO/RPO, not from redundancy. Availability Zones as the modern default, scale sets, a multi-region reality check, ransomware-proof backup, Site Recovery, and testing the failure with Chaos Studio |
| **2 — Azure SQL & Data Platform** | 11 | Deployment models, Hyperscale, serverless vs. provisioned, Managed Instance security posture, HA tiers, restore as the real test, PostgreSQL/MySQL Flexible Server, Cosmos DB, vectors in Azure SQL, Synapse vs. Fabric — and a demo |
| **3 — Governance** | 11 | Management group hierarchy, Azure landing zones, tagging, RBAC, PIM and just-in-time access, access reviews, and Azure Policy as compliance-as-code |
| **4 — Networking & Network Security** | 12 | Zero Trust framing (identity is the perimeter), explicit outbound now that new VNets are private by default, private endpoints and Network Security Perimeter, hub-and-spoke, load balancing, WAF, Firewall, NSGs/ASGs, and Bastion |
| **5 — Virtual Machines & Storage** | 7 | The architect's VM checklist, sizing and retirements, the compute + storage cost model, Premium SSD v2 for SQL, encryption at host, and moving storage access past keys and SAS |
| **6 — Identity, Secrets & Security Posture** | 9 | Entra ID as the control plane, Conditional Access, mandatory MFA for Azure, External ID, managed identities, workload identity federation, Key Vault, and Defender for Cloud |
| **7 — Automation & Serverless** | 6 | Runbooks and runtime environments, Azure Functions on Flex Consumption, and Logic Apps Consumption vs. Standard |
| **8 — Operations: Observability & Cost** | 8 | Azure Monitor, workspace design and table plans, diagnostics by policy, alerts that wake the right person, OpenTelemetry, budgets, and FinOps |
| **Closing** | 3 | The same rules for AI workloads, the architect's WAF checklist, and three things to do on Monday |

### Suggested day

| Time | Block | Demo |
|---|---|---|
| 8:30 | Opening & Framing | |
| 9:00 | 1 — Reliability, High Availability & Recovery | |
| 9:30 | 2 — Azure SQL & Data Platform | 06 |
| 10:30 | *Break* | |
| 10:45 | 3 — Governance | 01 |
| 11:35 | 4 — Networking & Network Security | 02 |
| 12:30 | *Lunch* | |
| 1:30 | 5 — Virtual Machines & Storage | |
| 2:00 | 6 — Identity, Secrets & Security Posture | 03 |
| 2:45 | *Break* | |
| 3:00 | 7 — Automation & Serverless | 04, 05 |
| 3:40 | 8 — Operations: Observability & Cost | 07 |
| 4:20 | Closing, Q&A | |

The timings assume about 3½ minutes a slide plus questions. If you run long, the
cheapest cuts are demo 05 and the Front Door, Firewall and storage-services slides.
None of them carries a through-line.

### Through-lines

Four ideas recur deliberately, so the room hears them more than once in different
contexts:

- **Identity is the perimeter.** Conditional Access, PIM, managed identities and
  Entra-ID-first data access appear in governance, networking, storage, SQL and
  automation — not just in the identity section.
- **Trade-offs are the job.** Every recommendation is paired with what it costs:
  multi-region vs. the outage it prevents, always-ready instances vs. cold start,
  reservations vs. flexibility, `allLogs` vs. `audit`.
- **IaC makes it reviewable.** Click-ops isn't wrong because it's slow; it's wrong
  because there's no diff, no author, and no revert.
- **Test the thing you're relying on.** Untested DR is a hope. An unassigned
  policy is a document. A certificate you renew by hand is an outage with a date on
  it. A restore you've never timed is an RTO you made up.

### What's new in the 2026 edition

If you have delivered an earlier version of this session, these are the
substantive changes:

- **Promoted** identity and Zero Trust to a through-line rather than one section
- **Added** Infrastructure as Code, Azure landing zones, Savings Plans, Azure
  Front Door, and a multi-region reliability reminder
- **Rewrote** the storage security story away from account keys and ad-hoc SAS
  toward Entra ID auth, user-delegation SAS and private endpoints
- **Retired** the classic subscription administrator roles and the
  Availability-Sets-first framing; replaced static admin slides with PIM
- **Reframed** Synapse around Microsoft Fabric as the roadmap for new analytics work
- **Consolidated** four HA slides and several repetitive admin-role slides

The October 2026 refresh added:

- **A new Section 8 — Operations: Observability & Cost**, and demo 07 to go with it
- **Backup, Site Recovery and failure testing** in Section 1; **restore-as-the-test,
  vectors and Fabric mirroring** in Section 2, with demo 06
- **Mandatory MFA, workload identity federation and Defender for Cloud** in Section 6
- **Explicit outbound** as its own slide, now that new VNets are private by default
- **Current-state corrections:** Hyperscale at 128 TB; Single Server retired;
  `caf-enterprise-scale` archived in favour of Azure Verified Modules; Basic Load
  Balancer and App Gateway v1 retired; Azure Disk Encryption retiring in favour of
  encryption at host; B2C closed to new customers; Key Vault RBAC as the default;
  retired Automation runtimes; Linux Consumption retiring in favour of Flex Consumption
- **Demo 02 now deploys an AZ VPN gateway SKU.** Non-AZ SKUs can no longer be created

---

## The demos

Seven live demos, one per **Demonstration** slide. Each is a self-contained
Terraform stack with its own state, resource group and teardown — deploy one, all
seven, or whatever your timing allows.

| # | Demo | Deck slide | What it proves |
|---|---|---|---|
| 06 | [Azure SQL, Locked Down](demos/06-azure-sql-private/) | Section 2 | No SQL password, no public address, and the app still works — plus an RTO you measured instead of guessed |
| 01 | [Policy & Compliance](demos/01-policy-compliance/) | Section 3 | A Deny-capable policy running in report-only mode, showing exactly what it *would* have blocked before it blocks anything |
| 02 | [VNet Peering](demos/02-vnet-peering/) | Section 4 | Hub-and-spoke connectivity works, spoke-to-spoke doesn't — peering is non-transitive, and you watch the ping fail |
| 03 | [Key Vault Cert Rotation](demos/03-keyvault-cert-rotation/) | Section 6 | A certificate that renews itself, issues a fresh key pair, and raises an event nobody has to watch for |
| 04 | [Function App](demos/04-function-app/) | Section 7 | Open the app settings blade and try to find the storage connection string. There isn't one |
| 05 | [Logic App Workflow](demos/05-logic-app/) | Section 7 | Low-code is not un-architected: the workflow is deployed from Terraform and the business rule is a reviewable diff |
| 07 | [Observability & Cost Guardrails](demos/07-observability-alerts/) | Section 8 | A vault that was logging from birth because policy said so, an alert on your phone, and a budget routed to the same people |

Every demo README follows the same structure — the one takeaway, what the
Terraform builds and *why* each choice is what it is, pre-flight steps with
timings, numbered beats with talk track and exact commands, a symptom → cause →
fix table for when it breaks live, teardown, and approximate cost.

The stacks also reach back to non-demo slides for free: Bastion and VPN gateways
are flags on demo 02, managed identities appear in four different services
across demos 03–06, and every stack is an excuse to put a `.tf` file next to a
portal blade.

### Quick start

```bash
az login
az account set --subscription "<your-subscription-id>"

cd demos
./scripts/deploy-all.sh              # all seven
./scripts/deploy-all.sh 01 05        # or just the ones you need
```

Read [demos/README.md](demos/README.md) before a live session — it has the
day-before / T-60 / T-15 schedule, and the demos that need advance notice (a VPN
gateway takes 30–45 minutes to provision; the function apps' first code publish
does a slow remote build; demo 06's database needs a day of history to restore
from; demo 07's policy remediation needs 15–30 minutes).

### Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.6 | All demos |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | ≥ 2.60 | All demos |
| [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local) | v4 | Demos 04 and 06 |
| [go-sqlcmd](https://learn.microsoft.com/sql/tools/sqlcmd/go-sqlcmd-utility) | any recent | Demo 06 only |

An Azure subscription you can create resource groups in. Demos 03–07 create role
assignments scoped to resources they create, so those need `Owner` or
`User Access Administrator`; demos 01 and 02 do not.

### Safety and cost

The demo stacks are built to be safe to run in a subscription you share with
other people:

- **Nothing is scoped above its own resource group.** No subscription-level or
  management-group-level assignments, ever.
- **Only one stack enforces anything by default**, and only inside its own resource
  group: demo 07's DeployIfNotExists policy adds a diagnostic setting to Key Vaults
  in that resource group. Demo 01 assigns its initiative in `DoNotEnforce` mode with
  audit-only effects; Deny and Modify are separate opt-in switches.
- **Every role assignment is on a resource or resource group the same stack
  created**, and disappears with `terraform destroy`.
- **Under $5 for all seven stacks for a day** on defaults. The components that
  cost real money — a VPN gateway and Azure Bastion — are off by default.

See [Blast radius](demos/README.md#blast-radius) for a per-stack breakdown, and
run `./scripts/destroy-all.sh` when you're done.

---

## Using this material

The deck is plain markdown, so it renders anywhere and converts cleanly:

```bash
# Reveal.js / PowerPoint via pandoc
pandoc slides.md -t revealjs -s --slide-level=3 -o slides.html
pandoc slides.md --slide-level=3 -o slides.pptx
```

Slide breaks are `###` headings and section breaks are `##` headings — hence
`--slide-level=3`. Most markdown presentation tools will split it correctly given
the same hint.

If you fork this for your own delivery, the parts most worth adapting are the
`prefix` and `location` variables in each demo's `terraform.tfvars.example`, and
the talk track in each demo README — the commands will work as-is, but the
framing should sound like you.
