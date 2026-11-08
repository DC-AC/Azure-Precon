# Demo 06 — Azure SQL, Locked Down

**Deck slide:** *Demonstration — Azure SQL, Locked Down* (Section 2 — Azure SQL, Fabric & Data Platform)

> - Entra-only authentication: no SQL password exists anywhere
> - Turn off public access live; the app keeps working through its private endpoint
> - Point-in-time restore, timed — that's your RTO, measured

**Runs after:** *Vectors in Azure SQL* — but beat 0 starts at the first slide of Section 2, *Azure SQL — Deployment Models*
**Length:** 12–15 minutes live (plus pre-flight)
**WAF pillars on screen:** Security, Reliability, Cost Optimization

---

## The one thing they should leave with

> **The database has no password and no public address, and the app still works.**
> Identity replaces the credential, Private Link replaces the internet path, and
> the only permission you typed by hand was one line of T-SQL saying who may read.
> And your RTO isn't a number from a slide — it's the number `time` printed.

---

## What the Terraform builds

| Resource | Why it's there |
|---|---|
| Logical server with `azuread_authentication_only = true` | No `administrator_login`, no password variable — SQL authentication is off at the server |
| Entra admin = whoever ran `terraform apply` | Override with `entra_admin_object_id`. In production this is an Entra **group**, so admin rights follow membership and PIM |
| `sqldb-adventureworks` — `GP_S_Gen5_1` **serverless** | Pauses itself after 60 idle minutes; the AdventureWorksLT sample gives you real rows to query |
| Backup storage redundancy `Local` | Cheapest — and it rules out geo-restore. That's the BCDR slide's last bullet |
| One firewall rule, for `client_ip_address` | Only exists while public access is on. Azure won't hold firewall rules on a private-only server |
| VNet: `snet-func` (delegated to Flex) and `snet-pe` | `snet-pe` sets `default_outbound_access_enabled = false` — the platform default for new VNets since March 2026 |
| Private endpoint + `privatelink.database.windows.net` zone | DNS is half of Private Link. Without the zone, the function would resolve the public address |
| Flex Consumption function, VNet-integrated | Reads SQL through the **SQL input binding**, signed in as its system-assigned identity |
| Storage, user-assigned identity, App Insights | The same keyless pattern as demo 04 |

**What's deliberately missing:** a role assignment on the SQL server. Entra ID
proves who the function is; what it may do *inside the database* is a database
permission, granted in [`sql/grant-function-access.sql`](sql/grant-function-access.sql).

### The connection string with no secret in it

```
Server=tcp:sql-<suffix>.database.windows.net,1433;Database=sqldb-adventureworks;Authentication=Active Directory Managed Identity;Encrypt=True;
```

It's still called a connection string. Read it out loud on stage — a server, a
database, and "use my managed identity". There's nothing in it worth stealing.

---

## Pre-flight

