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

# Package the Compose file and loader from this Git commit.
files = [
    Path("docker/compose.yaml"),
    Path("services/loader/Dockerfile"),
    Path("services/loader/requirements.txt"),
    Path("services/loader/load.py"),
]

for path in files:
    if not path.is_file():
        raise RuntimeError(f"Required file missing: {path}")

archive = io.BytesIO()
with tarfile.open(fileobj=archive, mode="w:gz") as bundle:
    for path in files:
        bundle.add(path, arcname=path.as_posix())

payload = base64.b64encode(archive.getvalue()).decode("ascii")

# SSM executes this as root; the password stays on EC2.
remote_script = f"""#!/bin/bash
set -euo pipefail

release_dir=$(mktemp -d /opt/olist/reference-loader.XXXXXX)
trap 'rm -rf "$release_dir"' EXIT

printf '%s' '{payload}' | base64 --decode | tar -xz -C "$release_dir"

cd "$release_dir"

mkdir -p /usr/local/lib/docker/cli-plugins

curl -fSL --retry 3 \\
  https://github.com/docker/buildx/releases/download/v0.30.1/buildx-v0.30.1.linux-amd64 \\
  -o /usr/local/lib/docker/cli-plugins/docker-buildx

chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

docker buildx version
docker compose \\
  --project-name olist \\
  --env-file /opt/olist/.env \\
  -f docker/compose.yaml \\
  --profile tools config --quiet

docker compose \\
  --project-name olist \\
  --env-file /opt/olist/.env \\
  -f docker/compose.yaml \\
  --profile tools build loader

docker compose \\
  --project-name olist \\
  --env-file /opt/olist/.env \\
  -f docker/compose.yaml \\
  --profile tools run --rm --no-deps -T loader
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

    print("Reference data load succeeded.", flush=True)
    break
else:
    raise RuntimeError(
        f"Stopped waiting for SSM command {command_id}. "
        "Check its status in AWS before retrying."
    )