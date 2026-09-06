#!/usr/bin/env bash
# Runs one plan/apply attempt against a Terraform stack and treats known
# transient OCI capacity errors as "try again later" rather than a failure.
# Called from .github/workflows/oracle-provision-retry.yml on a schedule —
# this script does not loop itself, the schedule is the loop.
#
# Pass --replace as a second argument to force the compute instance to be
# recreated (e.g. after a first-boot cloud-init failure) using the exact
# same stored secrets — no need to re-enter any credentials by hand.
set -euo pipefail

STACK_DIR="${1:?usage: retry-provision.sh <stack-dir> [--replace]}"
REPLACE_FLAG="${2:-}"
cd "$STACK_DIR"

if [ "$REPLACE_FLAG" = "--replace" ]; then
  echo "== terraform apply -replace (forced recreate) =="
  set +e
  APPLY_OUTPUT=$(terraform apply -replace=oci_core_instance.primary -auto-approve -input=false -no-color 2>&1)
  APPLY_EXIT=$?
  set -e
  echo "$APPLY_OUTPUT"
  if [ "$APPLY_EXIT" -eq 0 ]; then
    echo "Instance recreated successfully."
    echo "provisioned=true" >>"${GITHUB_OUTPUT:-/dev/null}"
    exit 0
  fi
  echo "Unexpected Terraform error during forced replace — failing the job so it's visible." >&2
  exit 1
fi

echo "== terraform plan =="
set +e
PLAN_OUTPUT=$(terraform plan -detailed-exitcode -input=false -no-color 2>&1)
PLAN_EXIT=$?
set -e
echo "$PLAN_OUTPUT"

if [ "$PLAN_EXIT" -eq 0 ]; then
  echo "Nothing to do — already provisioned."
  echo "provisioned=true" >>"${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

echo "== terraform apply =="
set +e
APPLY_OUTPUT=$(terraform apply -auto-approve -input=false -no-color 2>&1)
APPLY_EXIT=$?
set -e
echo "$APPLY_OUTPUT"

if [ "$APPLY_EXIT" -eq 0 ]; then
  echo "Provisioned successfully."
  echo "provisioned=true" >>"${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

# Known, expected, transient OCI capacity errors — this is the whole reason
# this script exists instead of a plain `terraform apply` in CI. Treat them
# as "not yet," not as a pipeline failure: exit 0 so the workflow shows
# green and doesn't email/notify on every single retry, but leave a clear
# marker in the logs and in provisioned=false for the workflow to act on.
if echo "$APPLY_OUTPUT" | grep -qiE "Out of host capacity|OutOfCapacity|LimitExceeded|TooManyRequests|InternalError"; then
  echo "Known transient capacity error — will retry on the next schedule."
  echo "provisioned=false" >>"${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

# Anything else (bad credentials, invalid config, quota actually exceeded
# for a different reason) is a real problem — fail loudly so it's visible
# instead of silently retrying forever against a config error.
echo "Unexpected Terraform error — failing the job so it's visible." >&2
exit 1
