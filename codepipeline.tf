variable "github_oauth_token" {
  type      = string
  sensitive = true
}

# ECR Repository
resource "aws_ecr_repository" "wordpress" {
  name                 = "wordpress"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# S3 Bucket
resource "aws_s3_bucket" "tfvars_bucket" {
  bucket         = "wordpress-terraform-tfvars"
  force_destroy  = true
}

# IAM Role for CodePipeline
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

# IAM Policy for CodePipeline (S3 + CodeBuild access)
resource "aws_iam_policy" "codepipeline_s3_policy" {
  name = "codepipeline-s3-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          "${aws_s3_bucket.tfvars_bucket.arn}",
          "${aws_s3_bucket.tfvars_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ],
        Resource = aws_codebuild_project.wordpress_image_build.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_s3_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_s3_policy.arn
}

resource "aws_iam_policy" "codepipeline_ecs_policy" {
  name = "codepipeline-ecs-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_ecs_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_ecs_policy.arn
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_push_ecr_role" {
  name = "codebuild-push-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Custom IAM Policy for CodeBuild (optional if not using AdministratorAccess)
resource "aws_iam_policy" "codebuild_policy" {
  name = "codebuild-push-ecr-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ],
        Resource = [
          "${aws_s3_bucket.tfvars_bucket.arn}",
          "${aws_s3_bucket.tfvars_bucket.arn}/*"
        ]
      },
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
          "ec2:Describe*",
          "ecs:*",
          "elasticloadbalancing:*",
          "iam:PassRole",
          "cloudwatch:*",
          "ecr:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_push_ecr_permissions" {
  role       = aws_iam_role.codebuild_push_ecr_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# CodeBuild Project for building and pushing Docker image to ECR
resource "aws_codebuild_project" "wordpress_image_build" {
  name          = "wordpress-image-build"
  description   = "Build and push WordPress Docker image to ECR"
  build_timeout = 10

  service_role = aws_iam_role.codebuild_push_ecr_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "GITHUB"
    location  = "https://github.com/jorfonfir/proyecto-fargate.git"
    buildspec = "buildspec.yml" 
  }
}

# CodePipeline
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
      version          = "1"
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
    name = "DockerBuild"

    action {
      name             = "BuildDockerImage"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["BuildArtifact"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.wordpress_image_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "DeployToECS"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "ECS"
      input_artifacts  = ["BuildArtifact"]
      version          = "1"

      configuration = {
        ClusterName = aws_ecs_cluster.wordpress_cluster.name
        ServiceName = aws_ecs_service.wordpress_service.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
