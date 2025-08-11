# ==============================================================================
# SALIDAS (OUTPUTS)
# ==============================================================================
# Este archivo define los valores de salida que Terraform mostrará una vez que
# la infraestructura haya sido creada. Son útiles para acceder a recursos
# importantes, como URLs o endpoints.
# ------------------------------------------------------------------------------

# --- Salida del DNS del Balanceador de Carga ---
# Muestra la URL pública del Application Load Balancer para acceder a la aplicación.
output "alb_dns_name" {
  description = "El nombre DNS del Application Load Balancer."
  value       = aws_lb.main.dns_name
}

# --- Salida del Endpoint de RDS ---
# Muestra el endpoint de conexión para la base de datos RDS.
output "rds_endpoint" {
  description = "El endpoint de la instancia de RDS."
  value       = aws_db_instance.main.endpoint
}

# --- Salida del Nombre del Bucket S3 ---
# Muestra el nombre del bucket S3 creado para las fotos.
output "s3_bucket_name" {
  description = "El nombre del bucket S3 para las fotos."
  value       = aws_s3_bucket.photos-bucket.bucket
}
