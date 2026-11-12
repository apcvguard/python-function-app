#!/usr/bin/env bash
# Deploys dist/functionapp.zip to an Azure Function App and smoke-tests /api/health.
# Required env: AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID RG APP
# Optional env: APP_VERSION
set -euo pipefail
ENV_NAME="${1:-dev}"
ZIP="dist/functionapp.zip"
[[ -f "$ZIP" ]] || { echo "Missing $ZIP - run the Package step first"; exit 1; }

az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID" --output none
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

echo "Setting app settings on $APP ($ENV_NAME)"
az functionapp config appsettings set -g "$RG" -n "$APP" --output none --settings \
  APP_ENV="$ENV_NAME" APP_VERSION="${APP_VERSION:-unknown}" \
  SCM_DO_BUILD_DURING_DEPLOYMENT=false ENABLE_ORYX_BUILD=false

echo "Deploying $ZIP to $APP"
az functionapp deployment source config-zip -g "$RG" -n "$APP" --src "$ZIP" --timeout 600

HOST=$(az functionapp show -g "$RG" -n "$APP" --query defaultHostName -o tsv)
URL="https://${HOST}/api/health"
echo "Smoke test: $URL"
for i in $(seq 1 12); do
  if BODY=$(curl -fsS --max-time 10 "$URL"); then
    echo "$BODY"
    if echo "$BODY" | grep -q "\"version\": \"${APP_VERSION:-}"; then
      echo "Deployed version confirmed."; exit 0
    fi
  fi
  echo "Not ready yet (attempt $i/12), retrying in 10s..."; sleep 10
done
echo "Smoke test failed"; exit 1
