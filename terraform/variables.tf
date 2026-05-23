variable "aws_region" {
    description = "Região da AWS onde os recursos são criados"
    type        = string
    default     = "us-east-1"
}

variable "app_name" {
    description = "Nome da aplicação"
    type        = string
    default     = "trainee-api"
}

variable "container_port" {
  description = "Porta que o container expõe"
  type        = number
  default     = 5000
}

variable "container_image" {
  description = "Imagem Docker a ser utilizada"
  type        = string
  default     = "registry.gitlab.com/seu-usuario/trainee-devops:latest"
}

variable "desired_count" {
  description = "Número de instâncias do container rodando simultaneamente"
  type        = number
  default     = 1
}