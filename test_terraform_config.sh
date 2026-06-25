#!/bin/bash
set -eo pipefail

# Ensure terraform is initialized without a backend to avoid state locking/remote issues for this simple test
echo "--- Initializing Terraform ---"
terraform init -backend=false

# Scenario: Terraform configuration validation
echo "--- Validating Terraform Configuration ---"
if ! terraform validate; then
  echo "ERROR: Terraform validation failed."
  exit 1
fi

# Scenario: Terraform plan output verification
echo "--- Planning Terraform Changes ---"
PLAN_OUTPUT=$(terraform plan -detailed-exitcode -no-color 2>&1)
PLAN_EXIT_CODE=$?

# detailed-exitcode:
# 0 = Succeeded with no diffs
# 1 = Errored
# 2 = Succeeded with diffs

if [ ${PLAN_EXIT_CODE} -eq 0 ]; then
  echo "Terraform Plan: No changes detected. (Exit code 0)"
  if [[ ! "${PLAN_OUTPUT}" =~ "No changes. Your infrastructure matches the configuration." ]]; then
    echo "ERROR: Plan output did not contain 'No changes' message despite exit code 0."
    echo "${PLAN_OUTPUT}"
    exit 1
  fi
elif [ ${PLAN_EXIT_CODE} -eq 1 ]; then
  echo "ERROR: Terraform plan failed."
  echo "${PLAN_OUTPUT}"
  exit 1
elif [ ${PLAN_EXIT_CODE} -eq 2 ]; then
  echo "ERROR: Terraform plan detected changes, but none were expected for a blank line removal."
  echo "${PLAN_OUTPUT}"
  exit 1
else
  echo "ERROR: Terraform plan exited with unexpected code: ${PLAN_EXIT_CODE}"
  echo "${PLAN_OUTPUT}"
  exit 1
fi

# Scenario: Terraform apply dry-run (if applicable/safe)
# For a 'no changes' plan, 'terraform apply -auto-approve' acts as an idempotency check
# and should report 0 added, 0 changed, 0 destroyed.

echo "--- Applying Terraform Configuration (Idempotency Check) ---"
APPLY_OUTPUT=$(terraform apply -auto-approve -no-color 2>&1)
APPLY_EXIT_CODE=$?

if [ ${APPLY_EXIT_CODE} -ne 0 ]; then
  echo "ERROR: Terraform apply failed."
  echo "${APPLY_OUTPUT}"
  exit 1
fi

# Verify apply output for '0 added, 0 changed, 0 destroyed'
if [[ ! "${APPLY_OUTPUT}" =~ "Apply complete! Resources: 0 added, 0 changed, 0 destroyed." ]]; then
  echo "ERROR: Terraform apply output did not indicate no resource changes."
  echo "${APPLY_OUTPUT}"
  exit 1
fi

echo "All Terraform configuration tests passed successfully."
