# Demo 01 — Policy & Compliance

**Deck slide:** *Demonstration — Policy & Compliance* (Section 3 — Governance)

> - Assign a policy / initiative
> - View non-compliant resources and remediate

**Runs after:** *Azure Policy — Compliance as Code*
**Length:** 8–10 minutes live (plus pre-flight)
**WAF pillars on screen:** Security, Cost Optimization, Operational Excellence

---

## ⚠️ This stack is report-only by default

As shipped it **cannot block a deployment and cannot change a resource**:

| Control | Default | Effect |
|---|---|---|
| `enforce_policies` | `false` | Assignment runs in **DoNotEnforce**. Compliance is evaluated and reported; Deny and Modify effects do not fire |
| `enable_remediation` | `false` | No Modify policy, **no managed identity, no role assignment** — nothing exists that could write to a resource |
| `audit_effect` | `Audit` | The custom policies report; they don't deny |
| Assignment scope | this stack's own resource group | Never a subscription, never a management group |

Set `create_policy_assignment = false` to go further: the definitions and the
initiative are created, but **attached to no scope at all**.

> A policy *definition* is inert. It changes nothing until it is assigned to a
> scope. That's worth saying out loud on stage — it's exactly why the definitions
> here are unconditional and the assignment isn't.

---

## The one thing they should leave with

> **RBAC controls who can act. Policy controls what is allowed to exist.**
> And you never have to guess what a guardrail will break: run it in DoNotEnforce
> mode first and Azure will show you every resource it *would* have blocked,
> before it blocks anything.

That second sentence is the demo. Report-only isn't a watered-down version of
this demo — it's the version that teaches the safer habit.

---

## What the Terraform builds

| Resource | Why it's there |
|---|---|
| Resource group tagged `CostCenter=FIN-1042` | Scope for the assignment, and the compliant tag value |
| 2 custom **audit** policies (custom JSON) | The deck's "write custom JSON" beat, with a parameterised effect |
| 1 **built-in** policy — `Allowed locations` | You don't write everything yourself. Its effect is hardcoded **Deny**, which is the point: watching a Deny policy report instead of block is the report-only payoff |
| **Initiative** grouping all three | "Group into initiatives for whole-estate guardrails" |
| **Assignment** at RG scope, `enforce = false` | Scope for policy, in Azure's own report-only mode |
| `stgood…` storage account | Compliant control case |
| `stbad…` storage account | **Deliberately non-compliant** — no tag, public blob access allowed |

