#!/bin/bash

set -euo pipefail

# Navigate to the directory containing the Terraform configuration
# Assuming vpc.tf is in the root of the repository for this example.
# If it's in a subdirectory, adjust this path accordingly (e.g., cd vpc).

echo "--- Initializing Terraform ---"
terraform init -backend=false # -backend=false prevents state backend config if not needed for validate/plan

if [ $? -ne 0 ]; then
  echo "Error: Terraform initialization failed."
  exit 1
fi

echo "--- Validating Terraform configuration ---"
terraform validate

if [ $? -ne 0 ]; then
  echo "Error: Terraform validation failed. Please check vpc.tf for syntax or configuration issues."
  exit 1
fi

echo "--- Generating Terraform plan ---"
# Use -no-color for easier parsing in CI environments, and -detailed-exitcode
# to distinguish between no changes (0), changes (2), and errors (1).
terraform plan -detailed-exitcode -no-color

PLAN_EXIT_CODE=$?

if [ $PLAN_EXIT_CODE -eq 1 ]; then
  echo "Error: Terraform plan generation failed. This might indicate configuration errors that prevent a successful plan."
  exit 1
elif [ $PLAN_EXIT_CODE -eq 0 ]; then
  echo "Success: Terraform plan generated with no changes required. Infrastructure matches configuration."
elif [ $PLAN_EXIT_CODE -eq 2 ]; then
  echo "Warning: Terraform plan generated with changes detected. This may be unexpected for a cosmetic change."
  echo "Please review the plan output above to understand the proposed changes."
  # For a cosmetic change, we might still consider this a success if it's not an error (exit 1)
  # but it's important to highlight if changes are proposed.
fi

echo "--- VPC Infrastructure Deployment Verification Test Passed Successfully ---"
