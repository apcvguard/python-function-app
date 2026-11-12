#!/usr/bin/env bash
# For an EXISTING Function App: prints its details and creates a service principal
# that Harness uses to deploy. Run locally after `az login`.
#   RG=<resource-group> APP=<function-app-name> ./scripts/create-service-principal.sh
set -euo pipefail
: "${RG:?set RG}"; : "${APP:?set APP}"

echo "== Function App details =="
az functionapp show -g "$RG" -n "$APP" --query "{name:name, kind:kind, state:state, host:defaultHostName, linuxFxVersion:siteConfig.linuxFxVersion, flexRuntime:functionAppConfig.runtime}" -o json

SUB_ID=$(az account show --query id -o tsv)
APP_ID=$(az functionapp show -g "$RG" -n "$APP" --query id -o tsv)
echo "== Creating service principal scoped to this Function App only =="
az ad sp create-for-rbac -n "sp-harness-${APP}" --role "Website Contributor" --scopes "$APP_ID" \
  --query "{azure_client_id:appId, azure_client_secret:password, azure_tenant_id:tenant}" -o json
echo "azure_subscription_id: $SUB_ID"
echo "Store these four values as Harness secrets with the names shown."
