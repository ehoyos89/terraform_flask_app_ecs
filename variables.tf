# ==============================================================================
# DEFINICIÓN DE VARIABLES
# ==============================================================================
# Este archivo declara todas las variables de entrada que se utilizan en el
# proyecto. Permite personalizar la configuración sin modificar el código fuente.
# ------------------------------------------------------------------------------

# --- Variable de Región de AWS ---
# Define la región de AWS donde se desplegará la infraestructura.
variable "aws_region" {
  description = "La región de AWS para desplegar la infraestructura."
  type        = string
  default     = "us-east-1"
}

# --- Variable del Nombre del Proyecto ---
# Un nombre base para todos los recursos para asegurar la consistencia y unicidad.
variable "project_name" {
  description = "El nombre del proyecto."
  type        = string
  default     = "ecs-flask-app"
}

# --- Variables de Configuración de Red (VPC) ---
# Define el rango de IPs para la VPC y las subredes públicas y privadas.
variable "vpc_cidr" {
  description = "El bloque CIDR para la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  description = "Los bloques CIDR para las subredes públicas."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidr" {
  description = "Los bloques CIDR para las subredes privadas."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# --- Variables de la Base de Datos (RDS) ---
# Credenciales para la base de datos. Se marcan como 'sensitive' para que
# Terraform no las muestre en los logs.
variable "db_username" {
  description = "El nombre de usuario para la base de datos RDS."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "El nombre de la base de datos RDS."
  type        = string
  sensitive   = true
}
