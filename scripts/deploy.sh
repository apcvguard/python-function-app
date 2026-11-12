#!/usr/bin/env bash
# Deploys dist/functionapp.zip to an EXISTING Azure Function App and smoke-tests /api/health.
# Works with Linux Consumption, Premium, Dedicated and Flex Consumption plans.
# Required env: AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID RG APP
# Optional env: APP_VERSION
set -euo pipefail
ENV_NAME="${1:-dev}"
ZIP="dist/functionapp.zip"
[[ -f "$ZIP" ]] || { echo "Missing $ZIP - run the Package step first"; exit 1; }

az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID" --output none
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# --- Inspect the existing app -------------------------------------------------
KIND=$(az functionapp show -g "$RG" -n "$APP" --query kind -o tsv)
FLEX_RT=$(az functionapp show -g "$RG" -n "$APP" --query "functionAppConfig.runtime.name" -o tsv 2>/dev/null || true)
if [[ -n "$FLEX_RT" && "$FLEX_RT" != "None" ]]; then
  PLAN="flex"
  APP_PY=$(az functionapp show -g "$RG" -n "$APP" --query "functionAppConfig.runtime.version" -o tsv)
  [[ "$FLEX_RT" == "python" ]] || { echo "App runtime is '$FLEX_RT', not python"; exit 1; }
else
  PLAN="classic"
  [[ "$KIND" == *linux* ]] || { echo "App kind '$KIND' is not Linux; Python Function Apps must be Linux"; exit 1; }
  FX=$(az functionapp config show -g "$RG" -n "$APP" --query linuxFxVersion -o tsv)   # e.g. Python|3.11
  [[ "${FX,,}" == python* ]] || { echo "App stack is '$FX', not Python"; exit 1; }
  APP_PY="${FX#*|}"
fi
BUILD_PY=$(cat dist/pyversion 2>/dev/null || echo unknown)
echo "App: $APP | plan: $PLAN | app Python: $APP_PY | build Python: $BUILD_PY"
if [[ "$BUILD_PY" != "unknown" && "$APP_PY" != "$BUILD_PY" ]]; then
  echo "ERROR: Python mismatch. Change the python:<ver>-slim image in the Package step(s) to python:${APP_PY}-slim"
  exit 1
fi

# --- App settings -------------------------------------------------------------
SETTINGS=(APP_ENV="$ENV_NAME" APP_VERSION="${APP_VERSION:-unknown}")
if [[ "$PLAN" == "classic" ]]; then
  SETTINGS+=(SCM_DO_BUILD_DURING_DEPLOYMENT=false ENABLE_ORYX_BUILD=false)  # deps are pre-packaged
fi
az functionapp config appsettings set -g "$RG" -n "$APP" --output none --settings "${SETTINGS[@]}"

# --- Deploy ---------------------------------------------------------------------
echo "Deploying $ZIP to $APP"
az functionapp deployment source config-zip -g "$RG" -n "$APP" --src "$ZIP" --timeout 600

# --- Smoke test -----------------------------------------------------------------
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
