# Deploy de exemplo no Kubernetes (ArgoCD + Docker Hub)

Este `k8s/` é um **template genérico** para uma API (`myservice-api`) e um frontend (`myfront-app`).

## Fluxo resumido

1. Push em `main` no repositório da app → GitHub Actions builda a imagem e envia para **Docker Hub** (`your-dockerhub-user/myservice-api:tag`).
2. ArgoCD lê o repo Git com os manifests (`k8s/backend` e `k8s/frontend`) e aplica no cluster (k3s com Traefik).

> **Importante:** o domínio real vem do `DOMAIN` configurado no `bootstrap.sh` genérico  
> (ex.: `DOMAIN=seudominio.com` → `api.seudominio.com`, `app.seudominio.com`).

## Layout dos manifests

- `backend/` → API (`myservice-api`)
  - `deployment.yaml` → Deployment da API, container porta 8081, image `your-dockerhub-user/myservice-api:latest`, envs vindas de `myservice-api-secret`.
  - `service.yaml`    → Service ClusterIP `myservice-api`, porta 80 → targetPort 8081.
  - `ingress.yaml`    → Ingress Traefik para `https://api.seudominio.com`.
  - `rate-limit-middleware.yaml` → Middleware Traefik de rate limit para a API.

- `frontend/` → Frontend (`myfront-app`)
  - `deployment.yaml` → Deployment do frontend (Nginx), porta 80, image `your-dockerhub-user/myfront-app:latest`.
  - `service.yaml`    → Service ClusterIP `myfront-app`, porta 80 → targetPort 80.
  - `ingress.yaml`    → Ingress Traefik para `https://app.seudominio.com`.
  - `rate-limit-middleware.yaml` → Middleware Traefik de rate limit para o frontend.

## Services e portas

- **API (`myservice-api`):**
  - Container: escuta em **8081**
  - Service: expõe **80** e encaminha para `targetPort: 8081`

- **Frontend (`myfront-app`):**
  - Container: escuta em **80** (Nginx)
  - Service: expõe **80** e encaminha para `targetPort: 80`

