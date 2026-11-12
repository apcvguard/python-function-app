#!/usr/bin/env bash
# One-time setup: resource group, storage, dev + prod Linux Python Function Apps,
# and a service principal for Harness. Run locally after `az login`.
set -euo pipefail
LOCATION="${LOCATION:-centralindia}"
RG="${RG:-rg-pyfunc}"
STORAGE="${STORAGE:-stpyfunc$RANDOM}"   # 3-24 lowercase alphanumerics, globally unique
DEV_APP="${DEV_APP:-pyfunc-app-dev}"
PROD_APP="${PROD_APP:-pyfunc-app-prod}"
PY_VERSION="${PY_VERSION:-3.11}"

az group create -n "$RG" -l "$LOCATION" -o none
az storage account create -n "$STORAGE" -g "$RG" -l "$LOCATION" --sku Standard_LRS -o none

for APP in "$DEV_APP" "$PROD_APP"; do
  az functionapp create -n "$APP" -g "$RG" --storage-account "$STORAGE" \
    --consumption-plan-location "$LOCATION" --os-type Linux \
    --runtime python --runtime-version "$PY_VERSION" --functions-version 4 -o none
  echo "Created $APP"
done

SUB_ID=$(az account show --query id -o tsv)
echo "Creating service principal scoped to $RG (store the output as Harness secrets):"
az ad sp create-for-rbac -n "sp-harness-pyfunc" --role Contributor \
  --scopes "/subscriptions/$SUB_ID/resourceGroups/$RG" \
  --query "{azure_client_id:appId, azure_client_secret:password, azure_tenant_id:tenant}" -o json
echo "azure_subscription_id: $SUB_ID"
