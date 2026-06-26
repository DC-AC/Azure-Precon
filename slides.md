

# Azure: From Admin to Architect — 2026 Edition
*Reframed through the Azure Well-Architected Framework & Modern Security/Design*

---

## Opening & Framing

### Slide: From Admin to Architect — The Mindset Shift
- An admin keeps services running; an architect makes deliberate trade-offs across competing priorities
- The five WAF pillars — Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency — are the language of those trade-offs
- Every decision today gets weighed against the pillars, not against "what we did on-prem"

### Slide: The Problem with Lift-and-Shift (Reworked)
- Moving VMs as-is carries forward on-prem assumptions: snowflake servers, manual patching, over-permissioned access
- You pay cloud prices for on-prem architecture — worst of both on cost and operations
- Modernization is a spectrum: rehost → replatform → refactor; pick per workload against business value, not dogma

### Slide: What Architecture Is Actually For
- Translating business requirements (RTO/RPO, compliance, budget, scale) into technical design
- Making trade-offs explicit and reviewable, not implicit and accidental
- Use the Azure Well-Architected Review and Azure Advisor to score and prioritize — architecture as a continuous practice

### Slide: Shared Responsibility — Know Where Your Job Starts (Reworked)
- IaaS, PaaS, SaaS shift different amounts of burden to Microsoft
- **You always own** data, identity & access, and configuration — regardless of model
- "Trust but verify" the provider; most cloud breaches trace to customer-side misconfiguration, not platform failure

### Slide: The Cloud Value Proposition Through WAF (Reworked)
- **IaaS:** elastic compute/storage, higher baseline availability, software-defined networking enabling automation
- **PaaS:** built-in HA, platform backups, automated patching, evergreen versions — DR often costs extra
- WAF lens: PaaS advances Operational Excellence and Reliability, but you still validate DR and govern cost

### Slide: Infrastructure as Code — The Architect's Default (New)
- Click-ops doesn't scale and isn't reviewable — define infrastructure in **Bicep / Terraform**, version it in Git
- Deploy through pipelines with policy checks; treat environments as reproducible, not hand-built
- IaC underpins Operational Excellence and makes security/compliance enforceable by default

---

## Section 1 — Reliability & High Availability

### Slide: Designing for Reliability — Start with the Targets
- Define RTO and RPO per workload *first* — redundancy is a means, not a goal
- Map targets to Azure constructs: availability zones, regions, paired regions
- Reliability pillar: redundancy, failure-mode analysis, and **tested** recovery — untested DR is a hope, not a plan

### Slide: Availability Zones over Availability Sets (Reworked)
- **Availability Zones** are now the default for VM resilience — physically separate datacenters, higher SLA than sets
- Availability Sets (fault/update domains) still exist but are the legacy single-datacenter option
- Pair zones with zone-redundant load balancing and storage for true datacenter-failure survival

### Slide: Virtual Machine Scale Sets
- Identically configured, load-balanced VMs with manual, scheduled, and autoscale options
- Auto-distributes across fault and update domains; flexible orchestration mode is now standard
- Performance Efficiency: scale to real demand with clear thresholds, not fixed over-provisioning

### Slide: A 2026 Reliability Reminder (New)
- Regional incidents still happen — single-region designs carry single-region risk
- For mission-critical workloads, plan multi-region geodiversity, not just multi-zone
- Decide consciously: the cost of multi-region vs. the cost of the outage it prevents

---

## Section 2 — Azure SQL & Data Platform

### Slide: Azure SQL — Deployment Models
- Single database, elastic pool, managed instance — different isolation and consolidation profiles
- Elastic pools optimize cost across many databases with uneven, intermittent usage
- Managed Instance gives near-100% on-prem compatibility for lift-and-shift modernization

### Slide: Hyperscale — Scaling Without Re-architecting
- Auto-scales storage to 100TB with rapid, independent compute/storage scaling
- Fast backups/restores and near-instant scale operations regardless of data size
- Read-scale-out replicas double as hot standbys — serves both Performance Efficiency and Reliability

### Slide: Serverless vs. Provisioned Compute
- **Serverless:** auto-pause/resume, per-second billing — best for intermittent single-DB workloads
- **Provisioned:** uniform utilization, reserved capacity, hourly billing, Azure Hybrid Benefit eligibility
- Decision driver is workload shape and cost optimization, not feature count

### Slide: Azure SQL Managed Instance — Security Posture (Reworked)
- Native VNet integration with private IPs — no public surface by default
- Entra-ID-only authentication, Always Encrypted, TDE with customer-managed keys, Defender for SQL
- Full instance-level compatibility eases migration without sacrificing isolation

