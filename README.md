# Infraestructura como Código para Aplicación Flask en AWS ECS Fargate

## 1. Resumen Técnico

Este proyecto utiliza Terraform para aprovisionar una arquitectura robusta y escalable en AWS para el despliegue de una aplicación web contenedorizada (Flask). La infraestructura se gestiona completamente como código, implementando las mejores prácticas de seguridad, alta disponibilidad y automatización de CI/CD.

La arquitectura resultante consiste en una aplicación serverless ejecutándose en **AWS Fargate**, dentro de una red privada, con una base de datos relacional **RDS (MySQL)** y un pipeline de **AWS CodePipeline** que automatiza el ciclo de vida de desarrollo desde el commit hasta el despliegue.

## 2. Arquitectura Detallada

### 2.1. Red (VPC)

- **VPC**: Se crea una VPC con un CIDR block configurable (default: `10.0.0.0/16`).
- **Subredes**: La VPC se distribuye en dos Zonas de Disponibilidad (AZs) para alta disponibilidad.
  - **2 Subredes Públicas**: Alojan el Application Load Balancer y el NAT Gateway. Tienen una ruta directa al Internet Gateway.
  - **2 Subredes Privadas**: Alojan las tareas de ECS Fargate y la instancia de RDS, garantizando que no sean accesibles directamente desde Internet.
- **Gateways**:
  - **Internet Gateway (IGW)**: Provee acceso a Internet a las subredes públicas.
  - **NAT Gateway**: Se aprovisiona con una IP Elástica en una de las subredes públicas. Permite a los recursos en las subredes privadas (ej. tareas de ECS) iniciar conexiones salientes a Internet (ej. para consumir APIs o descargar dependencias) sin exponerlos a conexiones entrantes.
- **Enrutamiento**: Se configuran tablas de rutas para dirigir el tráfico `0.0.0.0/0` de las subredes públicas al IGW y el de las privadas al NAT Gateway.

### 2.2. Computación (ECS Fargate)

- **ECS Cluster**: Un clúster lógico que agrupa los servicios y tareas de la aplicación.
- **Application Load Balancer (ALB)**:
  - Se despliega en las subredes públicas.
  - Un *listener* en el puerto 80 (HTTP) redirige el tráfico a un *target group*.
  - El *target group* apunta a las IPs de las tareas de Fargate en el puerto 5000 y realiza *health checks* en la ruta `/`.
- **ECS Task Definition**:
  - **Launch Type**: `FARGATE`, eliminando la necesidad de gestionar instancias EC2.
  - **CPU/Memoria**: Configurable (default: 256 CPU units / 512 MiB Memory).
  - **Container Definition**:
    - **Imagen**: Obtenida del repositorio ECR gestionado por el pipeline (`aws_ecr_repository.app_ecr_repo`).
    - **Variables de Entorno**: Se inyectan el `DATABASE_HOST` (endpoint de RDS), `DATABASE_DB_NAME` y `PHOTOS_BUCKET`.
    - **Gestión de Secretos**: Las credenciales de la base de datos (`DATABASE_USER`, `DATABASE_PASSWORD`) y la `FLASK_SECRET` se inyectan de forma segura desde **AWS Secrets Manager**, evitando la exposición de datos sensibles.
    - **Logging**: Los logs del contenedor se centralizan en un grupo de **CloudWatch Logs** (`/ecs/project-name`).
- **ECS Service**:
  - Mantiene el número deseado de tareas (default: 1).
  - Asocia las tareas con el ALB y asegura que se registren en el *target group*.
  - Despliega las tareas en las subredes privadas.
  - **ECS Exec** está habilitado (`enable_execute_command = true`) para permitir la depuración mediante un shell interactivo dentro del contenedor.

### 2.3. Base de Datos (RDS)

- **Instancia**: Se aprovisiona una instancia `db.t4g.micro` con motor **MySQL 8.0**.
- **Almacenamiento**: `gp3` con cifrado en reposo (`storage_encrypted = true`).
- **Red**: La instancia se despliega en un `DB Subnet Group` que abarca las subredes privadas.
- **Gestión de Credenciales**: La contraseña maestra se genera aleatoriamente (`random_password`) y se almacena en **AWS Secrets Manager**. La configuración de la instancia de RDS y la definición de tarea de ECS referencian este secreto.
- **Inicialización de Esquema**: Se utiliza un `null_resource` con un provisioner `local-exec` para orquestar una tarea de ECS (`db_init`) de un solo uso. Esta tarea se ejecuta post-aprovisionamiento de RDS, utilizando una imagen `mysql:8.0` para ejecutar el script `init.sql` y crear el esquema inicial de la base de datos.

