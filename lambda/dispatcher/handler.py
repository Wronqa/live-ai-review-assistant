import os, json, boto3, traceback

ecs = boto3.client("ecs")

CLUSTER_ARN   = os.environ["CLUSTER_ARN"]
TASK_DEF_ARN  = os.environ["TASK_DEF_ARN"]
SUBNET_IDS    = os.environ["SUBNET_IDS"].split(",")
SEC_GROUP_ID  = os.environ["SEC_GROUP_ID"]

def lambda_handler(event, context):
    failures = []
    for rec in event.get("Records", []):
        body = rec["body"]  
        try:
            resp = ecs.run_task(
                cluster=CLUSTER_ARN,
                capacityProviderStrategy=[{"capacityProvider": "FARGATE_SPOT", "weight": 1}],
                taskDefinition=TASK_DEF_ARN,
                networkConfiguration={
                    "awsvpcConfiguration": {
                        "subnets": SUBNET_IDS,
                        "securityGroups": [SEC_GROUP_ID],
                        "assignPublicIp": "ENABLED"
                    }
                },
                overrides={
                    "containerOverrides": [{
                        "name": "worker",
                        "environment": [{"name": "CS_EVENT_JSON", "value": body}]
                    }]
                }
            )

            if resp.get("failures"):
                print(f"ECS run_task failures: {resp['failures']}")
                failures.append({"itemIdentifier": rec["messageId"]})
            else:
                task_arns = [t["taskArn"] for t in resp.get("tasks", [])]
                print(f"Started ECS task(s): {task_arns}")

        except Exception as e:
            print(f"Exception while running task for messageId={rec['messageId']}: {e}")
            traceback.print_exc()
            failures.append({"itemIdentifier": rec["messageId"]})

    return {"batchItemFailures": failures}
