# IAM Role for Backend CodeBuild Project
resource "aws_iam_role" "backend_codebuild_role" {
  name = "backend-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Backend CodeBuild Role
resource "aws_iam_role_policy" "backend_codebuild_policy" {
  name = "backend-codebuild-policy"
  role = aws_iam_role.backend_codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion"
        ],
        Resource = [
          aws_s3_bucket.s3.arn,
          "${aws_s3_bucket.s3.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases",
          "codebuild:BatchPutCodeCoverages",
        ],
        Resource = "*"
      }
    ]
  })
}

# CodeBuild Project for Backend
resource "aws_codebuild_project" "backend_codebuild_project" {
  name          = "backend-build"
  service_role  = aws_iam_role.backend_codebuild_role.arn
  build_timeout = "10"
  source {
    type            = "GITHUB"
    location        = "https://github.com/kuchurisatwik/chatapp.git"
    git_clone_depth = 1
    buildspec       = "backend/buildspec.yml"
  }
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for EC2 Role
resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2-policy"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.s3.arn,
          "${aws_s3_bucket.s3.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Security Group for EC2 Instance
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-backend-sg"
  description = "Allow inbound traffic for backend application"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Find latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance for Backend
resource "aws_ec2_instance" "backend_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras install java-openjdk11 -y
              EOF
  tags = {
    Name = "backend-instance"
  }
}

# IAM Role for Deploy Stage CodeBuild
resource "aws_iam_role" "deploy_codebuild_role" {
  name = "deploy-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Deploy Stage CodeBuild
resource "aws_iam_role_policy" "deploy_codebuild_policy" {
  name = "deploy-codebuild-policy"
  role = aws_iam_role.deploy_codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:SendCommand"
        ],
        Resource = [
          aws_ec2_instance.backend_instance.arn,
          "arn:aws:ssm:*:*:document/AWS-RunShellScript"
        ]
      },
      {
        Effect   = "Allow",
        Action   = "iam:PassRole",
        Resource = aws_iam_role.ec2_role.arn
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.s3.arn}/*"
      }
    ]
  })
}

# CodeBuild Project for Deploy Stage
resource "aws_codebuild_project" "deploy_project" {
  name         = "backend-deploy"
  service_role = aws_iam_role.deploy_codebuild_role.arn
  build_timeout = "5"
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "INSTANCE_ID"
      value = aws_ec2_instance.backend_instance.id
    }
    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = aws_s3_bucket.s3.bucket
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        build:
          commands:
            - aws s3 cp app.jar s3://${ARTIFACT_BUCKET}/latest/app.jar
            - |
              aws ssm send-command \
                --instance-ids "${INSTANCE_ID}" \
                --document-name "AWS-RunShellScript" \
                --parameters 'commands=[
                  "aws s3 cp s3://${ARTIFACT_BUCKET}/latest/app.jar /home/ec2-user/app.jar",
                  "pkill -f 'java -jar' || true",
                  "nohup java -jar /home/ec2-user/app.jar > /home/ec2-user/app.log 2>&1 &"
                ]'
    EOF
  }
}

# Backend CodePipeline
resource "aws_codepipeline" "backend_pipeline" {
  name     = "backend-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.s3.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_connection.arn
        FullRepositoryId = "kuchurisatwik/chatapp"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.backend_codebuild_project.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.deploy_project.name
      }
    }
  }
}
