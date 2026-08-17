#!/usr/bin/env bash
#
# Tear down the demo stacks.
#
#   ./destroy-all.sh                # all five, with a confirmation prompt
#   ./destroy-all.sh 02             # just that one
#   FORCE=1 ./destroy-all.sh        # skip the prompt (use in CI / cleanup jobs)
#
# Destroys only stacks that have local Terraform state. Anything you created by
# hand in the portal is NOT tracked and will block the destroy — delete it first.
#
set -euo pipefail

DEMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALL_DEMOS=(
  "01-policy-compliance"
  "02-vnet-peering"
  "03-keyvault-cert-rotation"
  "04-function-app"
  "05-logic-app"
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
      exit 1
    fi
  done
}

command -v terraform >/dev/null || { echo "terraform not found on PATH" >&2; exit 1; }

# Portable read-into-array: macOS still ships bash 3.2, which has no mapfile.
TARGETS=()
while IFS= read -r line; do TARGETS+=("$line"); done < <(select_demos "$@")

PENDING=()
for demo in "${TARGETS[@]}"; do
  if [[ -f "$DEMOS_DIR/$demo/terraform/terraform.tfstate" ]]; then
    PENDING+=("$demo")
  fi
done

if [[ ${#PENDING[@]} -eq 0 ]]; then
  echo "Nothing to destroy — no local state found for: ${TARGETS[*]}"
  exit 0
fi

echo "About to DESTROY all Azure resources in these stacks:"
printf '  - %s\n' "${PENDING[@]}"
echo
echo "Subscription: $(az account show --query '[name, id]' -o tsv 2>/dev/null | paste -sd' ' - || echo 'unknown')"
echo

if [[ "${FORCE:-}" != "1" ]]; then
  read -r -p "Type DESTROY to continue: " answer
  [[ "$answer" == "DESTROY" ]] || { echo "Aborted."; exit 1; }
fi

for demo in "${PENDING[@]}"; do
  echo "==> destroying $demo"
  terraform -chdir="$DEMOS_DIR/$demo/terraform" destroy -input=false -auto-approve
  echo
done

echo "Done."
echo "Note: a VPN gateway (demo 02) can take 10-20 minutes to finish deleting."
