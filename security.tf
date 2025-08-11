
# ==============================================================================
# CONFIGURACIÓN DE SEGURIDAD (GRUPOS DE SEGURIDAD Y ROLES DE IAM)
# ==============================================================================
# Este archivo define las reglas de firewall (Security Groups) para controlar
# el tráfico de red y los roles y políticas de IAM para gestionar los permisos.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Grupos de Seguridad (Security Groups)
# ------------------------------------------------------------------------------

# --- Grupo de Seguridad para el Balanceador de Carga (ALB) ---
# Permite el tráfico entrante HTTP (puerto 80) desde cualquier lugar de Internet.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# --- Grupo de Seguridad para las Tareas de ECS ---
# Permite el tráfico entrante solo desde el ALB hacia el puerto 5000 de la 
# aplicación Flask.
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 5000 # Puerto de la aplicación Flask
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks-sg"
  }
}

# --- Grupo de Seguridad para la Base de Datos (RDS) ---
# Permite el tráfico entrante en el puerto de MySQL (3306) solo desde las
# tareas de ECS.
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow traffic from ECS tasks to RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from ECS tasks"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# ------------------------------------------------------------------------------
# Roles y Políticas de IAM (Identity and Access Management)
# ------------------------------------------------------------------------------

# --- Rol de Ejecución de Tareas de ECS ---
# Rol que asume el agente de ECS para realizar acciones en nombre del usuario,
# como descargar imágenes de ECR y obtener secretos de Secrets Manager.
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-execution-role"
  }
}

# Asocia la política gestionada por AWS para la ejecución de tareas de ECS.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Política de Acceso a Secretos ---
# Define permisos explícitos para que las tareas de ECS puedan leer los secretos
# (credenciales de BD, claves de la app) desde AWS Secrets Manager.
resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "${var.project_name}-ecs-secrets-policy"
  description = "Permitir a las tareas de ECS acceder a los secretos"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Effect   = "Allow",
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn,
          aws_secretsmanager_secret.flask_app_password.arn
        ]
      }
    ]
  })
}

# Asocia la política de secretos al rol de ejecución de tareas.
resource "aws_iam_role_policy_attachment" "ecs_secrets_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}

# --- Política de Acceso a S3 ---
# Define permisos para que la aplicación pueda leer y escribir objetos en el
# bucket S3 designado.
resource "aws_iam_policy" "ecs_s3_policy" {
  name        = "${var.project_name}-ecs-s3-policy"
  description = "Permitir a las tareas de ECS acceder al bucket S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.photos-bucket.arn}/*"
      }
    ]
  })
}

# Asocia la política de S3 al rol de la tarea.
resource "aws_iam_role_policy_attachment" "ecs_s3_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_s3_policy.arn
}

# --- Política para ECS Exec ---
# Permite la funcionalidad de 'ECS Exec' para obtener un shell dentro de un
# contenedor en ejecución, útil para depuración.
resource "aws_iam_policy" "ecs_exec_policy" {
  name        = "${var.project_name}-ecs-exec-policy"
  description = "Permitir la funcionalidad de ECS Exec"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Asocia la política de ECS Exec al rol de la tarea.
resource "aws_iam_role_policy_attachment" "ecs_exec_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
}

# --- Rol de Tarea de ECS ---
# Rol que asume la aplicación dentro del contenedor. Es una buena práctica 
# separar los permisos de la aplicación de los permisos de ejecución del agente ECS.
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}
