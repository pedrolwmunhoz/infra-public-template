#!/usr/bin/env bash
set -euo pipefail

# Script para configurar o template infra-public-template
# Troca dominio, nomes de servico, usuarios e secrets em TODOS os arquivos relevantes.

# --- CONFIG: altere aqui UMA VEZ ---
# Dominio base (sem subdominio)
DOMAIN="seudominio.com"

# Nomes dos services/applications
SERVICE_NAME="myservice-api"   # backend
FRONT_NAME="myfront-app"       # frontend

# Docker Hub
DOCKERHUB_USERNAME="your-dockerhub-user"
DOCKERHUB_REPO_BACK="myservice-api"
DOCKERHUB_REPO_FRONT="myfront-app"
DOCKERHUB_TOKEN=""              # opcional: se quiser já injetar o PAT nos arquivos/template
# Nome do secret no GitHub Actions (workflow: esse placeholder vira o nome do secret)
GH_SECRET_DOCKERHUB_USER="DOCKERHUB_USERNAME"
GH_SECRET_DOCKERHUB_TOKEN="DOCKERHUB_TOKEN"

# GitHub (usado tanto para os repos quanto para credencial Git do ArgoCD)
GITHUB_USER="your-github-username"
GITHUB_REPO_BACK="myservice-api"
GITHUB_REPO_FRONT=""           # opcional: preencha se tiver repo separado do frontend
GIT_TOKEN=""                   # opcional: PAT do GitHub para ArgoCD acessar repos privados

# Senhas
ARGOCD_PASS="CHANGE_ME_ADMIN_PASSWORD"
GRAFANA_PASS="CHANGE_ME_GRAFANA_PASSWORD"

# Raiz do repositorio (descoberta a partir deste script)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Configurar template infra-public (usando CONFIG do topo) =="
echo "Aplicando configuracoes..."

### Arquivos alvo
BOOT="$ROOT_DIR/bootstrap/bootstrap.sh"
KB="$ROOT_DIR/k8s/backend"
KF="$ROOT_DIR/k8s/frontend"
WF="$ROOT_DIR/.github/workflows/docker-build.yml"
KREADME="$ROOT_DIR/k8s/README.md"
CFGIT="$ROOT_DIR/configure-github-secrets.sh"

# Substitui placeholders {VARIAVEL} pelos valores configurados acima
# Bootstrap: so a linha DOMAIN= usa placeholder {BASE_DOMAIN}; o resto do script usa $DOMAIN.
for f in "$BOOT" "$KB/deployment.yaml" "$KB/service.yaml" "$KB/ingress.yaml" \
         "$KF/deployment.yaml" "$KF/service.yaml" "$KF/ingress.yaml" \
         "$WF" "$KREADME" "$CFGIT"; do
  sed -i "s|{BASE_DOMAIN}|$DOMAIN|g" "$f"
  sed -i "s|{SERVICE_NAME}|$SERVICE_NAME|g" "$f"
  sed -i "s|{FRONT_NAME}|$FRONT_NAME|g" "$f"
  sed -i "s|{DOCKERHUB_USERNAME}|$DOCKERHUB_USERNAME|g" "$f"
  sed -i "s|{DOCKERHUB_REPO_BACK}|$DOCKERHUB_REPO_BACK|g" "$f"
  sed -i "s|{DOCKERHUB_REPO_FRONT}|$DOCKERHUB_REPO_FRONT|g" "$f"
  sed -i "s|{DOCKERHUB_TOKEN}|$DOCKERHUB_TOKEN|g" "$f"
  sed -i "s|{GH_SECRET_DOCKERHUB_USER}|$GH_SECRET_DOCKERHUB_USER|g" "$f"
  sed -i "s|{GH_SECRET_DOCKERHUB_TOKEN}|$GH_SECRET_DOCKERHUB_TOKEN|g" "$f"
  sed -i "s|{GITHUB_USER}|$GITHUB_USER|g" "$f"
  sed -i "s|{GITHUB_REPO_BACK}|$GITHUB_REPO_BACK|g" "$f"
  sed -i "s|{GITHUB_REPO_FRONT}|$GITHUB_REPO_FRONT|g" "$f"
  sed -i "s|{GIT_TOKEN}|$GIT_TOKEN|g" "$f"
  sed -i "s|{ARGOCD_PASS}|$ARGOCD_PASS|g" "$f"
  sed -i "s|{GRAFANA_PASS}|$GRAFANA_PASS|g" "$f"
done

echo "OK. Template configurado com:"
echo "  DOMAIN         = $DOMAIN"
echo "  SERVICE_NAME   = $SERVICE_NAME"
echo "  FRONT_NAME     = $FRONT_NAME"
echo "  DOCKERHUB_USER = $DOCKERHUB_USERNAME"