### Slide: HA in Azure SQL (Consolidated from 4 slides)
- Standard model separates compute/storage; premium/business-critical uses a local replica cluster for lowest latency
- Hyperscale uses page servers + log service for fast recovery at scale
- **Zone-redundant** config survives datacenter-level failure within a region
- Reliability: pick tier + zone/geo redundancy to meet stated RTO/RPO; test failover

### Slide: Azure DB for PostgreSQL & MySQL
- Flexible Server with zone-redundant HA, read replicas, burstable-to-business-critical tiers
- Entra ID auth, TLS enforcement, private access, Defender threat protection
- Encryption at rest with customer-managed keys

### Slide: Cosmos DB — Globally Distributed by Design
- Multi-region writes, tunable consistency, multiple APIs (SQL, Mongo, Cassandra, Gremlin, Table)
- RU-based throughput — performance and cost are the same dial; size it deliberately
- Performance Efficiency: pick the consistency level that meets correctness needs at lowest latency/cost

### Slide: Where Synapse Fits Now (Reworked)
- The old "what's not suitable for Synapse" framing still holds — it's not for OLTP, singleton selects, or row-by-row work
- But new analytics investment now defaults to **Microsoft Fabric**; Synapse remains supported, not the roadmap
- For an admin-to-architect audience: don't start new analytics builds on Synapse

---

## Section 3 — Governance (The Boring-but-Critical Part)

### Slide: Governance Is a Pillar, Not Paperwork (Reworked)
- Management groups → subscriptions → resource groups give you scope for policy, budgets, and access
- Governance enables both Cost Optimization (budgets, chargeback) and Security (guardrails)
- Design the hierarchy intentionally — it's hard to restructure later

### Slide: Cloud Adoption Framework Landing Zones (New)
- Don't hand-build subscriptions — start from **CAF enterprise-scale landing zones**
- Landing zones bake in identity, networking, policy, and management baselines from day one
- Architect's job: adopt the pattern, then tailor — not reinvent governance per project

### Slide: Resource Groups & Organization
- Logical grouping tied to lifecycle; can't be nested; each resource belongs to exactly one
- Organize for authorization, lifecycle, and billing — consistent naming and tagging are non-negotiable
- Tags drive cost reporting, automation, and ownership — enforce them via policy

### Slide: Management Groups
- Scope above subscriptions for policy and budget targeting with inheritance
- Compliance and cost reporting aligned to org structure (business units, teams)
- Keep the hierarchy shallow and purposeful

### Slide: Subscriptions, Limits & Quotas
- Limits (quotas) apply at subscription and sometimes regional level
- Raise soft limits via support request at no charge; design around hard limits
- Architect for quota headroom before you hit it in production

### Slide: RBAC — Identity as the Control Plane (Reworked)
- Fine-grained, identity-based access built on Azure Resource Manager: security principal + role + scope
- Grant **least privilege**; segregate duties; prefer built-in roles, create custom only when needed
- Deny assignments take precedence — use sparingly and deliberately

### Slide: Retire Classic Admin Roles (Reworked)
- Classic subscription administrator roles (Account/Service/Co-Administrator) are legacy — **fully retired in 2024**
- Use Azure RBAC roles (Owner, Contributor, Reader, User Access Administrator) and Entra ID roles instead
- If you still see Co-Administrators, that's technical debt to clean up

### Slide: Privileged Identity Management — Just-in-Time Access (New, replaces static admin slides)
- Standing admin access is a liability — **PIM** grants elevated roles just-in-time, time-boxed, with approval
- Require MFA and justification for activation; auto-expire and audit every elevation
- Core Zero Trust practice: no permanent privilege, verify every escalation

### Slide: Entra ID Access Reviews
- Periodic certification that access is still needed — for groups, app assignments, and privileged roles
- Reviewers: specified users, group owners, or self-review; surfaced via the access panel / portal
- Closes the loop on access creep — pairs with PIM and least privilege

### Slide: Azure Policy — Compliance as Code
- Policy differs from RBAC: RBAC controls *who can act*, Policy controls *what's allowed to exist*
- Define → assign to scope → evaluate compliance; group into initiatives for whole-estate guardrails
- Import from GitHub or write custom JSON; enforce locations, SKUs, tags, encryption — automatically

### Slide: Demonstration — Policy & Compliance
- Assign a policy / initiative
- View non-compliant resources and remediate

---

## Section 4 — Networking & Network Security

### Slide: Network Design Through a Zero Trust Lens (Reworked framing)
- VNets, subnets, and address spaces are the foundation — plan non-overlapping ranges, secure subnets with NSGs
- But the perimeter is no longer the network — **identity is the perimeter**; network controls *where*, identity controls *who*
- Layer both: private connectivity + identity-based access = defense in depth

### Slide: Connectivity Options
- To internet: outbound allowed by default; inbound via public IP or load balancer (minimize public exposure)
- Between Azure resources: VNet, service/private endpoints, VNet peering
- To on-prem: point-to-site, site-to-site VPN, ExpressRoute

