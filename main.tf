# ==============================================================================
# ARCHIVO PRINCIPAL DE TERRAFORM
# ==============================================================================
# Este archivo contiene la configuración central del proveedor de AWS y la 
# configuración del backend de Terraform, que gestiona el estado remoto.
# ------------------------------------------------------------------------------

# --- Configuración del Proveedor de AWS ---
# Define el proveedor que Terraform usará (en este caso, AWS) y asegura que
# se utilice una versión compatible para mantener la estabilidad del código.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --- Configuración del Proveedor ---
# Especifica la región de AWS donde se crearán todos los recursos definidos
# en este proyecto. El valor se toma de variables.tf.
provider "aws" {
  region = var.aws_region
}
