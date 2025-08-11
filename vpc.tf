
# ==============================================================================
# CONFIGURACIÓN DE LA RED (VPC)
# ==============================================================================
# Este archivo define la Virtual Private Cloud (VPC), subredes, gateways y 
# tablas de enrutamiento que forman la red para la aplicación.
# ------------------------------------------------------------------------------

# --- Creación de la VPC ---
# Define la red principal aislada en la nube.
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ------------------------------------------------------------------------------
# Subredes
# ------------------------------------------------------------------------------

# --- Subredes Públicas ---
# Estas subredes tienen acceso directo a Internet. Aquí se alojará el 
# Balanceador de Carga (ALB).
resource "aws_subnet" "public" {
  count             = length(var.public_subnets_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets_cidr[count.index]
  availability_zone = tolist(data.aws_availability_zones.available.names)[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# --- Subredes Privadas ---
# Estas subredes no tienen acceso directo desde Internet, proporcionando un
# entorno seguro para los contenedores de la aplicación y la base de datos.
resource "aws_subnet" "private" {
  count             = length(var.private_subnets_cidr)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidr[count.index]
  availability_zone = tolist(data.aws_availability_zones.available.names)[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# ------------------------------------------------------------------------------
# Gateways de Red
# ------------------------------------------------------------------------------

# --- Internet Gateway (IGW) ---
# Permite la comunicación entre la VPC y el internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# --- NAT Gateway ---
# Permite a las instancias en subredes privadas iniciar tráfico hacia 
# Internet (ej. para descargar actualizaciones) sin permitir conexiones entrantes.
resource "aws_eip" "nat" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------------------------
# Tablas de Enrutamiento
# ------------------------------------------------------------------------------

# --- Tabla de Rutas Públicas ---
# Dirige el tráfico de las subredes públicas hacia el Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Tabla de Rutas Privadas ---
# Dirige el tráfico de las subredes privadas hacia el NAT Gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------------------------
# Orígenes de Datos (Data Sources)
# ------------------------------------------------------------------------------

# --- Zonas de Disponibilidad ---
# Obtiene una lista de las zonas de disponibilidad disponibles en la región actual
# para distribuir los recursos y aumentar la resiliencia.
data "aws_availability_zones" "available" {
  state = "available"
}
