# Demo 02 — VNet Peering & Hub-and-Spoke

**Deck slide:** *Demonstration — VNet Peering* (Section 4 — Networking & Network Security)

> - Configure peering, VPN gateway, gateway transit; confirm connectivity

**Runs after:** *VNet Peering & Hub-and-Spoke*
**Length:** 10–12 minutes live (plus pre-flight)
**WAF pillars on screen:** Security, Reliability, Operational Excellence

---

## The one thing they should leave with

> **Peering is non-transitive.** Spoke 1 talks to the hub. Spoke 2 talks to the hub.
> Spoke 1 does **not** talk to spoke 2 — and no amount of "but they're both peered"
> changes that. Every route you want, you build.

The stack ships with spoke-to-spoke peering **off**. You demonstrate the failure,
then fix it live.

---

## Topology

```
              (optional)                       (optional)
            VPN Gateway  ─┐               ┌─ Azure Bastion
                          │               │
                    ┌─────┴───────────────┴─────┐
                    │  vnet-hub   10.0.0.0/16   │
                    │  GatewaySubnet            │
                    │  AzureBastionSubnet       │
                    │  snet-workload  + vm-hub  │
                    └──────┬──────────────┬─────┘
            peering (x2)   │              │   peering (x2)
                    ┌──────┴─────┐  ┌─────┴──────┐
                    │ vnet-spoke1│  │ vnet-spoke2│
                    │ 10.1.0.0/16│  │ 10.2.0.0/16│
                    │  vm-spoke1 │  │  vm-spoke2 │
                    └──────╥─────┘  └─────╥──────┘
                           ╚══ NOT peered ═╝
```

Three Ubuntu VMs, **none with a public IP**. Connectivity is proved with
`az vm run-command`, which needs no inbound access at all — which is itself a
nice aside for the Bastion slide.

---

## What the Terraform builds

| Resource | Notes |
|---|---|
| `vnet-hub` + `GatewaySubnet`, `AzureBastionSubnet`, `snet-workload` | Those two subnet names are fixed by Azure |
| `vnet-spoke1`, `vnet-spoke2` + workload subnets | Non-overlapping /16s |
| 4 peering resources (hub↔spoke1, hub↔spoke2) | **Two per link** — peering is reciprocal |
| 2 more peerings, gated by `enable_spoke_to_spoke_peering` | The live fix |
| NSG using **service tags** (`VirtualNetwork`, `Internet`) | Not hand-maintained CIDR lists |
| 3 × `Standard_B2ats_v2` Ubuntu VMs, no public IPs | Connectivity proof |
| VPN gateway (`VpnGw1AZ`) + zone-redundant public IP | **Optional** — `deploy_vpn_gateway`. Must be an AZ SKU: non-AZ SKUs can no longer be created |
| Azure Bastion + public IP | **Optional** — `deploy_bastion` |

### Optional pieces, and why they're optional

| Flag | Default | Cost / time | When to turn it on |
|---|---|---|---|
| `deploy_vpn_gateway` | `false` | ~$0.19/hr, **30–45 min to provision** | You want gateway transit live. Deploy the day before. |
| `deploy_bastion` | `false` | ~$0.19/hr | You're also covering the *Azure Bastion* slide from this stack. |
| `enable_spoke_to_spoke_peering` | `false` | free | Only on stage, as the fix. |

When `deploy_vpn_gateway = true`, the hub-side peerings get `allow_gateway_transit`
and the spoke-side peerings get `use_remote_gateways` — that pairing *is* gateway
transit, and it's worth putting the two lines side by side on screen.

---

## Pre-flight

```bash
cd demos/02-vnet-peering/terraform
cp terraform.tfvars.example terraform.tfvars

az login
az account set --subscription "<your-subscription-id>"

# Empty "Restrictions" column = the VM size is available to you in this region
az vm list-skus -l eastus2 --size Standard_B2ats_v2 -o table

terraform init
terraform apply          # ~4 minutes without the gateway
```

If you want gateway transit, do this the **day before**:

```bash
terraform apply -var 'deploy_vpn_gateway=true'   # 30-45 minutes
```

Sanity check before you walk on:

```bash
terraform output vm_private_ips
eval "$(terraform output -raw test_hub_to_spoke1)"     # expect 3 replies
```

**Requires:** `Contributor` on the subscription. No `Owner` needed for this one.

---

## Run of show

### 1. The shape on screen *(1 min)*

Portal → the demo resource group → **Resource visualizer**, or just the VNet list.

> "Hub-and-spoke. Shared services in the middle — that's where your firewall,
> your DNS, your gateways live — and workloads in their own blast radius on the
> outside. This is the standard enterprise topology and it is not an accident:
> it exists because peering has rules."

### 2. Peering is two resources, not one *(2 min)*

Portal → `vnet-hub` → **Peerings**. Show `peer-hub-to-spoke1`. Then go to
`vnet-spoke1` → **Peerings** and show `peer-spoke1-to-hub`.

> "Two resources. One link. Peering is reciprocal — if you only build one side,
> the state sits at `Initiated` and nothing flows. Half the peering tickets I've
> seen are somebody who built one direction and went to lunch."

Open [`terraform/main.tf`](terraform/main.tf) and show the two matching blocks.

