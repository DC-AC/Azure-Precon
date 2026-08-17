# Demo 05 — Logic App Workflow

**Deck slide:** *Demonstration — Logic App Workflow* (Section 7 — Automation & Serverless)

> - Create a logic app, add a trigger, run it

**Runs after:** *Azure Logic Apps — Workflow Orchestration*
**Length:** 8–10 minutes live
**WAF pillars on screen:** Operational Excellence, Cost Optimization, Security

---

## The one thing they should leave with

> **Low-code is not un-architected.** The workflow is deployed from Terraform, the
> business rule is a reviewable variable, and the connector authenticates with a
> managed identity. Low-code changes who can *author* the flow — it does not change
> who owns the governance.

---

## The workflow

```
[ HTTP request trigger ]        POST {"orderId","customer","amount"}
           │
[ Build_order_record ]          Compose — normalise + stamp the run id
           │
[ Route_by_amount ]             If amount > approval_threshold (5000)
      ├── true  ──> Respond 202  "escalated"
      └── false ──> Respond 200  "auto-approved"
```

Deliberately **connector-free**, so it runs end-to-end from `curl` with nothing to
authorise and nothing to go wrong on stage. The "hundreds of connectors" beat is
done live in the designer — against a storage queue this stack has already
authorised for the workflow's managed identity.

---

## What the Terraform builds

| Resource | Notes |
|---|---|
| `azurerm_logic_app_workflow` + system-assigned identity | Consumption tier — per-action billing |
| `azurerm_logic_app_trigger_http_request` | With a **JSON schema**, so the designer gets typed tokens |
| `azurerm_logic_app_action_custom` × 2 | Compose, then a Condition with a Response in each branch |
| Storage account + `escalations` queue | Optional — target for the live connector step |
| `Storage Queue Data Message Sender` on the workflow identity | Pre-authorised, so the connector needs no key |

> **Why `depends_on` between the actions:** every action resource mutates the same
> workflow definition. Without the chain, Terraform issues the updates in parallel
> and they overwrite each other. This is the one genuinely awkward part of managing
> Consumption Logic Apps in Terraform, and it's worth 20 seconds on stage.

---

## Pre-flight

```bash
cd demos/05-logic-app/terraform
cp terraform.tfvars.example terraform.tfvars

az login
az account set --subscription "<your-subscription-id>"

terraform init
terraform apply          # ~1 minute
```

Verify both branches fire:

```bash
URL=$(terraform output -raw trigger_callback_url)

curl -sS -X POST "$URL" -H 'Content-Type: application/json' \
  -d '{"orderId":"SO-1001","customer":"Contoso","amount":250}'      # expect 200

curl -sS -X POST "$URL" -H 'Content-Type: application/json' \
  -d '{"orderId":"SO-1002","customer":"Fabrikam","amount":42000}'   # expect 202
```

