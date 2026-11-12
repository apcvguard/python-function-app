"""Azure Functions entry point (Python v2 programming model)."""
import json
import logging

import azure.functions as func

from app.greeting import build_greeting, health_payload

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)


@app.route(route="hello", methods=["GET", "POST"])
def hello(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("hello function triggered")
    name = req.params.get("name")
    if not name:
        try:
            name = (req.get_json() or {}).get("name")
        except ValueError:
            name = None
    status, body = build_greeting(name)
    return func.HttpResponse(json.dumps(body), status_code=status, mimetype="application/json")


@app.route(route="health", methods=["GET"], auth_level=func.AuthLevel.ANONYMOUS)
def health(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse(json.dumps(health_payload()), status_code=200, mimetype="application/json")
