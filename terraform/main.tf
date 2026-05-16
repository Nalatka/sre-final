locals {
  kube_context = var.minikube_profile
}

resource "null_resource" "minikube_cluster" {
  triggers = {
    profile = var.minikube_profile
    driver  = var.minikube_driver
    cpus    = tostring(var.minikube_cpus)
    memory  = var.minikube_memory
  }

  provisioner "local-exec" {
    command = "minikube start --profile ${self.triggers.profile} --driver ${self.triggers.driver} --cpus ${self.triggers.cpus} --memory ${self.triggers.memory}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "minikube delete --profile ${self.triggers.profile}"
  }
}

resource "null_resource" "minikube_addons" {
  triggers = {
    profile = var.minikube_profile
  }

  provisioner "local-exec" {
    command = "minikube addons enable ingress --profile ${self.triggers.profile}"
  }

  provisioner "local-exec" {
    command = "minikube addons enable metrics-server --profile ${self.triggers.profile}"
  }

  depends_on = [
    null_resource.minikube_cluster
  ]
}

resource "null_resource" "backend_image" {
  triggers = {
    image       = var.backend_image_name
    dockerfile  = filesha256("${path.module}/../backend/Dockerfile")
    package     = filesha256("${path.module}/../backend/package.json")
    packageLock = filesha256("${path.module}/../backend/package-lock.json")
    server      = filesha256("${path.module}/../backend/server.js")
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "& minikube -p ${var.minikube_profile} docker-env --shell powershell | Invoke-Expression; docker build -t ${self.triggers.image} ../backend"
  }

  depends_on = [
    null_resource.minikube_cluster
  ]
}

resource "null_resource" "frontend_image" {
  triggers = {
    image       = var.frontend_image_name
    api_url     = var.frontend_api_url
    dockerfile  = filesha256("${path.module}/../frontend/Dockerfile")
    nginx       = filesha256("${path.module}/../frontend/nginx.conf")
    package     = filesha256("${path.module}/../frontend/package.json")
    packageLock = filesha256("${path.module}/../frontend/package-lock.json")
    app         = filesha256("${path.module}/../frontend/src/App.js")
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "& minikube -p ${var.minikube_profile} docker-env --shell powershell | Invoke-Expression; docker build -t ${self.triggers.image} ../frontend"
  }

  depends_on = [
    null_resource.minikube_cluster
  ]
}

resource "null_resource" "kubernetes_manifests" {
  triggers = {
    context    = local.kube_context
    namespace  = var.namespace
    deployment = filesha256("${path.module}/../k8s/deployment.yaml")
    service    = filesha256("${path.module}/../k8s/service.yaml")
    ingress    = filesha256("${path.module}/../k8s/ingress.yaml")
  }

  provisioner "local-exec" {
    command = "kubectl --context ${self.triggers.context} apply -f ../k8s/deployment.yaml -f ../k8s/service.yaml -f ../k8s/ingress.yaml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl --context ${self.triggers.context} delete -f ../k8s/ingress.yaml -f ../k8s/service.yaml -f ../k8s/deployment.yaml --ignore-not-found=true"
  }

  depends_on = [
    null_resource.minikube_addons,
    null_resource.backend_image,
    null_resource.frontend_image
  ]
}
