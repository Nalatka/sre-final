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

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace
  }

  depends_on = [
    null_resource.minikube_addons
  ]
}

resource "kubernetes_config_map" "app" {
  metadata {
    name      = "${var.project_name}-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    NODE_ENV     = "production"
    PORT         = "5000"
    MONGODB_URI  = "mongodb://mongo:27017/${var.database_name}"
    FRONTEND_URL = var.frontend_urls
  }
}

resource "kubernetes_secret" "app" {
  metadata {
    name      = "${var.project_name}-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    JWT_SECRET = var.jwt_secret
  }

  type = "Opaque"
}

resource "kubernetes_persistent_volume_claim" "mongo_data" {
  metadata {
    name      = "mongo-data"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "mongo" {
  metadata {
    name      = "mongo"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mongo"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongo"
        }
      }

      spec {
        container {
          name  = "mongo"
          image = "mongo:7.0"

          port {
            container_port = 27017
          }

          volume_mount {
            name       = "mongo-data"
            mount_path = "/data/db"
          }
        }

        volume {
          name = "mongo-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mongo_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          name              = "backend"
          image             = var.backend_image_name
          image_pull_policy = "Never"

          port {
            container_port = 5000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.app.metadata[0].name
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 5000
            }

            initial_delay_seconds = 10
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 5000
            }

            initial_delay_seconds = 30
            period_seconds        = 20
          }
        }
      }
    }
  }

  depends_on = [
    null_resource.backend_image,
    kubernetes_deployment.mongo
  ]
}

resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          name              = "frontend"
          image             = var.frontend_image_name
          image_pull_policy = "Never"

          port {
            container_port = 80
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }

            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }

            initial_delay_seconds = 20
            period_seconds        = 20
          }
        }
      }
    }
  }

  depends_on = [
    null_resource.frontend_image,
    kubernetes_deployment.backend
  ]
}

resource "kubernetes_service" "mongo" {
  metadata {
    name      = "mongo"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "mongo"
    }

    port {
      port        = 27017
      target_port = 27017
    }
  }
}

resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "backend"
    }

    port {
      port        = 5000
      target_port = 5000
    }
  }
}

resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "frontend"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = var.project_name
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    rule {
      host = var.app_hostname

      http {
        path {
          path      = "/api"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.backend.metadata[0].name

              port {
                number = 5000
              }
            }
          }
        }

        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.frontend.metadata[0].name

              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
