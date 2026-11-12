# Python Azure Function App — deployed by Harness from Git

```
git push main ──► Harness trigger ──► [Unit tests → Package → Deploy DEV + smoke test]
                                         ──► [Manual approval] ──► [Package → Deploy PROD + smoke test]
```

## Layout
| Path | Purpose |
|---|---|
| `function_app.py` | Functions (v2 model): `GET/POST /api/hello?name=X` (function key), `GET /api/health` (anonymous) |
| `app/greeting.py` | Business logic, no Azure SDK, unit tested |
| `tests/` | pytest suite |
| `host.json`, `requirements.txt` | Function runtime config + deps |
| `.harness/pipeline.yaml` | Harness pipeline (import into your project) |
| `.harness/trigger-push-main.yaml` | Webhook trigger on push to `main` |
| `scripts/deploy.sh` | Zip deploy via `az` + health-check that the new commit is live |
| `scripts/create-azure-resources.sh` | One-time Azure setup + service principal |

## Setup (one time)

1. **Push this repo** to GitHub/GitLab/Bitbucket/Azure Repos.
2. **Create Azure resources** (needs Azure CLI, `az login`):
   ```bash
   RG=rg-pyfunc DEV_APP=<unique>-dev PROD_APP=<unique>-prod ./scripts/create-azure-resources.sh
   ```
   It prints the service-principal credentials.
3. **In Harness → Project Settings:**
   - **Connectors**: a Git connector `github_connector` (API access enabled, for webhooks) and a Docker registry connector `docker_hub` (`https://index.docker.io/v2/`, anonymous is fine).
   - **Secrets** (text): `azure_client_id`, `azure_client_secret`, `azure_tenant_id`, `azure_subscription_id`.
4. **Import the pipeline**: Pipelines → Create → *Import from Git* → `.harness/pipeline.yaml` (or paste the YAML). Fix the `CHANGE_ME` values: org/project IDs, repo name, resource group, app names, approver group.
5. **Create the trigger**: Pipeline → Triggers → New → YAML → paste `.harness/trigger-push-main.yaml`. Harness registers the webhook on the repo.
6. `git push` to `main` → watch it deploy.

## Test after deploy
```bash
curl https://<dev-app>.azurewebsites.net/api/health
KEY=$(az functionapp keys list -g rg-pyfunc -n <dev-app> --query functionKeys.default -o tsv)
curl "https://<dev-app>.azurewebsites.net/api/hello?name=Asha&code=$KEY"
```

## Local dev
```bash
python -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt && pytest
cp local.settings.example.json local.settings.json && func start   # Azure Functions Core Tools v4
```

## Notes
- The package image (`python:3.11-slim`) must match the Function App's Python version; change both together.
- Dependencies are vendored into `.python_packages` in CI, and remote build is disabled, so what was tested is what runs.
- Prod rebuilds from the same commit SHA that passed dev. The prod stages only run for `main`.
- Self-hosted Harness runners: change `runtime.type: Cloud` to your `KubernetesDirect`/`Docker` infrastructure.
