
# ==============================================================================
# CONFIGURACIÓN DE CI/CD (CONTINUOUS INTEGRATION/CONTINUOUS DEPLOYMENT)
# ==============================================================================
# Este archivo define el pipeline de automatización que construye y despliega
# la aplicación automáticamente cuando hay cambios en el repositorio de código.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ECR (Elastic Container Registry)
# ------------------------------------------------------------------------------
# --- Repositorio de Imágenes Docker ---
# Crea un repositorio privado en ECR para almacenar las imágenes de Docker de la
# aplicación. La opción 'scan_on_push' analiza las imágenes en busca de 
# vulnerabilidades cada vez que se sube una nueva.
resource "aws_ecr_repository" "app_ecr_repo" {
  name                 = "${var.project_name}-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-ecr-repo"
  }
}

# ------------------------------------------------------------------------------
# Conexión a GitHub (CodeStar Connections)
# ------------------------------------------------------------------------------
# --- Conexión a GitHub ---
# Establece una conexión segura con GitHub. Después de aplicar, se debe 
# completar la autorización manualmente en la consola de AWS.
resource "aws_codestarconnections_connection" "github_connection" {
  provider_type = "GitHub"
  name          = "${var.project_name}-github-connection"
}

# ------------------------------------------------------------------------------
# Roles y Políticas de IAM para el Pipeline
# ------------------------------------------------------------------------------

# --- Rol para CodePipeline ---
# Define los permisos que necesita CodePipeline para orquestar el flujo, como
# acceder a S3, iniciar compilaciones en CodeBuild y desplegar en ECS.
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "codepipeline_policy" {
  name   = "${var.project_name}-codepipeline-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codestar-connections:UseConnection"
        ],
        Resource = aws_codestarconnections_connection.github_connection.arn
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ],
        Resource = aws_codebuild_project.app_build.arn
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:UpdateService",
          "ecs:RegisterTaskDefinition"
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

resource "aws_iam_role_policy_attachment" "codepipeline_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

# --- Rol para CodeBuild ---
# Define los permisos que necesita CodeBuild para ejecutar la compilación, como
# acceder a S3, escribir logs en CloudWatch y subir imágenes a ECR.
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "codebuild_policy" {
  name   = "${var.project_name}-codebuild-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
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
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Resource = aws_ecr_repository.app_ecr_repo.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# ------------------------------------------------------------------------------
# Bucket S3 para Artefactos del Pipeline
# ------------------------------------------------------------------------------
# CodePipeline necesita un bucket S3 para almacenar los artefactos (como el 
# código fuente o los resultados de la compilación) entre etapas.
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.project_name}-codepipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name = "${var.project_name}-codepipeline-artifacts"
  }
}

# Obtiene el ID de la cuenta de AWS actual para asegurar un nombre de bucket único.
data "aws_caller_identity" "current" {}


# ------------------------------------------------------------------------------
# Proyecto de CodeBuild
# ------------------------------------------------------------------------------
# Define el entorno de compilación. Especifica el tipo de máquina, la imagen
# de software (con Docker, etc.), las variables de entorno y el archivo 
# 'buildspec.yml' que contiene los comandos de compilación.
resource "aws_codebuild_project" "app_build" {
  name          = "${var.project_name}-build"
  description   = "Construye la imagen Docker para la app Flask"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "15" # en minutos

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true # Requerido para construir imágenes Docker
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = aws_ecr_repository.app_ecr_repo.repository_url
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "CONTAINER_NAME"
      value = "${var.project_name}-container"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml" # Asume que buildspec.yml está en la raíz del repo
  }

  tags = {
    Name = "${var.project_name}-build-project"
  }
}

# ------------------------------------------------------------------------------
# Pipeline de CodePipeline
# ------------------------------------------------------------------------------
# Orquesta todo el proceso de CI/CD en tres etapas:
# 1. Source: Obtiene el código fuente de GitHub.
# 2. Build: Ejecuta el proyecto de CodeBuild para crear la imagen Docker.
# 3. Deploy: Despliega la nueva imagen en el servicio de ECS.
resource "aws_codepipeline" "app_pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
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
        FullRepositoryId = "ehoyos89/FlaskApp"
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
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ClusterName = aws_ecs_cluster.main.name
        ServiceName = aws_ecs_service.main.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
