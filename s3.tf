# ==============================================================================
# CONFIGURACIÓN DEL BUCKET S3
# ==============================================================================
# Este archivo define el bucket de S3 que la aplicación utilizará para 
# almacenar archivos, como las fotos de perfil de los empleados.
# ------------------------------------------------------------------------------

# --- Creación del Bucket S3 ---
# Define un bucket de S3 con un nombre único generado a partir del nombre del
# proyecto y un sufijo aleatorio para evitar colisiones de nombres.
resource "aws_s3_bucket" "photos-bucket" {
  bucket = "${var.project_name}-photos-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-photos-bucket"
    Project = var.project_name
  }
}

# --- Bloqueo de Acceso Público ---
# Aplica configuraciones de seguridad para asegurar que el contenido del bucket
# no sea accesible públicamente por defecto.
resource "aws_s3_bucket_public_access_block" "photos-bucket-block" {
  bucket = aws_s3_bucket.photos-bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# --- Sufijo Aleatorio para el Nombre del Bucket ---
# Genera una cadena hexadecimal aleatoria para añadir al nombre del bucket,
# garantizando que sea globalmente único.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}
