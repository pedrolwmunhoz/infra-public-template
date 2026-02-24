# Deploy de exemplo no Kubernetes (ArgoCD + Docker Hub)

Este `k8s/` é um **template genérico** para uma API (`{SERVICE_NAME}`) e um frontend (`{FRONT_NAME}`).

## Fluxo resumido

1. Push em `main` no repositório da app → GitHub Actions builda a imagem e envia para **Docker Hub** (`{GH_SECRET_DOCKERHUB_USER}/{DOCKERHUB_REPO_BACK}:tag`).
2. ArgoCD lê o repo Git com os manifests (`k8s/backend` e `k8s/frontend`) e aplica no cluster (k3s com Traefik).

> **Importante:** o domínio real vem do `DOMAIN` configurado no `bootstrap.sh` genérico  
> (ex.: `DOMAIN={BASE_DOMAIN}` → `api.{BASE_DOMAIN}`, `app.{BASE_DOMAIN}`).

## Layout dos manifests

- `backend/` → API (`{SERVICE_NAME}`)
  - `deployment.yaml` → Deployment da API, container porta 8081, image `{GH_SECRET_DOCKERHUB_USER}/{DOCKERHUB_REPO_BACK}:latest`, envs vindas de `{SERVICE_NAME}-secret`.
  - `service.yaml`    → Service ClusterIP `{SERVICE_NAME}`, porta 80 → targetPort 8081.
  - `ingress.yaml`    → Ingress Traefik para `https://api.{BASE_DOMAIN}`.
  - `rate-limit-middleware.yaml` → Middleware Traefik de rate limit para a API.

- `frontend/` → Frontend (`{FRONT_NAME}`)
  - `deployment.yaml` → Deployment do frontend (Nginx), porta 80, image `{GH_SECRET_DOCKERHUB_USER}/{DOCKERHUB_REPO_FRONT}:latest`.
  - `service.yaml`    → Service ClusterIP `{FRONT_NAME}`, porta 80 → targetPort 80.
  - `ingress.yaml`    → Ingress Traefik para `https://app.{BASE_DOMAIN}`.
  - `rate-limit-middleware.yaml` → Middleware Traefik de rate limit para o frontend.

> O `Dockerfile.frontend` foi pensado pra **qualquer SPA** (React, Vite, Vue, etc.) que:
> - tenha script `npm run build`, e
> - gere os arquivos estáticos em `dist/`.  
> Se o seu build gerar em outra pasta (ex.: `build/` do CRA), é só ajustar o caminho do `COPY` no Dockerfile.

## Services e portas

- **API (`{SERVICE_NAME}`):**
  - Container: escuta em **8081**
  - Service: expõe **80** e encaminha para `targetPort: 8081`

- **Frontend (`{FRONT_NAME}`):**
  - Container: escuta em **80** (Nginx)
  - Service: expõe **80** e encaminha para `targetPort: 80`

