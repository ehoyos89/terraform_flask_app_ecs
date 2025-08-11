
# ==============================================================================
# GESTIÓN DE SECRETOS (AWS SECRETS MANAGER)
# ==============================================================================
# Este archivo se encarga de la creación segura de contraseñas y su 
# almacenamiento en AWS Secrets Manager para evitar exponer información sensible
# directamente en el código.
# ------------------------------------------------------------------------------

# --- Contraseña Aleatoria para la Base de Datos ---
# Genera una contraseña segura y aleatoria para la instancia de RDS.
resource "random_password" "db_password" {
  length  = 16
  special = false
}

# --- Secreto para las Credenciales de la Base de Datos ---
# Crea un secreto en AWS Secrets Manager para almacenar las credenciales de la BD.
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.project_name}-db-credentials"
}

# Crea una versión del secreto con el nombre de usuario (de variables.tf) y
# la contraseña generada aleatoriamente.
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username,
    password = random_password.db_password.result
  })
}

# --- Contraseña Aleatoria para la Aplicación Flask ---
# Genera una clave secreta aleatoria para la propia aplicación Flask.
resource "random_password" "flask_app_password" {
  length  = 16
  special = false
  upper = true
  lower = true
  
}

# --- Secreto para la Contraseña de la Aplicación Flask ---
# Crea un secreto en AWS Secrets Manager para almacenar la clave de la app.
resource "aws_secretsmanager_secret" "flask_app_password" {
  name = "${var.project_name}-flask-app-password"
}

# Almacena la contraseña generada en la versión del secreto.
resource "aws_secretsmanager_secret_version" "flask_app_password_version" {
  secret_id     = aws_secretsmanager_secret.flask_app_password.id
  secret_string = jsonencode({
    password = random_password.flask_app_password.result
  })
}