**Opt-in only** (`enable_remediation = true`): a Modify policy, a system-assigned
identity on the assignment, and a `Tag Contributor` role assignment scoped to the
demo resource group. See [the appendix](#appendix--the-remediation-path-opt-in).

---

## Pre-flight — start this 45 minutes before you present

Policy evaluation is not instant. Deploy early, then force a scan.

```bash
cd demos/01-policy-compliance/terraform
cp terraform.tfvars.example terraform.tfvars   # edit prefix / location if you like

az login
az account set --subscription "<your-subscription-id>"

terraform init
terraform apply

terraform output mode        # confirm it says REPORT-ONLY before you go further
```

Then force an on-demand compliance scan (takes 2–5 minutes; the default cycle is
up to 30 minutes):

```bash
az policy state trigger-scan --resource-group "$(terraform output -raw resource_group_name)"
```

Confirm you have a non-compliant resource before you walk on stage:

```bash
eval "$(terraform output -raw compliance_command)"
```

**Requires:** `Resource Policy Contributor` on the subscription (to create the
definitions) plus `Contributor` on the demo resource group. **No `Owner` and no
`User Access Administrator` needed** — with `enable_remediation = false` this
stack creates no role assignments at all.

---

## Run of show

### 1. Show the guardrail as code, not as a screenshot *(2 min)*

Open [`terraform/policies/audit-storage-public-blob-access.json`](terraform/policies/audit-storage-public-blob-access.json).

> "This is the whole policy. An `if` block that describes a condition, a `then`
> block that describes the effect. That's it. Everything else in Azure Policy is
> plumbing around these two keys."

Point at `"effect": "[parameters('effect')]"`.

> "And the effect is a parameter, not a constant. Same definition, different
> posture per environment — audit in dev, deny in prod, one artifact."

### 2. Definitions are inert. Assignments are the live wire. *(2 min)*

Portal → **Policy** → **Definitions** → filter to `[Precon]`.

> "These exist now. They are doing precisely nothing. A definition is a *description*
> of a rule — it has no scope, so it has no reach. This is the part people get
> wrong when they're nervous about policy: writing one is free and harmless.
> Assigning one is the decision."

Portal → **Policy** → **Assignments** → `[Precon] Baseline guardrails (report-only)`.

Point at the **Scope** field, then at **Policy enforcement: Disabled**.

> "Two things I want you to see. First, scope — one resource group. Not the
> subscription, not a management group. In your tenant this eventually goes on a
> management group and everything underneath inherits it, and that is why the
> earlier slide said design the hierarchy intentionally: the hierarchy *is* the
> enforcement surface. Second, enforcement is Disabled. That's Azure's report-only
> mode, and it is how you should introduce every guardrail you ever write."

### 3. View non-compliant resources *(3 min)*

Portal → **Policy** → **Compliance** → filter to the demo resource group. Drill
into the initiative.

Two of the three policies show non-compliant resources — both of them `stbad…`:

- missing the `CostCenter` tag
- public blob access allowed

Click through to the resource, then show the **non-compliance message**.

> "Compare the two storage accounts. Same subscription, same resource group,
> deployed 30 seconds apart. One is a finding and one isn't. Nobody had to
> notice — the platform noticed."

### 4. The report-only payoff *(3 min — this is the best beat)*

Stay in the compliance view and pull up the built-in `Allowed locations` policy.

```bash
cd demos/01-policy-compliance/terraform
eval "$(terraform output -raw would_have_blocked_command)"
```

Point at the `action` column: `audit` for the two custom policies, **`deny`** for
`Allowed locations`.

> "Look at that third row. That policy's effect is Deny. It is assigned. It is
> evaluating. And it has blocked exactly nothing — because enforcement is off.
> What I have here is a complete list of everything that policy *would* have
> rejected, generated against my real estate, with zero risk of breaking anybody."

> "This is the answer to the question you're going to get from your change board.
> 'How do we know this won't take production down?' You don't guess and you don't
> pilot it in a sandbox that looks nothing like prod. You assign it in
> DoNotEnforce against prod, let it run a week, read the report, fix the
> exceptions, *then* flip enforcement. Same artifact the whole way through — the
> only thing that changes is one boolean."

Show that boolean in [`terraform/main.tf`](terraform/main.tf):

```hcl
enforce = var.enforce_policies   # false => DoNotEnforce
```

> "One line in a pull request, with an author and a reviewer and a revert path.
> That's what promoting a guardrail should cost."

### 5. Close the loop *(1 min)*

> "So the sequence is: write the definition — free. Group it into an initiative —
> still free. Assign it in report-only — you learn what you'd break. Flip
> enforcement — now it's a control. Four steps, and the risky one is last and
> reversible."

Optional, if the room asks about auto-fixing: see the appendix below and describe
it rather than running it.

> "There's a fourth effect type, Modify, that doesn't just report drift — it
> removes it. Policy adds the missing tag itself, using a managed identity you
> grant a narrow role. It's genuinely great and I'd deliberately not turn it on
> in a demo tenant, because the first thing an architect should be able to
> articulate is what a control can *write to*."

---

## Appendix — the remediation path (opt-in)

Restores the slide's second bullet in full. Turning this on adds a Modify policy,
a system-assigned identity on the assignment, and a `Tag Contributor` role
assignment **scoped to the demo resource group only**. It needs `Owner` or
`User Access Administrator`.

Modify only fires when enforcement is also on, so you need both switches:

```bash
cd demos/01-policy-compliance/terraform
terraform apply -var 'enable_remediation=true' -var 'enforce_policies=true'

az policy state trigger-scan --resource-group "$(terraform output -raw resource_group_name)"
eval "$(terraform output -raw remediation_command)"

# The tag policy added, without anyone touching the resource
az storage account show \
  --name "$(terraform output -raw noncompliant_storage_account)" \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --query tags
```

> "I didn't touch that resource. The policy's managed identity did, using the
> Tag Contributor role I granted it at exactly one resource group. That is
> compliance as code closing its own loop."

**Put it back afterwards:**

```bash
terraform apply -var 'enable_remediation=false' -var 'enforce_policies=false'
```

### Demonstrating Deny

Same idea — needs `enforce_policies = true`, and it will genuinely reject
deployments inside the demo resource group:

```bash
terraform apply -var 'enforce_policies=true' -var 'audit_effect=Deny'
sleep 120   # assignment changes take a few minutes to propagate

az storage account create \
  --name "stdeny$RANDOM" \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --location eastus2 --sku Standard_LRS --allow-blob-public-access true
```

The create is rejected with `RequestDisallowedByPolicy` and your non-compliance
message in the error body.

> "That is the difference between a governance *document* and a governance
> *control*. The document is advice. This is physics."

Reset with `terraform apply` (defaults are report-only), and delete any
storage account you created by hand — Terraform doesn't know about it and it
will block `destroy`.

---

## If it breaks on stage

| Symptom | Cause | Fix |
|---|---|---|
| Compliance blade is empty | Evaluation hasn't run yet | `az policy state trigger-scan -g <rg>` — do this in pre-flight, not live |
| Everything shows compliant | Scan ran before the storage accounts existed | Trigger another scan and wait 2–5 min |
| `terraform output mode` doesn't say REPORT-ONLY | A `-var` or `terraform.tfvars` override is set | Check `terraform.tfvars`; defaults are report-only |
| `terraform apply` fails creating definitions | Missing `Resource Policy Contributor` | Definitions are created at subscription scope and need that role |
| `terraform apply` fails on `azurerm_role_assignment` | You enabled remediation without `Owner`/UAA | Set `enable_remediation=false`, or get `User Access Administrator` |
| Deny test succeeds when it should fail | Assignment change not propagated, or enforcement still off | Confirm `enforce_policies=true`; assignment changes take up to ~5 min |
| `data.azurerm_policy_definition_built_in` not found | Built-in display name changed | `az policy definition list --query "[?displayName=='Allowed locations'].name"` and pin the GUID |

---

## Teardown

```bash
cd demos/01-policy-compliance/terraform
terraform destroy
```

Terraform removes the assignment, initiative and definitions in the right order.
If you created a Deny-test storage account by hand, delete it first or `destroy`
will fail on a non-empty resource group.

---

## Approximate cost

Under **$0.05** for a couple of hours. Two empty LRS storage accounts; policy,
initiatives and remediation tasks are free.