### 2.4. Almacenamiento (S3)

- **Bucket S3**: Se crea un bucket para uso de la aplicación (ej. almacenamiento de imágenes). El nombre se genera con un sufijo aleatorio (`random_id`) para garantizar unicidad global.
- **Seguridad**: El acceso público está explícitamente bloqueado a nivel de bucket (`aws_s3_bucket_public_access_block`).

### 2.5. Seguridad (IAM y Security Groups)

- **Security Groups (Firewall)**:
  - **ALB SG**: Permite tráfico entrante en el puerto 80/TCP desde `0.0.0.0/0`.
  - **ECS Tasks SG**: Permite tráfico entrante en el puerto 5000/TCP únicamente desde el Security Group del ALB.
  - **RDS SG**: Permite tráfico entrante en el puerto 3306/TCP únicamente desde el Security Group de las tareas de ECS.
- **Roles de IAM (Principio de Mínimo Privilegio)**:
  - **ECSTaskExecutionRole**: Rol estándar para el agente de ECS, con políticas para extraer imágenes de ECR y leer secretos de Secrets Manager. Se adjunta una política en línea para acceder a los secretos específicos del proyecto.
  - **ECSTaskRole**: Rol para la aplicación. Se le otorgan permisos explícitos para `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` en el bucket de la aplicación y permisos para la funcionalidad de ECS Exec.

### 2.6. CI/CD Pipeline (AWS CodePipeline)

- **ECR Repository**: Se crea un repositorio para almacenar las imágenes Docker de la aplicación. El escaneo de vulnerabilidades al subir una imagen está activado (`scan_on_push = true`).
- **CodeStar Connection**: Se define una conexión a un repositorio de GitHub. Requiere una única configuración manual en la consola de AWS tras el primer despliegue.
- **Pipeline Stages**:
  1.  **Source**: Se activa automáticamente ante un `push` a la rama `main` del repositorio conectado.
  2.  **Build**: Utiliza **AWS CodeBuild** con un entorno `standard:7.0` en modo privilegiado para la construcción de imágenes Docker. El proceso se define en un archivo `buildspec.yml` (no incluido en este repo), que debe encargarse de:
      - Autenticarse en ECR.
      - Construir y etiquetar la imagen Docker.
      - Subir la imagen a ECR.
      - Generar un artefacto `imagedefinitions.json` para la etapa de despliegue.
  3.  **Deploy**: Utiliza la acción nativa de ECS para actualizar el servicio con la nueva definición de imagen contenida en el artefacto de la etapa de Build.
- **IAM Roles**: Se crean roles específicos para CodePipeline y CodeBuild con permisos acotados para sus respectivas funciones.

## 3. Uso y Despliegue

### 3.1. Prerrequisitos

- **Terraform** (~> 5.0)
- **AWS CLI**
- **Docker** (para desarrollo local)
- Credenciales de AWS configuradas.

### 3.2. Configuración

1.  Clonar el repositorio.
2.  Crear un archivo `terraform.tfvars` para definir las variables de entrada. Como mínimo, se deben configurar las variables marcadas como `sensitive` en `variables.tf`.

    ```hcl
    # Ejemplo de terraform.tfvars
    aws_region  = "us-east-1"
    project_name = "mi-proyecto-flask"
    db_name      = "flaskdb"
    db_username  = "admin"
    ```

### 3.3. Comandos de Despliegue

1.  **Inicializar Terraform**:
    ```bash
    terraform init
    ```
2.  **Planificar Cambios**:
    ```bash
    terraform plan
    ```
3.  **Aplicar Infraestructura**:
    ```bash
    terraform apply
    ```

### 3.4. Configuración Post-Despliegue

- **Conexión de CI/CD**: Navegar a **AWS CodePipeline** en la consola, localizar el pipeline creado y completar el handshake de la conexión de CodeStar con el repositorio de GitHub.
- **Repositorio de Aplicación**: Asegurarse de que el repositorio de la aplicación contiene un `Dockerfile` y un `buildspec.yml` compatibles con el pipeline.

### 3.5. Salidas (Outputs)

Una vez completado el despliegue, Terraform mostrará las siguientes salidas:

- `alb_dns_name`: La URL para acceder a la aplicación.
- `rds_endpoint`: El endpoint de la base de datos RDS.
- `s3_bucket_name`: El nombre del bucket S3 creado.

### 3.6. Destrucción de la Infraestructura

Para eliminar todos los recursos aprovisionados y evitar costos, ejecutar:

```bash
terraform destroy
```