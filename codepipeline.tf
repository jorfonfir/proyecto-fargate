variable "github_oauth_token" {
  type      = string
  sensitive = true
}

resource "aws_s3_bucket" "tfvars_bucket" {
  bucket = "wordpress-terraform-tfvars"
  force_destroy = true
}

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codepipeline.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_codebuild_project" "terraform_build" {
  name        = "terraform-wordpress-build"
  description = "Terraform deployment"
  build_timeout = 10

  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
  }

  source {
    type      = "GITHUB"
    location  = "https://github.com/jorfonfir/proyecto-fargate.git"
    buildspec = "buildspec.yml"
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_permissions" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_codepipeline" "wordpress_pipeline" {
  name     = "wordpress-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.tfvars_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Github_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "2"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "jorfonfir"
        Repo       = "proyecto-fargate"
        Branch     = "main"
        OAuthToken = var.github_oauth_token
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "TerraformBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = []
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
      }
    }
  }
}
