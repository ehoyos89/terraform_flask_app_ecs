# Proyecto de Despliegue de Aplicación Flask en AWS con Terraform

Este proyecto contiene el código de infraestructura como código (IaC) utilizando Terraform para aprovisionar y desplegar una aplicación web Flask en Amazon Web Services (AWS). La arquitectura está diseñada siguiendo las mejores prácticas de seguridad y escalabilidad, utilizando servicios administrados para minimizar la sobrecarga operativa.

Este proyecto asume que **ya has construido tu imagen de contenedor de la aplicación y la has subido a un repositorio de Amazon ECR existente**.

## Arquitectura

La infraestructura creada por este proyecto de Terraform consta de los siguientes componentes:

1.  **Red (VPC):**
    *   Una **Virtual Private Cloud (VPC)** para aislar los recursos de la red.
    *   **Subredes Públicas y Privadas** en dos zonas de disponibilidad para alta disponibilidad.
    *   Un **Internet Gateway** para permitir el acceso a Internet a los recursos en las subredes públicas.
    *   Un **NAT Gateway** para permitir que los recursos en las subredes privadas (como los contenedores de ECS) inicien conexiones a Internet sin estar expuestos directamente.

2.  **Contenedores (ECS):**
    *   **Amazon Elastic Container Service (ECS) con Fargate:** Un clúster de ECS para orquestar la ejecución de los contenedores de la aplicación. Se utiliza el tipo de lanzamiento Fargate para una experiencia sin servidor, eliminando la necesidad de gestionar instancias EC2.
    *   **Definición de Tarea y Servicio de ECS:** Definen cómo se debe ejecutar la aplicación, incluyendo la URL de la imagen a usar, los recursos de CPU/memoria, y la configuración de red. El servicio se encarga de mantener el número deseado de tareas en ejecución.

3.  **Base de Datos (RDS):**
    *   **Amazon Relational Database Service (RDS):** Una instancia de base de datos MySQL administrada, desplegada en las subredes privadas para mayor seguridad.
    *   **AWS Secrets Manager:** Para almacenar de forma segura la contraseña de la base de datos y pasarla a la aplicación sin exponerla en el código.

4.  **Seguridad y Redireccionamiento:**
    *   **Application Load Balancer (ALB):** Un balanceador de carga que distribuye el tráfico HTTP entrante a las tareas de ECS.
    *   **Grupos de Seguridad:** Reglas de firewall detalladas que controlan el tráfico entre el ALB, los contenedores de ECS y la base de datos RDS, siguiendo el principio de mínimo privilegio.
    *   **Roles de IAM:** Permisos específicos para que los servicios de ECS puedan interactuar con otros servicios de AWS (como ECR y CloudWatch) de forma segura.

## Requisitos Previos

Antes de comenzar, asegúrate de tener instaladas las siguientes herramientas:

*   **Terraform:** [Guía de instalación oficial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
*   **AWS CLI:** [Guía de instalación oficial](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
*   **Docker:** [Guía de instalación oficial](https://docs.docker.com/engine/install/)

También necesitarás configurar tus credenciales de AWS para que Terraform y la AWS CLI puedan interactuar con tu cuenta.

## Cómo Usar este Proyecto

Sigue estos pasos para desplegar la infraestructura y la aplicación:

### 1. Construir y Subir la Imagen Docker a ECR (Paso Previo)

Este proyecto asume que ya tienes una imagen de tu aplicación en un repositorio de ECR. Si no es así, sigue estos pasos:

1.  **Crea un repositorio en ECR** a través de la consola de AWS o la AWS CLI.
2.  **Construye tu imagen Docker:**
    ```bash
    docker build -t <nombre-de-tu-repo-ecr>:latest .
    ```
3.  **Autentica Docker en ECR:**
    ```bash
    aws ecr get-login-password --region <tu-region> | docker login --username AWS --password-stdin <tu-id-de-cuenta>.dkr.ecr.<tu-region>.amazonaws.com
    ```
4.  **Sube la imagen a ECR:**
    ```bash
    docker push <nombre-de-tu-repo-ecr>:latest
    ```
5.  **Copia la URI de la imagen.** La necesitarás en el siguiente paso.

### 2. Inicializar Terraform

Navega al directorio raíz del proyecto y ejecuta `terraform init` para descargar los proveedores necesarios.

```bash
terraform init
```

### 3. Configurar Variables

Edita el archivo `terraform.tfvars` para personalizar las variables del proyecto. Deberás proporcionar la URL completa de tu imagen de ECR y una contraseña para la base de datos.

```hcl
aws_region    = "us-east-1"
project_name  = "ecs-flask-app"
db_password   = "tu-contraseña-segura"
ecr_image_url = "<tu-id-de-cuenta>.dkr.ecr.<tu-region>.amazonaws.com/<nombre-de-tu-repo-ecr>:latest"
```

### 4. Planificar y Aplicar la Infraestructura

Primero, ejecuta `terraform plan` para ver los recursos que se crearán.

```bash
terraform plan
```

Si el plan es correcto, ejecuta `terraform apply` para crear la infraestructura en AWS. Se te pedirá que confirmes la acción.

```bash
terraform apply
```

### 5. Acceder a la Aplicación

Una vez que Terraform termine, el servicio de ECS descargará tu imagen de ECR y la ejecutará automáticamente. Puedes acceder a tu aplicación a través del DNS del balanceador de carga, que puedes obtener de las salidas de Terraform:

```bash
terraform output alb_dns_name
```

Pega la URL en tu navegador y deberías ver el mensaje de bienvenida de la aplicación Flask.

## Limpieza

Para destruir toda la infraestructura y evitar costos adicionales, ejecuta el siguiente comando:

```bash
terraform destroy
```

Se te pedirá que confirmes la acción. Una vez confirmada, Terraform eliminará todos los recursos creados.