**Requires:**
- `Owner` or `User Access Administrator` (four role assignments on the storage account)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local) (`brew install azure-functions-core-tools@4`)
- [go-sqlcmd](https://learn.microsoft.com/sql/tools/sqlcmd/go-sqlcmd-utility) (`brew install sqlcmd`). The commands use `--authentication-method ActiveDirectoryDefault`, which signs in with your `az login`. The legacy ODBC `sqlcmd` uses different flags

### The day before

Point-in-time restore needs the database to have some history, so deploy a day
early. The first apply takes 6–8 minutes, mostly the database and private endpoint.

```bash
cd demos/06-azure-sql-private/terraform
cp terraform.tfvars.example terraform.tfvars
curl -s https://api.ipify.org          # put this in terraform.tfvars as client_ip_address

az login
az account set --subscription "<your-subscription-id>"

terraform init
terraform apply

cd ../src
func azure functionapp publish "$(cd ../terraform && terraform output -raw function_app_name)"
```

Rehearse every beat once — including the grant, the flip and the restore — then
put it back to the "before" state:

```bash
cd ../terraform
terraform apply -var 'public_network_access_enabled=true'

sqlcmd -S "$(terraform output -raw sql_server_fqdn)" -d "$(terraform output -raw database_name)" \
  --authentication-method ActiveDirectoryDefault \
  -Q "DROP USER IF EXISTS [$(terraform output -raw function_app_name)]"

az sql db delete -g "$(terraform output -raw resource_group_name)" \
  -s "$(terraform output -raw sql_server_name)" -n sqldb-adventureworks-restored --yes
```

### At the venue

Conference Wi-Fi is not the network you rehearsed on. Update the one firewall rule:

```bash
curl -s https://api.ipify.org          # update client_ip_address in terraform.tfvars
terraform apply                        # ~30 seconds
```

### T-15

Wake the database — it paused itself overnight — and confirm the functions are registered:

```bash
eval "$(terraform output -raw connect_command)"     # first query after a pause: 30-60 s
az functionapp function list -g "$(terraform output -raw resource_group_name)" \
  -n "$(terraform output -raw function_app_name)" --query "[].name" -o tsv   # whoami, products
```

> **Don't run the grant in pre-flight.** The 500 before the grant is beat 3.

---

## Run of show

### 0. Start the clock *(30 seconds — at the top of Section 2)*

Open a second terminal:

```bash
cd demos/06-azure-sql-private/terraform
eval "$(terraform output -raw restore_command)"
```

> "I've just asked Azure to restore this database to ten minutes ago, as a new
> database. I'm not going to guess how long that takes. When we get to the demo,
> this terminal will tell us."

Leave it running and go back to the slides. Starting here rather than at the
*Business Continuity* slide gives the restore half an hour — plenty for this size.

### 1. The server with no password *(2 min)*

Open [`terraform/main.tf`](terraform/main.tf) at `azurerm_mssql_server`.

> "Find me the admin password. It's not a variable, not a random_password, not a
> Key Vault secret. `azuread_authentication_only = true` — there's no SQL login
> on this server for anyone to guess, phish or leave in a config file. The admin
> is an Entra principal: me, today. In production, a group, behind PIM."

Portal → SQL server → **Settings** → **Microsoft Entra ID**: *Support only Microsoft
Entra authentication for this server* is ticked.

### 2. Connect as yourself *(2 min)*

```bash
eval "$(terraform output -raw connect_command)"
```

`login_name` is your UPN; `client_address` is your laptop's public IP.

> "That's me, signed in with the identity I use for the portal — MFA, Conditional
> Access, the lot. And that address is my laptop, coming in through the public
> endpoint, allowed by exactly one firewall rule. Remember that address."

### 3. Authentication is not authorization *(3 min)*

```bash
FUNC_URL=$(terraform output -raw function_app_url)
KEY=$(eval "$(terraform output -raw function_key_command)")

curl -s -o /dev/null -w '%{http_code}\n' "$FUNC_URL/api/whoami?code=$KEY"     # 500
```

> "500. The function signed in to Entra just fine — Entra knows exactly who it is.
> The *database* doesn't. Authentication is not authorization."

Show [`sql/grant-function-access.sql`](sql/grant-function-access.sql), then run it:

```bash
eval "$(terraform output -raw grant_command)"
curl -s "$FUNC_URL/api/whoami?code=$KEY" | jq .
```

Point at three fields:

- `database_user` — the function app's name. That's the user you just created.
- `client_address` — **10.60.1.x**. An address inside `snet-func`.
- `service_objective` — `GP_S_Gen5_1`. Serverless, running because someone asked.

> "Same server name I used from my laptop. But this query came from 10.60.1-
> something — it never touched the public endpoint. The private DNS zone sent it
> to the private endpoint."

```bash
curl -s "$FUNC_URL/api/products?code=$KEY" | jq .
```

> "Read-only, because the grant was `db_datareader`. Least privilege is one
> `ALTER ROLE` line, in a file, reviewable in a pull request."

### 4. Close the front door *(3 min)*

```bash
terraform apply -var 'public_network_access_enabled=false'     # ~1 minute
```

Point at the plan while it runs: one attribute changes, one firewall rule is destroyed.

> "Azure won't keep a firewall rule on a server with public access off — there's
> nothing left for it to filter."

Now try both paths:

```bash
eval "$(terraform output -raw connect_command)"
```

> *"Connection was denied since Deny Public Network Access is set to Yes."*

```bash
curl -s "$FUNC_URL/api/whoami?code=$KEY" | jq .
```

Still works. Still 10.60.1.x.

> "Same server name, same connection string. My laptop resolves it to a public
> address and gets refused. The function resolves it through the private zone to
> the private endpoint and walks straight in. No IP allow-list to maintain, no
> public surface for anyone to scan. That's the *Private Endpoints over Service
> Endpoints over Public* slide we'll get to in Section 4 — you've just seen it."

Optional, for the networking crowd:

```bash
nslookup "$(terraform output -raw sql_server_fqdn)"
```

> "Even from outside you can see the `privatelink` alias in the chain. That's the
> hook the private DNS zone overrides inside the VNet."

### 5. The RTO you actually have *(2 min)*

Switch to the second terminal. `time` has printed something like `real 7m12s`.

```bash
az sql db list -g "$(terraform output -raw resource_group_name)" \
  -s "$(terraform output -raw sql_server_name)" \
  --query "[].{name:name, status:status, sku:currentServiceObjectiveName}" -o table
```

> "That's not an SLA and it's not a guess. That's how long it took, today, in this
> region, at this size, to get this database back to ten minutes ago. Put *that*
> number in the DR plan — and measure it again when the database is a hundred
> times bigger, because it will not stay the same."

Close on the cost decision:

> "One more thing: `backup_storage_redundancy = Local`. Geo-restore isn't
> possible from this database. That was a cost decision. Make sure yours are
> deliberate ones."

---

## The sample code

[`src/function_app.py`](src/function_app.py) — Python v2 programming model, two HTTP
triggers, both using the SQL input binding. The SQL runs in the Functions host with
.NET SqlClient, so there's no ODBC driver to install and no token code to write.

| Function | Needs | Purpose on stage |
|---|---|---|
| `whoami` | `CONNECT` only | Who SQL thinks is connecting, and from which address — the private-path proof |
| `products` | `db_datareader` | Five rows of AdventureWorksLT, so there's real data on screen |

---

## If it breaks on stage

| Symptom | Cause | Fix |
|---|---|---|
| `connect_command` hangs, then error 40613 | Database auto-paused and is resuming | Run it again. Wake it at T-15 |
| "Client with IP address … is not allowed to access the server" | Your venue IP changed | Update `client_ip_address` in `terraform.tfvars`, `terraform apply` (~30 s) |
| `unknown flag: --authentication-method` | Legacy ODBC `sqlcmd` is first on your PATH | `brew install sqlcmd`, or use the legacy tool with `-G` |
| Grant fails: principal "could not be found" | Wrong name, or a brand-new identity not yet visible | Check `terraform output function_app_name`; wait a minute and retry |
| `whoami` still 500 after the grant | Database resuming, or first call after the grant | Retry. App Insights → **Failures** shows the SQL error text |
| `whoami` → 404 | Code not published | `eval "$(terraform output -raw deploy_command)"` |
| `client_address` is a public IP, not 10.60.x.x | Function isn't resolving through the private zone | Confirm the zone link and the endpoint's DNS zone group exist; re-run `terraform apply` |
| Apply: subscription not registered for `Microsoft.App` | VNet integration needs the provider | `az provider register -n Microsoft.App --wait` |
| Restore: point in time is before the earliest restore point | Database is too new | Deploy the day before |
| `date: illegal option -- v` | GNU `date` (Linux) | Use `date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S` |

---

## Teardown

```bash
cd demos/06-azure-sql-private/terraform

# The restored copy isn't in Terraform state. Delete it first.
az sql db delete -g "$(terraform output -raw resource_group_name)" \
  -s "$(terraform output -raw sql_server_name)" -n sqldb-adventureworks-restored --yes

terraform destroy
```

---

## Approximate cost

| Component | Cost |
|---|---|
| Serverless database, paused | **$0 compute**; storage only, cents per day |
| Serverless database, active | ~$0.26–$0.52 per hour at 0.5–1 vCore, billed per second |
| The restored copy | The same again while it exists — delete it after the demo |
| Private endpoint | ~$0.01/hour plus data processed |
| Private DNS zone | ~$0.50/month |
| Flex Consumption, idle | **$0.00** |
| Log Analytics + App Insights | Well under 100 MB here |

Under **$2/day** for a rehearsal plus a delivery, as long as you delete the restored database.
