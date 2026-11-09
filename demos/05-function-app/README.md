# Demo 05 — Create a Function App

**Deck slide:** *Demonstration — Create a Function App* (Section 7 — Automation & Serverless)

> - Create and verify a function app

**Runs after:** *Azure Functions — Event-Driven Compute*
**Length:** 8–10 minutes live
**WAF pillars on screen:** Cost Optimization, Performance Efficiency, Security, Operational Excellence

---

## The one thing they should leave with

> **The interesting part of a function app is not the code — it's that there is no
> credential in it.** No connection string, no account key, no secret in an app
> setting. Storage access is a role assignment on a managed identity, and the bill
> only starts when a request arrives.

---

## What the Terraform builds

| Resource | Notes |
|---|---|
| `azurerm_service_plan` — **FC1** | Flex Consumption, the plan named on the slide |
| `azurerm_function_app_flex_consumption` | Python, `maximum_instance_count` and `instance_memory_in_mb` set explicitly |
| Storage account + `app-package` container | Deployment package and runtime state |
| **User-assigned** identity + `Storage Blob Data Owner` | Reads the deployment container — exists *before* the app does |
| **System-assigned** identity + Blob/Queue/Table Data Contributor | What the runtime uses for `AzureWebJobsStorage` |
| Log Analytics workspace + Application Insights | Workspace-based, wired via `site_config` |

### Why two identities

This is the *system-assigned vs user-assigned* slide as an actual design decision,
not a definition:

- The platform must read the deployment container **at app-create time**. A
  system-assigned identity does not exist yet at that moment — so deployment
  storage uses a **user-assigned** identity created and granted first.
- The app's own outbound calls use its **system-assigned** identity, which is
  created with the app and deleted with it. App-scoped access, app-scoped lifetime.

There is no `AzureWebJobsStorage` connection string in this stack. The setting is
`AzureWebJobsStorage__accountName` — an account *name*, resolved with the identity.

