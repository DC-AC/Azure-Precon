#!/usr/bin/env bash
#
# Deploy the demo stacks for "Azure: From Admin to Architect".
#
#   ./deploy-all.sh                 # all seven demos
#   ./deploy-all.sh 01 04           # just those two
#
# Each stack is independent. Terraform state stays in its own directory.
#
set -euo pipefail

DEMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALL_DEMOS=(
  "01-azure-sql-private"
  "02-policy-compliance"
  "03-vnet-peering"
  "04-keyvault-cert-rotation"
  "05-function-app"
  "06-logic-app"
  "07-observability-alerts"
)

select_demos() {
  if [[ $# -eq 0 ]]; then
    printf '%s\n' "${ALL_DEMOS[@]}"
    return
  fi
  local arg found
  for arg in "$@"; do
    found=""
    for d in "${ALL_DEMOS[@]}"; do
      if [[ "$d" == "$arg" || "$d" == "$arg"-* ]]; then
        echo "$d"
        found=1
      fi
    done
    if [[ -z "$found" ]]; then
      echo "Unknown demo: $arg" >&2
      echo "Valid values: ${ALL_DEMOS[*]}" >&2
      exit 1
    fi
  done
}

command -v terraform >/dev/null || { echo "terraform not found on PATH" >&2; exit 1; }
command -v az >/dev/null || { echo "az CLI not found on PATH" >&2; exit 1; }

if ! az account show >/dev/null 2>&1; then
  echo "Not logged in. Run: az login && az account set --subscription <id>" >&2
  exit 1
fi

echo "Subscription: $(az account show --query '[name, id]' -o tsv | paste -sd' ' -)"
echo

# Portable read-into-array: macOS still ships bash 3.2, which has no mapfile.
TARGETS=()
while IFS= read -r line; do TARGETS+=("$line"); done < <(select_demos "$@")

for demo in "${TARGETS[@]}"; do
  dir="$DEMOS_DIR/$demo/terraform"
  echo "==> $demo"

  if [[ ! -f "$dir/terraform.tfvars" ]]; then
    echo "    no terraform.tfvars — copying from terraform.tfvars.example"
    cp "$dir/terraform.tfvars.example" "$dir/terraform.tfvars"
  fi

  terraform -chdir="$dir" init -input=false
  terraform -chdir="$dir" apply -input=false -auto-approve
  echo
done

echo "Done. Per-demo outputs:"
for demo in "${TARGETS[@]}"; do
  echo "  terraform -chdir=$DEMOS_DIR/$demo/terraform output"
done

cat <<'EOF'

Reminders:
  * Demo 01 needs your laptop's IP in client_ip_address, and its code deployed:
      cd 01-azure-sql-private/src && func azure functionapp publish <app-name> --python
    Deploy it the day before - point-in-time restore needs a completed first backup.
  * Demo 02 is REPORT-ONLY by default - it cannot block or modify anything.
    Confirm with:
      terraform -chdir=02-policy-compliance/terraform output mode
  * Demo 02 needs a compliance scan before it shows anything:
      az policy state trigger-scan --resource-group <rg>
  * Demo 03's VPN gateway is off by default (30-45 min to provision).
  * Demo 05 still needs the code deployed:
      cd 05-function-app/src && func azure functionapp publish <app-name> --python
  * Demo 07 needs alert_email and/or alert_sms_number in its terraform.tfvars,
    and deploys an ENFORCED DeployIfNotExists policy scoped to its own resource
    group. Give remediation 15-30 minutes before you present.
EOF
