# Terraform: VPC + S3 + CloudFront + EC2 (Backend)

A compact, practical Terraform example that creates a secure static delivery pipeline (S3 + CloudFront) **and** a simple EC2-based backend in the same VPC. This README explains what the code does, how to run it, and recommended production hardening.
---

## What this repo provisions:

* **VPC** with two public subnets (CIDR blocks included in `variables.tf`).
* **S3 bucket** for static assets.
* **CloudFront distribution** with an Origin Access Identity (OAI) so CloudFront can securely read objects from the S3 bucket.
* **EC2 instance** in a public subnet acting as a simple backend (you can replace this with a Docker service, systemd service, or connect an ALB later).
* **Security group** rules for SSH and HTTP access for the EC2 instance (customize for your environment).

Files in this folder:

* `providers.tf` – Terraform & AWS provider config
* `variables.tf` – Variables and sensible defaults (region, AMI, instance type, key pair name)
* `vpc.tf` – VPC, subnets, route tables
* `s3_cloudfront.tf` – S3 bucket, OAI, bucket policy, CloudFront distribution
* `ec2.tf` – EC2 instance, security group, optional user-data bootstrap
* `outputs.tf` – Useful outputs (CloudFront domain, EC2 public IP, SSH command).

---

## Prerequisites

* **Terraform 1.0+** installed.
* AWS credentials configured using one of these recommended methods:

  * Environment variables: `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` or
  * Named profile in `~/.aws/credentials` plus `AWS_PROFILE` env var, or
  * IAM role on the machine (recommended for CI runners / EC2).
* Optionally create an **EC2 key pair** in the target region and set its name in `-var 'key_name=...'` so you can SSH into the instance.

**Security note:** do **not** hard-code AWS credentials into Terraform files. Use environment variables, profiles, or remote state backends.

---

## Quickstart (example)

1. Initialize Terraform in this folder (downloads providers and modules) :

```bash
terraform init
```

2. (Optional) Inspect the plan. Example sets region and a custom bucket name. The plan lets you review resources before applying.

```bash
terraform plan -var "aws_region=us-east-1" -var "bucket_name=my-unique-bucket-12345" -var "key_name=my-keypair"
```

3. Apply the changes (creates resources):

```bash
terraform apply -var "aws_region=us-east-1" -var "bucket_name=my-unique-bucket-12345" -var "key_name=my-keypair" -auto-approve
```

4. After apply, Terraform outputs include `cloudfront_domain_name` (the distribution endpoint) and `ec2_public_ip`.

* Visit the CloudFront domain in your browser to see static content.
* SSH to the EC2 instance with the output SSH command shown in `ec2_ssh_command` (or use the `ec2_public_ip` with your key):

```bash
ssh -i /path/to/my-keypair.pem ec2-user@${ec2_public_ip}
```

---

## EC2 backend details included in this example

* **AMI**: Controlled via `variable "ami_id"` so you can choose the correct region-specific image. Default is Amazon Linux 2 (change if using other regions).
* **Instance type**: Controlled by `variable "instance_type"` (e.g. `t3.micro`).
* **Security group**: Minimal rules included:

  * SSH (port 22) from your IP (best practice: restrict to your workstation IP)
  * HTTP (port 80) from anywhere (or lock down to a load balancer or CloudFront IPs)
* **User data**: Simple bootstrap script to install and start a basic HTTP server (example uses `nginx` or `python -m http.server`). This demonstrates how to deliver a backend web app.

Example `ec2.tf` snippet (already included in repo):

```hcl
resource "aws_instance" "backend" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  user_data = file("user-data.sh")
  tags = { Name = "tf-backend-ec2" }
}
```

`user-data.sh` might contain (example):

```bash
#!/bin/bash
sudo yum update -y
sudo yum install -y nginx
sudo systemctl enable --now nginx
echo "Hello from Terraform-managed EC2" | sudo tee /usr/share/nginx/html/index.html
```

**What this does:** boots the instance, installs nginx, and hosts a default page accessible via the instance public IP.

---

## Common variables you may want to change

* `aws_region` – AWS region to deploy
* `bucket_name` – S3 bucket name (must be globally unique)
* `ami_id` – AMI ID for EC2 (ensure it matches the region)
* `instance_type` – EC2 instance size
* `key_name` – EC2 Key Pair created in the AWS Console or via CLI

---

## Outputs (what you’ll get after `apply`)

* `cloudfront_domain_name` – CloudFront distribution domain
* `s3_bucket_name` – The bucket created for static assets
* `ec2_public_ip` – IP to SSH or hit via HTTP
* `ec2_ssh_command` – A ready-to-run SSH command using the configured key name

---

## Security & production hardening (recommended)

1. **Do not expose SSH to the world** — restrict SSH to specific IP ranges (your office/home IP).
2. **Use private subnets** for backends and place an ALB (Application Load Balancer) in public subnets. Move EC2 instances to private subnets.
3. **Use IAM roles** for EC2 instead of long-lived credentials.
4. **Use ACM** for TLS termination at CloudFront or ALB — do not use self-signed certs in production.
5. **Store secrets** in AWS Secrets Manager or SSM Parameter Store. Don’t store secrets in Terraform state or plaintext files.
6. **Enable logging**: CloudFront access logs, S3 access logs, VPC Flow Logs, and OS-level logs shipped to CloudWatch/ELK.

---

## Next steps / variations you might ask for

* Replace single EC2 with an **Auto Scaling Group + Launch Template** for resiliency.
* Add an **ALB** in front of EC2 and use CloudFront + ALB origin for caching dynamic content.
* Use **private subnets** for EC2 and NAT gateway for outbound access.
* Deploy containerized backend (Docker + ECS/Fargate or EKS) instead of raw EC2.
* Integrate CI/CD: push artifacts to S3 or ECR, and automate deployments with GitHub Actions / CodePipeline.

---

## Troubleshooting tips

* **CloudFront not showing updated S3 content?** Invalidate the distribution or use versioned object keys.
* **EC2 fails on boot:** check EC2 System Log and CloudInit output; validate your user-data script syntax.
* **Permissions errors accessing S3 from CloudFront:** confirm the bucket policy allows the Origin Access Identity ARN.

---
