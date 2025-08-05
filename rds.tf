
# ------------------------------------------------------------------------------
# RDS
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier           = "${var.project_name}-db"
  allocated_storage    = 20
  port                 = 3306
  engine               = "mysql"
  engine_version       = "8.0.41"
  instance_class       = "db.t4g.micro"
  storage_type         = "gp3" 
  storage_encrypted    = true
  db_name              = var.db_name
  username             = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string).username
  password             = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string).password 
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot  = true
  multi_az             = false
  deletion_protection  = false
  performance_insights_enabled = false

  tags = {
    Name = "${var.project_name}-rds-instance"
  }
}

# ECS Task Definition for database initialization
resource "aws_ecs_task_definition" "db_init" {
  family                   = "${var.project_name}-db-init-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-db-init-container"
      image     = "mysql:8.0"
      essential = true
      
      environment = [
        {
          name  = "MYSQL_HOST"
          value = aws_db_instance.main.address
        },
        {
          name  = "MYSQL_PORT"
          value = "3306"
        }
      ]
      
      secrets = [
        {
          name      = "MYSQL_USER"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:username::"
        },
        {
          name      = "MYSQL_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        }
      ]

      command = [
        "/bin/sh",
        "-c",
        "mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p$MYSQL_PASSWORD -e 'CREATE DATABASE IF NOT EXISTS flaskdb; USE flaskdb; CREATE TABLE IF NOT EXISTS employee (id int not null auto_increment primary key, object_key nvarchar(80), full_name nvarchar(200) not null, location nvarchar(200) not null, job_title nvarchar(200) not null, badges nvarchar(200) not null, created_datetime DATETIME DEFAULT now());'"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-db-init"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-db-init-task-definition"
  }
}

# CloudWatch Log Group for database initialization
resource "aws_cloudwatch_log_group" "db_init" {
  name = "/ecs/${var.project_name}-db-init"

  tags = {
    Name = "${var.project_name}-db-init-log-group"
  }
}

# NULL resource to run the database initialization ECS task
resource "null_resource" "database_initialization" {
  depends_on = [ 
    aws_db_instance.main,
    aws_ecs_task_definition.db_init,
    aws_cloudwatch_log_group.db_init
  ]

  # Triggers que refuerzan la re-ejecución
  triggers = {
    db_instance_identifier = aws_db_instance.main.identifier
    task_definition_arn = aws_ecs_task_definition.db_init.arn
  }

  # Provisioner para esperar a que RDS esté disponible
  provisioner "local-exec" {
    command = "aws rds wait db-instance-available --db-instance-identifier ${aws_db_instance.main.identifier}"
  }
  
  # Provisioner para ejecutar la tarea de inicialización
  provisioner "local-exec" {
    command = <<-EOT
      aws ecs run-task \
        --cluster ${aws_ecs_cluster.main.name} \
        --task-definition ${aws_ecs_task_definition.db_init.arn} \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[${join(",", aws_subnet.private[*].id)}],securityGroups=[${aws_security_group.ecs_tasks.id}],assignPublicIp=DISABLED}"
    EOT
  }
}
