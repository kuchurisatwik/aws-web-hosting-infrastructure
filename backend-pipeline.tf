
data "aws_iam_policy_document" "codedeploy_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy_role" {
  name               = "codedeploy-role-new"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_role_policy.json
}

resource "aws_iam_role_policy_attachment" "codedeploy_role_attachment" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

data "aws_iam_role" "ec2_codedeploy_role" {
  name = "ec2-codedeploy-role"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-codedeploy-instance-profile-new"
  role = data.aws_iam_role.ec2_codedeploy_role.name
}

resource "aws_codedeploy_app" "backend_app" {
  compute_platform = "Server"
  name             = "backend-codedeploy-app-new"
}

resource "aws_codedeploy_deployment_group" "backend_dg" {
  app_name              = aws_codedeploy_app.backend_app.name
  deployment_group_name = "backend-deployment-group-new"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = "tf-ec2-instance"
  }

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }
}

data "aws_codebuild_project" "backend_codebuild_project" {
  name = "backend-build"
}

resource "aws_codepipeline" "backend_pipeline" {
  name     = "backend-pipeline-new"
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
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName      = aws_codedeploy_app.backend_app.name
        DeploymentGroupName  = aws_codedeploy_deployment_group.backend_dg.deployment_group_name
      }
    }
  }
}
