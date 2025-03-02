provider "aws" {
  region = var.region
}

# 変数定義
variable "app_name" {
  description = "アプリケーション名"
  type        = string
}

variable "image_tag" {
  description = "デプロイするイメージのタグ"
  type        = string
}

variable "region" {
  description = "AWSリージョン"
  type        = string
}

locals {
  tags = {
    Name        = var.app_name
    Environment = "production"
  }
}

# ECRリポジトリの作成
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

# ECRリポジトリポリシー
resource "aws_ecr_repository_policy" "app_policy" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowPullFromAppRunner",
        Effect = "Allow",
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        },
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# App Runner用IAMロール
resource "aws_iam_role" "apprunner_access_role" {
  name = "${var.app_name}-apprunner-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# ECRアクセス用のポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "apprunner_ecr_access" {
  role       = aws_iam_role.apprunner_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# Dockerイメージのビルドとプッシュ用のnullリソース
resource "null_resource" "docker_push" {
  depends_on = [aws_ecr_repository.app]

  triggers = {
    ecr_repository_url = aws_ecr_repository.app.repository_url
    dockerfile_hash    = filemd5("${path.module}/Dockerfile")
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/docker_build_push.sh ${aws_ecr_repository.app.repository_url} ${var.image_tag} ${var.region}"
  }
}

# App Runnerサービスの作成
resource "aws_apprunner_service" "app" {
  service_name = var.app_name
  depends_on   = [aws_ecr_repository_policy.app_policy, null_resource.docker_push]

  source_configuration {
    auto_deployments_enabled = true

    image_repository {
      image_configuration {
        port = "8080"
      }
      image_identifier      = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      image_repository_type = "ECR"
    }

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_access_role.arn
    }
  }

  instance_configuration {
    cpu    = "1 vCPU"
    memory = "2 GB"
  }

  tags = local.tags
}

# 出力
output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "ECRリポジトリURL"
}

output "app_runner_service_url" {
  value       = aws_apprunner_service.app.service_url
  description = "App Runner Service URL"
}

output "deployment_instructions" {
  value = <<-EOT
    App Runner サービスのセットアップが完了しました。
    
    サービスURL: ${aws_apprunner_service.app.service_url}
    
    GitHub Actionsによる自動デプロイを設定するには：
    1. GitHub リポジトリにSecrets を追加:
       - AWS_ACCESS_KEY_ID
       - AWS_SECRET_ACCESS_KEY
    2. .github/workflows/deploy.yml ファイルを追加
    
    自動デプロイは ECR への新しいイメージのプッシュで自動的に開始されます（auto_deployments_enabled = true）
  EOT
  description = "デプロイ手順"
}