### Slide: Private Endpoints over Service Endpoints over Public (Reworked)
- **Private Link / private endpoints** are the modern default — the service joins your VNet, traffic stays on the Microsoft backbone, public IP eliminated
- Service endpoints are the older, coarser option; public access should be disabled wherever possible
- This is the single highest-leverage data-plane security move for PaaS

### Slide: VNet Peering & Hub-and-Spoke
- Peering is non-transitive; reciprocal connections required; cross-subscription supported
- Global peering connects regions; gateway transit enables hub-and-spoke shared connectivity
- Hub-and-spoke centralizes shared services (firewall, DNS, gateways) — the standard enterprise topology

### Slide: Demonstration — VNet Peering
- Configure peering, VPN gateway, gateway transit; confirm connectivity

### Slide: Load Balancing — Pick the Right Layer
- **Azure Load Balancer** (L4): source/destination IP, port, protocol — zone-redundant for resilience
- **Application Gateway** (L7): path-based and multi-site routing, redirection, header rewrite
- Match the tool to the traffic; combine with zones for HA

### Slide: Application Gateway + WAF
- Components: frontend IP, listeners, routing rules, backend pools, health probes
- **Web Application Firewall** protects against OWASP Top 10 — enable it on Application Gateway and Front Door
- Run WAF in prevention mode in production, not just detection

### Slide: Azure Front Door & Traffic Manager (Reworked)
- **Traffic Manager** (DNS-based): priority, performance, geographic, weighted routing with health checks
- **Front Door** adds global L7 acceleration, WAF, and TLS offload at the edge — often the better modern choice for web apps
- Choose by need: DNS-level failover vs. full edge delivery + security

### Slide: Azure Firewall
- Built-in HA, availability zones, cloud-scale; FQDN and network filtering rules; threat intelligence
- Centralize in the hub for hub-and-spoke egress control
- Pair with Firewall Manager and DNS proxy for policy at scale

### Slide: NSGs & Application Security Groups
- NSGs filter subnet/NIC traffic; **service tags** simplify rules (Storage, SQL, AzureLoadBalancer, etc.)
- **ASGs** scope rules to logical groups of resources instead of IP ranges — far more maintainable
- Layer NSGs (network) under identity and Firewall (centralized) for defense in depth

### Slide: Azure Bastion — Kill the Public RDP/SSH Surface (Reworked)
- RDP/SSH directly in the portal over TLS — **no public IP on the VM**, no internet-exposed management ports
- Protection against port scanning and management-plane exposure
- This eliminates one of the most-attacked surfaces in IaaS; treat public 3389/22 as a finding

---

## Section 5 — Virtual Machines & Storage

### Slide: VM Deployment Checklist — Architect's Version
- Start with the network and security (subnets, NSGs, no public IP by default)
- Right-size deliberately (general/compute/memory/storage/GPU/HPC); name and tag per convention
- Choose managed disks, plan storage tier, select OS — and understand the pricing model before deploying

### Slide: VM Sizing — Match the Workload
- Families map to workload shape: general-purpose, compute-, memory-, storage-optimized, GPU, HPC
- GPU families now matter for AI training/inference, not just rendering
- Performance Efficiency: size to observed demand, then revisit — don't guess high "to be safe"

### Slide: VM Cost Model — Compute + Storage (Reworked)
- Two costs per VM: compute and storage
- Compute payment options: pay-as-you-go, **Reserved Instances**, and **Savings Plans** (flexible across instance types)
- Cost Optimization: combine reservations/savings plans for the steady floor, PAYG for the variable peak; add Hybrid Benefit

### Slide: Managed Disks & SQL Storage Best Practices
- Disk tiers: Standard HDD, Standard SSD, Premium SSD, Ultra — SQL belongs on Premium or Ultra
- Separate data and log volumes; enable read caching on data; stripe for IOPS; enable Instant File Initialization
- Temporary disk is ephemeral — only for TempDB and other recreatable data

### Slide: Encryption & Disk Security (Reworked)
- Encryption at rest is on by default; use **customer-managed keys** in Key Vault for sensitive workloads
- Consider Azure Disk Encryption / encryption-at-host for defense in depth
- Confidential computing options exist for data-in-use protection on sensitive workloads

### Slide: Azure Storage — Services & Account Types
- One account groups Blob, File, Queue, Table; choose GPv2 as the modern default
- Redundancy: LRS, ZRS, GRS, GZRS — map to your durability and residency requirements
- Blob tiers (Hot/Cool/Cold/Archive) + lifecycle management automate cost optimization

### Slide: Securing Storage — Move Past Keys and SAS (Reworked, important)
- **Default to Entra ID authentication** for data-plane access — not account keys, not ad-hoc SAS
- Account keys grant full access and are hard to govern — **disable shared-key access** where possible
- If SAS is required, prefer **user-delegation SAS** (Entra-backed), scope tightly (time, IP, permission), and disable public blob access
- Use private endpoints + firewall on storage; treat public storage exposure as a finding