> "In the portal that's two blades. In code it's two resources next to each
> other, and the reviewer can see the pair. That's the Operational Excellence
> argument for IaC in one screen."

### 3. Prove hub ↔ spoke works *(2 min)*

```bash
cd demos/02-vnet-peering/terraform
eval "$(terraform output -raw test_hub_to_spoke1)"
```

> "3 packets, 3 replies, across two virtual networks. Note what I did **not** do:
> no VPN, no public IP, no NAT. Peering puts them on the Microsoft backbone."

Show why, with the routing table Azure programmed for you:

```bash
eval "$(terraform output -raw effective_routes_command)"
```

Point at the row with source **`VNetPeering`**.

> "I never wrote a route. The platform wrote it when the peering came up. That's
> software-defined networking doing the thing the slide promised."

### 4. The failure — and this is the point *(3 min)*

```bash
eval "$(terraform output -raw test_spoke1_to_spoke2)"
```

100% packet loss.

> "Both spokes are peered to the hub. Both are healthy. And they cannot see each
> other. **Peering is non-transitive.** The hub does not forward between them just
> because it's in the middle — that would need something that actually routes."

Show the effective route table again and point out there's **no route** to
`10.2.0.0/16` from spoke 1. There's nothing to debug. The route was never there.

> "This is the trap in every lift-and-shift network design. On-prem, everything
> could reach everything because a router in the middle said so. Here, reachability
> is a thing you explicitly build — which is a security feature, not a bug."

### 5. Fix it live *(2 min)*

Two ways to fix it, and the choice is architectural:

| Option | When |
|---|---|
| Direct spoke-to-spoke peering | Few spokes, no inspection requirement |
| Route through Azure Firewall / NVA in the hub | You need centralised egress + inspection (see the *Azure Firewall* slide) |

Do the fast one on stage:

```bash
terraform apply -var 'enable_spoke_to_spoke_peering=true' -auto-approve
eval "$(terraform output -raw test_spoke1_to_spoke2)"     # now 3 replies
```

> "Thirty seconds, and I've created a mesh link. Now do that for twenty spokes.
> Twenty times nineteen, times two resources. **That's** why the answer at scale
> is a firewall in the hub with UDRs, or Virtual WAN — not a peering mesh."

### 6. Gateway transit *(2 min — only if `deploy_vpn_gateway = true`)*

Portal → `vnet-hub` → **Peerings** → `peer-hub-to-spoke1`. Show
**Allow gateway transit** ticked. Then `vnet-spoke1` → `peer-spoke1-to-hub`,
**Use remote gateway** ticked.

> "One VPN gateway. In the hub. Every spoke borrows it. You are not paying for,
> or operating, a gateway per workload VNet — and there is exactly one place your
> on-prem routes come from. That's the whole economic argument for hub-and-spoke."

If the gateway isn't deployed, show the same two lines in
[`terraform/main.tf`](terraform/main.tf) and say what they'd do — the code reads
as well as the blade does.

### 7. Optional Bastion tie-in *(1 min — if `deploy_bastion = true`)*

Portal → `vm-spoke1` → **Connect** → **Bastion**. Log in with:

```bash
terraform output vm_admin_username
terraform output -raw vm_admin_password
```

> "That VM has no public IP. Port 22 is not open to the internet. I'm on a shell
> anyway, over TLS, through the portal — and it's logged. Treat public 3389 or 22
> as a finding."

---

## If it breaks on stage

| Symptom | Cause | Fix |
|---|---|---|
| `run-command` returns nothing | VM agent still starting | Wait ~2 min after apply; test in pre-flight |
| Hub→spoke ping fails too | NSG association didn't apply | `az network nic list-effective-nsg` — check `AllowVnetInboundIcmp` |
| `use_remote_gateways` apply error | Gateway not fully provisioned | `depends_on` handles it; if it races, re-run `terraform apply` |
| Peering shows `Disconnected` | One side deleted/recreated | Re-apply — both directions must exist |
| Spoke-to-spoke still fails after the fix | Peering state still `Updating` | Give it ~30 seconds and re-run the ping |
| Gateway apply: SKU not allowed / not supported | A non-AZ SKU (`VpnGw1`) — creation blocked since Nov 2025 | Use `VpnGw1AZ` (the default); the variable validation should catch this first |
| VM apply: `SkuNotAvailable` | Size capacity-restricted in the region | `az vm list-skus -l <region> --size <size> -o table`, pick an unrestricted size, set `vm_size` |

---

## Teardown

```bash
cd demos/02-vnet-peering/terraform
terraform destroy
```

A VPN gateway takes **10–20 minutes to delete**. Start the destroy before lunch,
not while you're packing up.

---

## Approximate cost

| Component | ~USD/hour |
|---|---|
| 3 × B2ats_v2 VMs + Standard HDD OS disks | ~$0.04 |
| VNets, subnets, NSGs, peering (idle) | $0.00 |
| Peering data transfer | ~$0.01/GB each direction — negligible for pings |
| VPN gateway (VpnGw1AZ), optional | ~$0.19 |
| Azure Bastion (Basic), optional | ~$0.19 |

Base stack: well under **$1/day**. With both optional components: ~**$10/day**.
