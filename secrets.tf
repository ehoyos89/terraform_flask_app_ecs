
# ------------------------------------------------------------------------------
# Secrets Manager
# ------------------------------------------------------------------------------

# Contraseña aleatoria para la base de datos
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# Guarda las credenciales de la base de datos en AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}-db-credentials"
}

# Almacena el nombre de usuario y contraseña de la base de datos en el secreto
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username,
    password = random_password.db_password.result
  })
}

# Genera una contraseña aleatoria para la aplicación Flask
resource "random_password" "flask_app_password" {
  length  = 16
  special = false
  upper = true
  lower = true
  
}

# Guarda la contraseña de la aplicación Flask en AWS Secrets Manager
resource "aws_secretsmanager_secret" "flask_app_password" {
  name = "${var.project_name}-flask-app-password"
}

# Almacena la contraseña de la aplicación Flask en el secreto
resource "aws_secretsmanager_secret_version" "flask_app_password_version" {
  secret_id     = aws_secretsmanager_secret.flask_app_password.id
  secret_string = jsonencode({
    password = random_password.flask_app_password.result
  })
}