**Requires:** `Owner` or `User Access Administrator` if `enable_queue_target = true`
(there's a role assignment); plain `Contributor` otherwise.

> Have the **designer open on one tab and a terminal on the other** before you start.
> The whole demo is the back-and-forth between them.

---

## Run of show

### 1. Trigger-driven, not scheduled *(2 min)*

Portal → the Logic App → **Logic app designer**.

> "Every Logic App starts with exactly one trigger. That's not a UI constraint —
> it's the execution model. Something happens, and the engine runs the action
> sequence. Nothing happens, nothing runs, and nothing is billed."

Click the trigger and show the request schema.

> "I gave the trigger a JSON schema. That's the difference between the designer
> knowing there's a field called `amount` that's a number, and you typing
> `@triggerBody()['amount']` by hand and finding your typo in production."

Then open **Add a trigger** in a new step and scroll the gallery.

> "Recurrence, HTTP, a new email in Outlook, a row in SQL, a message on Service
> Bus, a file in SharePoint, an Event Grid event. That gallery is the actual
> product — the engine is small, the connector catalogue is enormous."

### 2. Run it *(2 min)*

```bash
cd demos/05-logic-app/terraform
URL=$(terraform output -raw trigger_callback_url)

curl -sS -i -X POST "$URL" -H 'Content-Type: application/json' \
  -d '{"orderId":"SO-1001","customer":"Contoso","amount":250}'
```

`HTTP/1.1 200` and `"status":"auto-approved"`.

```bash
curl -sS -i -X POST "$URL" -H 'Content-Type: application/json' \
  -d '{"orderId":"SO-1002","customer":"Fabrikam","amount":42000}'
```

`HTTP/1.1 202` and `"status":"escalated"`.

> "Same endpoint, same payload shape, different route — because the condition
> evaluated differently. And it answered synchronously, so the caller got a
> decision rather than a receipt."

### 3. Run history is the reason people love this thing *(2 min)*

Portal → the Logic App → **Overview** → **Runs history** → click the escalated run.

Click into `Route_by_amount`. Show **Inputs** and **Outputs** on every action.

> "This is the part that wins the room. Every run, every action, every input and
> output, retained and inspectable without adding a single line of logging. Try
> getting that out of a PowerShell script on a scheduled task at 2am."

Then, honestly:

> "And it's also the trap. Those inputs are retained — which means if your
> payload has personal data or a token in it, your run history is now a data
> store you didn't design and probably haven't classified. Consumption Logic Apps
> let you mark inputs and outputs as secure to suppress that. Do it before you
> need it, not after."

### 4. The governance point — this is the slot that matters *(3 min)*

Change the business rule and redeploy:

```bash
terraform apply -var 'approval_threshold=100' -auto-approve

curl -sS -i -X POST "$URL" -H 'Content-Type: application/json' \
  -d '{"orderId":"SO-1003","customer":"Contoso","amount":250}'   # now 202, escalated
```

The same $250 order that auto-approved 30 seconds ago now escalates.

> "I changed a financial control. Not in the designer — in a variable, in a file,
> in a repo. That change is a pull request. It has an author, a reviewer, a
> timestamp and a revert path."

> "That's the whole low-code governance question. Nobody's objection to Logic
> Apps is 'the designer is hard'. The objection is 'who approved that, and can we
> roll it back'. The answer is IaC — same as everything else in this deck."

Now open the designer again and note the change is reflected there.

> "The designer and the code are the same object. Your business analyst can read
> the flow in the designer; your platform team can review the diff. You don't have
> to pick a side."

### 5. Managed identity on a connector *(2 min, optional but strong)*

In the designer, **+ New step** → search `Azure Queues` → **Put a message on a queue**.
At the connection screen, choose **Managed identity** (not access key).

It connects immediately — the role assignment is already in place:

```bash
terraform output logic_app_principal_id
terraform output queue_storage_account   # holds Storage Queue Data Message Sender
```

Point the action at the `escalations` queue with `@{outputs('Build_order_record')}`
as the message, save, then fire the escalated payload again and peek the queue:

```bash
az storage message peek --queue-name escalations \
  --account-name "$(terraform output -raw queue_storage_account)" \
  --auth-mode login --num-messages 5 -o json
```

> "Notice what the connection dialog did *not* ask me for. No account key, no
> connection string, no SAS token. The workflow has an identity and the identity
> has a role — and if someone leaves, or the workflow is deleted, that access
> disappears with it. That is the same pattern as the function app and the Key
> Vault demo. Three different services, one identity model."

*(If you're short on time, cut this step — the point is made in step 4.)*

---

## Combining with Demo 03

The Key Vault demo emits `CertificateNearExpiry` to Event Grid. This workflow is
a natural handler — a nice callback if you run both:

```bash
# From demo 03's terraform directory, note the Key Vault resource ID, then:
az eventgrid event-subscription create \
  --name cert-expiry-to-logicapp \
  --source-resource-id "<key vault resource id>" \
  --endpoint "$(terraform output -raw trigger_callback_url)" \
  --endpoint-type webhook \
  --included-event-types Microsoft.KeyVault.CertificateNearExpiry
```

> "Certificate is 30 days from expiry → Event Grid → this workflow → a Teams
> message to the platform channel with a link to the renewal runbook. Nobody had
> to remember anything. That's what 'automate, then govern the automation' means."

---

## If it breaks on stage

| Symptom | Cause | Fix |
|---|---|---|
| `curl` → **401 / 403** | Callback URL truncated, or the SAS was regenerated | Re-read it: `terraform output -raw trigger_callback_url` |
| `curl` → **400 Bad Request** | Payload doesn't match the trigger schema | `orderId` and `amount` are required; `amount` must be a number, not a string |
| `curl` hangs | No Response action reached | Check run history — an action before the Response failed |
| Actions vanish after `terraform apply` | Parallel writes to the same workflow | The `depends_on` chain prevents this; if you add an action, chain it too |
| Designer changes lost on next apply | Terraform owns the definition | Expected. Port designer edits back into `main.tf` — that's the governance point, not a bug |
| Connector shows no managed-identity option | Role assignment not propagated | Wait 2–3 min, or check `enable_queue_target = true` |

---

## Teardown

```bash
cd demos/05-logic-app/terraform
terraform destroy
```

---

## Approximate cost

Consumption Logic Apps bill **per action execution** — roughly $0.000025 each.
A demo's worth of runs plus an idle storage queue is **well under $0.01**. Idle
costs nothing at all.