> **Known provider bug.** azurerm 4.81 injects its own `AzureWebJobsStorage`
> connection string — with an empty account key — into every Flex Consumption app
> ([#33211](https://github.com/hashicorp/terraform-provider-azurerm/issues/33211)).
> The host reads that before `__accountName`, fails to authenticate, and the app
> goes unhealthy. The stack sets `AzureWebJobsStorage = ""` to win that fight.
> The cost: every `terraform plan` shows that one line as a change until the fix
> ships. It's harmless — and a decent "read your plan" aside.

---

## Pre-flight

Flex Consumption is region-limited. Check before you pick a region:

```bash
az functionapp list-flexconsumption-locations -o table
az functionapp list-flexconsumption-runtimes --location eastus2 --runtime python -o table
```

```bash
cd demos/05-function-app/terraform
cp terraform.tfvars.example terraform.tfvars

az login
az account set --subscription "<your-subscription-id>"

terraform init
terraform apply          # ~3 minutes
```

Deploy the sample code:

```bash
cd ../src
func azure functionapp publish "$(cd ../terraform && terraform output -raw function_app_name)" --python
```

Verify before you walk on:

```bash
cd ../terraform
eval "$(terraform output -raw list_functions_command)"      # expect hello, heartbeat, load

FUNC_URL=$(terraform output -raw function_app_url)
KEY=$(eval "$(terraform output -raw function_key_command)")
curl -s "$FUNC_URL/api/hello?name=precon&code=$KEY" | jq .
```

**Requires:** `Owner` or `User Access Administrator` (four role assignments), plus
[Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
(`brew install azure-functions-core-tools@4`).

> **Deploy the code in pre-flight, not live.** A first `func publish` does a remote
> build and takes 2–4 minutes. Redeploying a one-line change on stage takes about 40
> seconds and is a much better use of the room's attention.

---

## Run of show

### 1. The plan is the architecture decision *(2 min)*

Portal → the function app → **Overview**, then the App Service plan → **FC1**.

> "Before any code: I picked a hosting plan, and that single choice sets my cost
> model, my cold-start behaviour, my networking options and my scale ceiling."

| Plan | Bills for | Cold start | Use when |
|---|---|---|---|
| **Consumption** | Executions + GB-seconds | Yes | Windows only, for new work — **Linux Consumption retires Sept 30, 2028** and gets no new language versions |
| **Flex Consumption** | Executions + GB-seconds, with optional always-ready | Optional | The current default — scale to zero *and* VNet integration |
| **Premium** | Pre-warmed instances, 24×7 | No | Sustained load, VNet, long runs |
| **Dedicated** | The App Service plan you already own | No | Spare capacity on an existing plan |

> "Flex Consumption is the one to reach for now. It's the only option that gives
> you scale-to-zero billing *and* private networking — you used to have to pick one."

Show the two numbers in [`terraform/main.tf`](terraform/main.tf):

```hcl
instance_memory_in_mb  = 2048
maximum_instance_count = 40
```

> "A scale ceiling I chose, not a default I inherited. That's the Performance
> Efficiency pillar: scale on thresholds you set deliberately. It's also your
> blast radius if somebody puts a runaway loop in a queue trigger."

### 2. Find the secret *(2 min — the best 2 minutes in this demo)*

Portal → the function app → **Settings** → **Environment variables**.

> "Here's the app settings blade. Find me the storage connection string."

There isn't one. There's `AzureWebJobsStorage__accountName` — a name, not a credential.
(`AzureWebJobsStorage` is there too, and empty on purpose — that's the provider
workaround above.)

Portal → **Settings** → **Identity**. Show both tabs: system-assigned **On**, and a
user-assigned identity attached.

Then storage account → **Access control (IAM)** → **Role assignments**.

> "Four role assignments and zero secrets. Nothing to rotate, nothing to leak,
> nothing to accidentally commit. Every one of those grants is scoped to one
> storage account — and I can see every one of them in a single IAM blade, which
> is exactly what you cannot do with account keys."

Tie it back:

> "Remember the storage slide — 'disable shared-key access where possible'. This
> is what 'possible' looks like. There's a variable in the tfvars that turns keys
> off entirely on this account."

### 3. Verify it runs *(2 min)*

```bash
cd demos/05-function-app/terraform
FUNC_URL=$(terraform output -raw function_app_url)
KEY=$(eval "$(terraform output -raw function_key_command)")

curl -s "$FUNC_URL/api/hello?name=$USER&code=$KEY" | jq .
```

Point at the `instance` field in the response.

> "That instance ID didn't exist a second ago. The platform allocated it when the
> request arrived and it'll be gone when traffic stops."

Then the timer trigger:

Portal → **Functions** → `heartbeat` → **Invocations**, or:

```bash
az functionapp function list -g "$(terraform output -raw resource_group_name)" \
  -n "$(terraform output -raw function_app_name)" \
  --query "[].{name:name, trigger:config.bindings[0].type}" -o table
```

> "The timer trigger is the one that proves the point. Timers need a lock in blob
> storage — that's how Azure stops two instances firing the same schedule. It's
> working, and there is still no connection string. That's the managed identity
> doing real work, not a checkbox."

### 4. Scale on demand *(2 min)*

Open Application Insights → **Live metrics**, then generate load:

```bash
for i in $(seq 1 60); do
  curl -s "$FUNC_URL/api/load?ms=4000&code=$KEY" >/dev/null &
done; wait
```

Watch the **server count** climb in live metrics.

> "I never wrote a scaling rule. No autoscale profile, no metric threshold, no
> schedule. The platform scaled on the queue of pending requests, and when I stop,
> it goes back to zero and so does the bill."

### 5. The cold-start trade-off *(1 min, optional but it's a good closer)*

```bash
terraform apply -var 'always_ready_instance_count=1' -auto-approve
```

> "One always-ready instance. Cold start goes away — and I now pay 24×7 for
> capacity whether anyone calls it or not. That is the Cost Optimization versus
> Performance Efficiency trade-off in a single variable, and the right answer is
> a business question, not a technical one. That's the whole job."

---

## The sample code

[`src/function_app.py`](src/function_app.py) — Python v2 programming model, three triggers:

| Function | Trigger | Purpose on stage |
|---|---|---|
| `hello` | HTTP | "It's alive", and shows the instance ID |
| `heartbeat` | Timer, every 5 min | Proves keyless storage access — timers need a blob lock |
| `load` | HTTP, `?ms=4000` | Burns CPU so the scale-out graph has something to draw |

---

## If it breaks on stage

| Symptom | Cause | Fix |
|---|---|---|
| `terraform apply`: "FC1 not available in this region" | Flex Consumption region gap | `az functionapp list-flexconsumption-locations -o table` and change `location` |
| `func publish` fails on remote build | `requirements.txt` / runtime mismatch | Confirm `runtime_version` matches `az functionapp list-flexconsumption-runtimes` |
| `curl` → **401** | Missing or wrong function key | `az functionapp keys list …` — the auth level is `FUNCTION` by design |
| `curl` → **404** | Code not deployed, or host still starting | `az functionapp function list …` — empty means the publish didn't land |
| Functions list is empty after a successful publish | Role assignment hadn't propagated at create time | Restart the app: `az functionapp restart -g <rg> -n <app>` |
| `func publish`: "Can't determine project language" | `local.settings.json` (which names the runtime) is gitignored | Add `--python` — the `deploy_command` output already does |
| `az functionapp keys list` → Bad Request; publish says "app appears to be unhealthy" | The provider's injected `AzureWebJobsStorage` connection string is winning | Confirm `AzureWebJobsStorage` is empty in **Environment variables**, `terraform apply`, then restart the app |
| `terraform plan` always shows `AzureWebJobsStorage` changing | Provider bug #33211 — see *What the Terraform builds* | Expected; nothing to fix |
| No data in Application Insights | Telemetry lag | Live metrics is near-real-time; the Logs blade lags 1–3 minutes |

---

## Teardown

```bash
cd demos/05-function-app/terraform
terraform destroy
```

---

## Approximate cost

| Component | Cost |
|---|---|
| Flex Consumption, idle | **$0.00** — scale to zero |
| A demo's worth of executions | Fractions of a cent |
| Log Analytics + App Insights ingestion | ~$2.30/GB, well under 100 MB here |
| Storage account | ~$0.02/GB-month |
| `always_ready_instance_count = 1` | **~$0.30/day, billed 24×7** — turn it back off |

Under **$0.50** for a full day of rehearsal and delivery, provided you reset
`always_ready_instance_count` to 0.
