"""Sample functions for the 'Create a Function App' demo.

Three triggers, chosen to make three different points on stage:

  hello     - HTTP trigger. The "it's alive" proof.
  heartbeat - timer trigger. Proves the runtime reaches storage with a managed
              identity: timers need AzureWebJobsStorage, and there is no
              connection string configured anywhere.
  load      - HTTP trigger that burns CPU, so the scale-out graph in
              Application Insights actually has something to draw.
"""

import datetime
import json
import logging
import os
import time

import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)


@app.route(route="hello", methods=["GET", "POST"])
def hello(req: func.HttpRequest) -> func.HttpResponse:
    name = req.params.get("name")
    if not name:
        try:
            name = (req.get_json() or {}).get("name")
        except ValueError:
            name = None

    payload = {
        "message": f"Hello, {name or 'architect'}.",
        "instance": os.environ.get("WEBSITE_INSTANCE_ID", "local")[:12],
        "runtime": f"python {os.environ.get('FUNCTIONS_WORKER_RUNTIME_VERSION', '')}".strip(),
        "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    logging.info("hello invoked: %s", payload)

    return func.HttpResponse(
        json.dumps(payload, indent=2),
        mimetype="application/json",
        status_code=200,
    )


@app.timer_trigger(schedule="0 */5 * * * *", arg_name="timer", run_on_startup=False)
def heartbeat(timer: func.TimerRequest) -> None:
    """Runs every 5 minutes.

    A timer trigger takes a lock in blob storage. It works here without a single
    stored credential because AzureWebJobsStorage is configured as
    `AzureWebJobsStorage__accountName` and resolved with the app's
    system-assigned managed identity.
    """
    logging.info(
        "heartbeat at %s (past due: %s)",
        datetime.datetime.now(datetime.timezone.utc).isoformat(),
        timer.past_due,
    )


@app.route(route="load", methods=["GET"])
def load(req: func.HttpRequest) -> func.HttpResponse:
    """Burn CPU for `ms` milliseconds (default 2000, capped at 10000).

    Hit this concurrently to watch Flex Consumption scale out and to see the
    instance count move in Application Insights live metrics.
    """
    try:
        budget_ms = min(int(req.params.get("ms", "2000")), 10_000)
    except ValueError:
        budget_ms = 2000

    deadline = time.monotonic() + (budget_ms / 1000)
    iterations = 0
    while time.monotonic() < deadline:
        iterations += 1
        _ = sum(i * i for i in range(1000))

    return func.HttpResponse(
        json.dumps(
            {
                "burned_ms": budget_ms,
                "iterations": iterations,
                "instance": os.environ.get("WEBSITE_INSTANCE_ID", "local")[:12],
            },
            indent=2,
        ),
        mimetype="application/json",
        status_code=200,
    )
