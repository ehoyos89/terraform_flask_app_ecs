# Crear un bucket S3 para almacenar las fotos de perfil de la aplicación
resource "aws_s3_bucket" "photos-bucket" {
  bucket = "${var.project_name}-photos-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-photos-bucket"
    Project = var.project_name
  }
}

# Bloquear el acceso público al bucket
resource "aws_s3_bucket_public_access_block" "photos-bucket-block" {
  bucket = aws_s3_bucket.photos-bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ID aleatorio para el bucket
resource "random_id" "bucket_suffix" {
  byte_length = 4
}