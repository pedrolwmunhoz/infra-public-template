#!/usr/bin/env bash
set -euo pipefail

# Script para configurar o template infra-public-template
# Troca dominio, nomes de servico, usuarios e secrets em TODOS os arquivos relevantes.

ROOT_DIR="$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)"

# --- CONFIG: altere aqui UMA VEZ ---
# Dominio base (sem subdominio)
DOMAIN=\"seudominio.com\"

# Nomes dos services/applications
SERVICE_NAME=\"myservice-api\"   # backend
FRONT_NAME=\"myfront-app\"       # frontend

# Docker Hub
DOCKERHUB_USERNAME=\"your-dockerhub-user\"
DOCKERHUB_REPO_BACK=\"myservice-api\"
DOCKERHUB_REPO_FRONT=\"myfront-app\"

# GitHub
GITHUB_USER=\"your-github-username\"
GITHUB_REPO_BACK=\"myservice-api\"
GITHUB_REPO_FRONT=\"\"           # opcional: preencha se tiver repo separado do frontend

# Senhas
ARGOCD_PASS=\"CHANGE_ME_ADMIN_PASSWORD\"
GRAFANA_PASS=\"CHANGE_ME_GRAFANA_PASSWORD\"

echo \"== Configurar template infra-public (usando CONFIG do topo) ==\"
echo \"Aplicando configuracoes...\"

### bootstrap.sh
BOOT="$ROOT_DIR/bootstrap/bootstrap.sh"

sed -i "s/^DOMAIN=\".*\"/DOMAIN=\"$DOMAIN\"/" "$BOOT"
sed -i "s/^ARGOCD_SENHA_PADRAO=\".*\"/ARGOCD_SENHA_PADRAO=\"$ARGOCD_PASS\"/" "$BOOT"
sed -i "s/^GRAFANA_ADMIN_PASSWORD=\".*\"/GRAFANA_ADMIN_PASSWORD=\"$GRAFANA_PASS\"/" "$BOOT"

sed -i "s/^DOCKERHUB_USERNAME=\".*\"/DOCKERHUB_USERNAME=\"$DOCKERHUB_USERNAME\"/" "$BOOT"

sed -i "s/^GIT_USERNAME=\".*\"/GIT_USERNAME=\"$GITHUB_USER\"/" "$BOOT"

sed -i "s/myservice-api|https:\/\/github.com\/[^|]*\/[^|]*.git|k8s\/backend|main|CreateNamespace=true|api/$SERVICE_NAME|https:\/\/github.com\/$GITHUB_USER\/$GITHUB_REPO_BACK.git|k8s\/backend|main|CreateNamespace=true|api/" "$BOOT"

if [[ -n "${GITHUB_REPO_FRONT:-}" ]]; then
  # descomenta e ajusta a linha do frontend se o usuario quiser
  sed -i "s/# \"myfront-app|https:\/\/github.com\/your-github-username\/myfront-app.git|k8s\/frontend|main||app\"/\"$FRONT_NAME|https:\/\/github.com\/$GITHUB_USER\/$GITHUB_REPO_FRONT.git|k8s\/frontend|main||app\"/" "$BOOT"
fi

### k8s backend
KB="$ROOT_DIR/k8s/backend"

sed -i "s/myservice-api/$SERVICE_NAME/g" "$KB/deployment.yaml" "$KB/service.yaml" "$KB/ingress.yaml" "$ROOT_DIR/k8s/README.md"
sed -i "s/your-dockerhub-user\/myservice-api/$DOCKERHUB_USERNAME\/$DOCKERHUB_REPO_BACK/g" "$KB/deployment.yaml" "$ROOT_DIR/k8s/README.md"
sed -i "s/myservice-api-secret/${SERVICE_NAME}-secret/g" "$KB/deployment.yaml" "$ROOT_DIR/k8s/README.md"

sed -i "s/api.seudominio.com/api.$DOMAIN/g" "$KB/ingress.yaml" "$ROOT_DIR/k8s/README.md"
sed -i "s/api-seudominio-com-tls/api-${DOMAIN//./-}-tls/g" "$KB/ingress.yaml"

### k8s frontend
KF="$ROOT_DIR/k8s/frontend"

sed -i "s/myfront-app/$FRONT_NAME/g" "$KF/deployment.yaml" "$KF/service.yaml" "$KF/ingress.yaml" "$ROOT_DIR/k8s/README.md"
sed -i "s/your-dockerhub-user\/myfront-app/$DOCKERHUB_USERNAME\/$DOCKERHUB_REPO_FRONT/g" "$KF/deployment.yaml" "$ROOT_DIR/k8s/README.md"

sed -i "s/app.seudominio.com/app.$DOMAIN/g" "$KF/ingress.yaml" "$ROOT_DIR/k8s/README.md"
sed -i "s/app-seudominio-com-tls/app-${DOMAIN//./-}-tls/g" "$KF/ingress.yaml"

### Workflow
WF="$ROOT_DIR/.github/workflows/docker-build.yml"

sed -i "s/myservice-api/$SERVICE_NAME/g" "$WF"
sed -i "s/DOCKERHUB_USERNAME }\/myservice-api/DOCKERHUB_USERNAME }\/$DOCKERHUB_REPO_BACK/g" "$WF"

echo "OK. Template configurado com:"
echo "  DOMAIN         = $DOMAIN"
echo "  SERVICE_NAME   = $SERVICE_NAME"
echo "  FRONT_NAME     = $FRONT_NAME"
echo "  DOCKERHUB_USER = $DOCKERHUB_USERNAME"
