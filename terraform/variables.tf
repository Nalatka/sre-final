variable "project_name" {
  type    = string
  default = "task-manager"
}

variable "minikube_profile" {
  type    = string
  default = "task-manager"
}

variable "minikube_driver" {
  type    = string
  default = "docker"
}

variable "minikube_cpus" {
  type    = number
  default = 2
}

variable "minikube_memory" {
  type    = string
  default = "4096mb"
}

variable "namespace" {
  type    = string
  default = "task-manager"
}

variable "backend_image_name" {
  type    = string
  default = "task-manager-backend:latest"
}

variable "frontend_image_name" {
  type    = string
  default = "task-manager-frontend:latest"
}

variable "frontend_api_url" {
  type    = string
  default = "/api"
}

variable "app_hostname" {
  type    = string
  default = "task-manager.local"
}
