import json

def lambda_handler(event, context):
    headers = event.get("headers") or {}
    gh_event = headers.get("x-github-event")
    
    if gh_event == "ping":
        body = {"ok": True, "pong": True}
    else:
        body = {"ok": True, "received_event": gh_event}

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }