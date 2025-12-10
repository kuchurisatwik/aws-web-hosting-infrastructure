# Terraform: VPC + S3 + CloudFront

This folder contains a minimal Terraform configuration that creates:
- An AWS VPC with two public subnets
- An S3 bucket
- A CloudFront distribution using an Origin Access Identity (OAI) to securely serve the S3 bucket

Prerequisites
- Terraform 1.0+
- AWS credentials configured in your environment (e.g. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` or via named profile)

Quickstart

1. Open PowerShell in this folder.
2. Initialize Terraform:

```powershell
terraform init
```

3. Inspect the plan (set `-var 'bucket_name=your-unique-bucket-name'` if you want a specific bucket name):

```powershell
terraform plan -var "aws_region=us-east-1"
```

4. Apply:

```powershell
terraform apply -var "aws_region=us-east-1" -auto-approve
```

Notes
- If you don't provide `bucket_name`, Terraform will create a unique bucket name automatically.
- CloudFront distributions can take a few minutes to deploy; the output `cloudfront_domain_name` contains the distribution domain.

Security
- The configuration creates an Origin Access Identity and a bucket policy that permits CloudFront to read bucket objects.
- Customize and harden IAM and bucket policies as needed for production.

Files
- `providers.tf` - Terraform settings and AWS provider
- `variables.tf` - Input variables and defaults
- `vpc.tf` - VPC and subnet resources
- `s3_cloudfront.tf` - S3 bucket, OAI, bucket policy, CloudFront distribution
- `outputs.tf` - Helpful outputs after apply

Feel free to ask me to adapt this for private subnets, ALB, TLS certificates, or a custom domain with ACM.