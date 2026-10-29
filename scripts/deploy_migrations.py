import base64
import io
import json
from pathlib import Path
import subprocess
import tarfile
import time


def aws(*args):
    result = subprocess.run(
        ["aws", *args, "--region", "eu-west-2", "--output", "json"],
        capture_output=True,
        text=True,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout)


# Find exactly one running server belonging to this project.
response = aws(
    "ec2", "describe-instances",
    "--filters",
    "Name=tag:Project,Values=olist-streaming-platform",
    "Name=tag:Environment,Values=dev",
    "Name=tag:Name,Values=olist-dev",
    "Name=instance-state-name,Values=running",
)

instances = [
    instance["InstanceId"]
    for reservation in response["Reservations"]
    for instance in reservation["Instances"]
]

if len(instances) != 1:
    raise RuntimeError(
        f"Expected one running Olist instance; found {len(instances)}"
    )

instance_id = instances[0]

# Package SQL from this checked-out Git commit.
files = sorted(Path("sql/source").glob("V*__*.sql"))
if not files:
    raise RuntimeError("No migration files found")

archive = io.BytesIO()
with tarfile.open(fileobj=archive, mode="w:gz") as bundle:
    for path in files:
        bundle.add(path, arcname=path.name)

payload = base64.b64encode(archive.getvalue()).decode("ascii")

# SSM executes this as root. The password stays on EC2.
remote_script = f"""#!/bin/bash
set -euo pipefail
cd /opt/olist

migration_dir=$(mktemp -d /opt/olist/migrations.XXXXXX)
trap 'rm -rf "$migration_dir"' EXIT

printf '%s' '{payload}' | base64 --decode | tar -xz -C "$migration_dir"
chmod 755 "$migration_dir"
chmod 644 "$migration_dir"/*.sql

source /opt/olist/.env
export FLYWAY_PASSWORD="$POSTGRES_PASSWORD"

docker run --rm \\
  --network olist_default \\
  -e FLYWAY_PASSWORD \\
  -v "$migration_dir:/flyway/sql:ro" \\
  redgate/flyway:13.6.0 \\
  -url=jdbc:postgresql://postgres:5432/olist \\
  -user=olist_admin \\
  -defaultSchema=public \\
  -connectRetries=10 \\
  -validateMigrationNaming=true \\
  -cleanDisabled=true \\
  migrate
"""

# Keep this simple transport suitable for our small SQL migrations.
if len(remote_script.encode()) > 20_000:
    raise RuntimeError(
        "Migration package is too large for this workflow. "
        "Use an S3 deployment artifact instead."
    )

command = aws(
    "ssm", "send-command",
    "--instance-ids", instance_id,
    "--document-name", "AWS-RunShellScript",
    "--timeout-seconds", "60",
    "--parameters", json.dumps({
        "commands": [remote_script],
        "executionTimeout": ["600"],
    }),
)

command_id = command["Command"]["CommandId"]
print(f"Instance: {instance_id}", flush=True)
print(f"SSM command: {command_id}", flush=True)

deadline = time.monotonic() + 720

while time.monotonic() < deadline:
    try:
        result = aws(
            "ssm", "get-command-invocation",
            "--command-id", command_id,
            "--instance-id", instance_id,
        )
    except RuntimeError as error:
        # SSM results may take a moment to become available.
        if "InvocationDoesNotExist" not in str(error):
            raise
        time.sleep(5)
        continue

    status = result["Status"]

    if status in {"Pending", "InProgress", "Delayed", "Cancelling"}:
        time.sleep(5)
        continue

    print(result.get("StandardOutputContent", ""), flush=True)
    print(result.get("StandardErrorContent", ""), flush=True)

    if status != "Success":
        raise RuntimeError(f"Migration command finished with status: {status}")

    print("Database migrations succeeded.", flush=True)
    break
else:
    raise RuntimeError(
        f"Stopped waiting for SSM command {command_id}. "
        "Check its status in AWS before retrying."
    )