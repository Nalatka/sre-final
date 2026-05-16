# Task Manager

Full-stack task management application with a React frontend, Express backend, MongoDB database, JWT authentication, role-based access control, and Prometheus metrics.

## Stack

- Frontend: React, Create React App, Axios, Nginx container
- Backend: Node.js, Express, Mongoose
- Database: MongoDB
- Infrastructure: Docker, Docker Compose, Terraform, Kubernetes
- Monitoring-ready: Prometheus metrics exposed by the backend at `/metrics`

## Repository Layout

```text
backend/
frontend/
k8s/
monitoring/
terraform/
docker-compose.yml
README.md
```

## Infrastructure Decisions

The frontend and backend are separate containers because they scale and deploy independently. The frontend image builds static React files and serves them with Nginx, which is closer to production than running the React development server.

MongoDB runs as its own container and Kubernetes deployment because the backend already uses Mongoose and needs a database service. For this capstone setup, MongoDB is kept simple with a local Docker volume or a Kubernetes PVC.

Docker Compose is used for local development and review because a teammate can start the full app with one command.

Terraform provisions a local Minikube Kubernetes environment. This keeps the project reproducible from scratch without paid cloud credentials while still matching the assignment requirement to deploy through a Kubernetes cluster.

Kubernetes manifests are plain YAML files split into deployments, services, and ingress. This keeps the cluster deployment easy to understand while still supporting automated rollout updates from the CI/CD pipeline.

## Run Locally With Docker Compose

Build and start the application:

```bash
docker compose up --build
```

Open:

- Frontend: `http://localhost:3000`
- Backend: `http://localhost:5000`
- Backend metrics: `http://localhost:5000/metrics`
- MongoDB: `localhost:27017`

Start optional database UI:

```bash
docker compose --profile tools up --build
```

Start optional monitoring services:

```bash
docker compose --profile monitoring up --build
```

Monitoring URLs:

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`
- Node exporter: `http://localhost:9100`

Stop the stack:

```bash
docker compose down
```

Remove local database data:

```bash
docker compose down -v
```

## Terraform Minikube Infrastructure

Terraform provisions the local Kubernetes environment using Minikube:

- Starts a Minikube cluster with the Docker driver
- Enables the ingress addon
- Enables the metrics-server addon
- Builds backend and frontend images inside Minikube
- Applies the Kubernetes manifests from `k8s/`

From the repository root:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

