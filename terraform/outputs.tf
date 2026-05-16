output "minikube_profile" {
  value = var.minikube_profile
}

output "namespace" {
  value = var.namespace
}

output "application_url" {
  value = "http://${var.app_hostname}"
}

output "minikube_ip_command" {
  value = "minikube ip --profile ${var.minikube_profile}"
}

output "hosts_file_entry" {
  value = "<MINIKUBE_IP> ${var.app_hostname}"
}

output "check_pods_command" {
  value = "kubectl --context ${var.minikube_profile} get pods -n ${var.namespace}"
}