---

## Section 6 — Identity & Secrets

### Slide: Entra ID — The Identity Foundation (Reworked, de-duplicated)
- Cloud identity and access management: SSO, MFA, conditional access, device registration, monitoring
- "Azure AD" is now **Microsoft Entra ID** — same backbone, current name; update your mental model and docs
- Identity is the control plane for everything else in this deck

### Slide: Conditional Access — The Zero Trust Gate (New)
- Verify explicitly: evaluate identity, device compliance, location, and risk on every access request
- Enforce MFA, block legacy auth, require compliant devices — different thresholds for different data
- This is where "assume breach" becomes concrete policy

### Slide: Users, Groups & External Identities
- Cloud, directory-synced, and guest identities; security vs. Microsoft 365 groups; assigned vs. dynamic membership
- **B2B** lets partners use their own credentials — no external account management for you
- **B2C / External ID** handles customer-facing identity with standards-based auth (OIDC, OAuth2, SAML)

### Slide: Managed Identities — Eliminate Credentials in Code (Reworked)
- Combine Entra ID auth with RBAC so apps authenticate **without stored secrets**
- System-assigned (tied to one resource) vs. user-assigned (shared across resources)
- Default pattern for service-to-service auth — no keys to rotate, nothing to leak

### Slide: Azure Key Vault — Secrets, Keys, Certificates
- Centralized, access-controlled storage for secrets, keys, and certificates; HSM-backed options
- Grant access at narrow scope via RBAC; enable soft-delete and purge protection
- Pair with managed identities so apps retrieve secrets without ever holding credentials

### Slide: Demonstration — Certificate Auto-Rotation in Key Vault
- Configure automated certificate rotation to remove manual renewal risk

---

## Section 7 — Automation & Serverless

### Slide: Automation Is the Architect's Force Multiplier (Reworked)
- Manual tasks don't scale and aren't auditable — automate, then govern the automation
- Azure Automation Runbooks for operational tasks; pair with managed identities, not stored credentials
- Operational Excellence: codify runbooks, observability, and on-call practice

### Slide: Azure Automation Runbooks
- PowerShell, PowerShell Workflow, and Python runbooks; graphical authoring available
- Run in an Azure sandbox or on a Hybrid Runbook Worker for on-prem/local resources
- Source from the gallery or your own repo; trigger via portal, PowerShell, or schedule

### Slide: Azure Functions — Event-Driven Compute
- Trigger on HTTP, timers, queues, blobs, Event Grid, Event Hubs, Service Bus, Cosmos DB changes
- Hosting: Consumption, Premium, Dedicated, and Flex Consumption; KEDA for self-hosted Kubernetes
- Durable Functions add stateful orchestration; pay-per-use aligns cost to actual execution

### Slide: Demonstration — Create a Function App
- Create and verify a function app

### Slide: Azure Logic Apps — Workflow Orchestration
- Schedule, automate, and orchestrate across apps, data, and services with low-code workflows
- Trigger-driven: an event fires, the engine runs the action sequence
- Hundreds of connectors plus custom connectors; graphical designer for building and maintaining flows

### Slide: Demonstration — Logic App Workflow
- Create a logic app, add a trigger, run it

---

## Closing

### Slide: The Architect's WAF Checklist
- **Reliability:** RTO/RPO defined, zones/regions chosen to match, recovery tested
- **Security:** Zero Trust, identity-as-perimeter, private endpoints, no standing privilege, encryption with CMK
- **Cost Optimization:** reservations + savings plans, tagging/chargeback, lifecycle + budgets with alerts
- **Operational Excellence:** IaC (Bicep/Terraform), pipelines, runbooks, observability
- **Performance Efficiency:** right-size to real demand, match service to workload, scale on thresholds

### Slide: From Admin to Architect — Where to Start Monday
- Run an Azure Well-Architected Review on one real workload — score, don't guess
- Pick the three highest-risk gaps (often: public exposure, standing admin, untested DR) and close them
- Move one manual process to IaC or automation — build the habit, then scale it

---

A note on the biggest substantive changes: I promoted **identity and Zero Trust** to a through-line (Conditional Access, PIM, managed identities, Entra-ID-first data access), modernized the **storage security** story away from keys/SAS toward Entra ID and private endpoints, **retired the classic admin-role and Availability-Set-first** framing, added **IaC, CAF landing zones, Savings Plans, Front Door, and a 2026 reliability/multi-region reminder**, and reframed Synapse around Fabric. I consolidated the four HA slides and the repetitive admin-role slides to tighten the flow.

Want this as a downloadable markdown file or a Word doc you can mark up?