If you want to customize Minikube settings:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform apply
```

Useful Terraform variables:

```text
minikube_profile = "task-manager"
minikube_driver = "docker"
minikube_cpus = 2
minikube_memory = "4096mb"
backend_image_name = "task-manager-backend:latest"
frontend_image_name = "task-manager-frontend:latest"
```

After apply, check the cluster:

```bash
kubectl --context task-manager get pods -n task-manager
kubectl --context task-manager get services -n task-manager
kubectl --context task-manager get ingress -n task-manager
```

For ingress access, get the Minikube IP:

```bash
minikube ip --profile task-manager
```

On Windows with the Docker driver, keep this running in a separate Administrator terminal if the ingress IP is not reachable:

```bash
minikube tunnel --profile task-manager
```

Add this entry to your hosts file:

```text
<MINIKUBE_IP> task-manager.local
```

Then open:

```text
http://task-manager.local
```

If ingress is not reachable on your machine, use port forwarding:

```bash
kubectl --context task-manager port-forward -n task-manager service/frontend 3000:80
kubectl --context task-manager port-forward -n task-manager service/backend 5000:5000
```

Destroy the Terraform-managed Minikube environment:

```bash
terraform destroy
```

## Kubernetes Deployment

The manifests are in `k8s/`:

- `deployment.yaml`: namespace, config, secret, MongoDB PVC, MongoDB deployment, backend deployment, frontend deployment
- `service.yaml`: internal services for MongoDB, backend, and frontend
- `ingress.yaml`: routes `/api` to backend and `/` to frontend

Manual Minikube deployment without Terraform:

```bash
minikube start --profile task-manager --driver docker
minikube addons enable ingress --profile task-manager
minikube addons enable metrics-server --profile task-manager
minikube image build --profile task-manager -t task-manager-backend:latest ./backend
minikube image build --profile task-manager -t task-manager-frontend:latest --build-arg REACT_APP_API_URL=/api ./frontend
```

Apply manifests:

```bash
kubectl --context task-manager apply -f k8s/deployment.yaml
kubectl --context task-manager apply -f k8s/service.yaml
kubectl --context task-manager apply -f k8s/ingress.yaml
```

Check rollout status:

```bash
kubectl --context task-manager get pods -n task-manager
kubectl --context task-manager get services -n task-manager
kubectl --context task-manager get ingress -n task-manager
```

If your local cluster supports ingress, map the host to your ingress address:

```text
task-manager.local
```

On Windows with the Docker driver, you may need to run this in a separate Administrator terminal:

```bash
minikube tunnel --profile task-manager
```

Then open:

```text
http://task-manager.local
```

If ingress is not available, use port forwarding:

```bash
kubectl --context task-manager port-forward -n task-manager service/frontend 3000:80
kubectl --context task-manager port-forward -n task-manager service/backend 5000:5000
```

Delete the Kubernetes deployment:

```bash
kubectl --context task-manager delete -f k8s/ingress.yaml
kubectl --context task-manager delete -f k8s/service.yaml
kubectl --context task-manager delete -f k8s/deployment.yaml
```

## CI/CD Pipeline (Person 2 Scope)

The CI/CD pipeline is implemented in:

```text
.github/workflows/main.yml
```

Pipeline stages:

- `test` (push + PR to `main`): installs dependencies, runs backend syntax check, runs frontend tests, builds frontend
- `build-and-push` (push to `main`): builds backend and frontend images and pushes both to GHCR with `latest` and commit-SHA tags
- `deploy` (push to `main`): applies Kubernetes manifests, injects JWT secret from GitHub Secrets, performs rolling image update, waits for rollout status

Registry integration:

- Container registry: GitHub Container Registry (`ghcr.io`)
- Backend image: `ghcr.io/<owner>/<repo>/task-manager-backend:<tag>`
- Frontend image: `ghcr.io/<owner>/<repo>/task-manager-frontend:<tag>`
- Authentication: `${{ github.actor }}` and `${{ secrets.GITHUB_TOKEN }}`

Required GitHub repository secrets:

- `KUBE_CONFIG_DATA`: base64-encoded kubeconfig for the target cluster
- `JWT_SECRET`: production JWT secret for backend runtime

Encode kubeconfig for `KUBE_CONFIG_DATA`:

Linux/macOS:

```bash
cat ~/.kube/config | base64 -w 0
```

Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\.kube\config"))
```

Manual trigger option:

- `workflow_dispatch` is enabled for manual reruns from the Actions tab

Evidence checklist for report/defense:

- Screenshot of successful GitHub Actions run with `test`, `build-and-push`, and `deploy` jobs green
- Screenshot from GHCR Packages showing both backend and frontend images with SHA tags
- Screenshot from deploy logs showing successful rollout (`rollout status` success)

## Environment Variables

Backend:

- `NODE_ENV`
- `PORT`
- `MONGODB_URI`
- `JWT_SECRET`
- `FRONTEND_URL`

Frontend:

- `REACT_APP_API_URL`

For Docker Compose, local development defaults are already provided in `docker-compose.yml`.

For Terraform, customize values in `terraform/terraform.tfvars`.

For Kubernetes, update `k8s/deployment.yaml` before applying to a shared cluster. Replace `JWT_SECRET` with a strong value.

## Production Readiness Notes

This setup is intentionally simple and suitable for a university SRE capstone. The next production-readiness improvements are:

- TLS for ingress
- External secret manager integration (for example Vault, AWS Secrets Manager, or GCP Secret Manager)
- Container vulnerability scanning (for example Trivy in CI)
- Kubernetes resource requests and limits after measuring real usage
- Centralized logging
- Grafana dashboards and alert routing
- Database backup and restore procedure
