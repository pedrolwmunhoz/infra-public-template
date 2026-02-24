#!/usr/bin/env bash
set -euo pipefail

# Configura os GitHub Secrets nos repositórios da API e (opcional) frontend
# usando os mesmos valores definidos no template.
#
# Requer: gh CLI autenticado (gh auth login).

# --- CONFIG: preencha antes de rodar ---
DOMAIN="{DOMAIN}"
ARGOCD_PASSWORD="{ARGOCD_PASS}"          # Senha admin do ArgoCD
DOCKERHUB_TOKEN="{DOCKERHUB_TOKEN}"      # Personal Access Token do Docker Hub (placeholder para o configure-template.sh)
DOCKERHUB_USERNAME="{DOCKERHUB_USERNAME}"
ARGOCD_SERVER="argocd.{DOMAIN}"

# Repositórios GitHub (owner/repo) onde configurar os secrets
GITHUB_REPOS=(
  "{GITHUB_USER}/{GITHUB_REPO_BACK}"
  "{GITHUB_USER}/{GITHUB_REPO_FRONT}"    # opcional: remova se não usar repo separado de frontend
)

# ---
if [ -z "$ARGOCD_PASSWORD" ]; then
  echo "Erro: defina ARGOCD_PASSWORD no topo do script (ou exporte antes de rodar)."
  exit 1
fi
if [ -z "$DOCKERHUB_TOKEN" ]; then
  echo "Erro: defina DOCKERHUB_TOKEN no topo do script (ou exporte antes de rodar)."
  exit 1
fi

for repo in "${GITHUB_REPOS[@]}"; do
  # permite linhas vazias/comentadas no array
  if [ -z "${repo// }" ]; then
    continue
  fi
  echo "Configurando secrets no repo $repo..."
  gh secret set DOCKERHUB_USERNAME --repo "$repo" --body "$DOCKERHUB_USERNAME"
  gh secret set DOCKERHUB_TOKEN    --repo "$repo" --body "$DOCKERHUB_TOKEN"
  gh secret set ARGOCD_SERVER      --repo "$repo" --body "$ARGOCD_SERVER"
  gh secret set ARGOCD_AUTH_TOKEN  --repo "$repo" --body "$ARGOCD_PASSWORD"
done

echo ""
echo "Secrets configurados:"
echo ""
for repo in "${GITHUB_REPOS[@]}"; do
  if [ -z "${repo// }" ]; then
    continue
  fi
  echo "  $repo:"
  gh secret list --repo "$repo"
  echo ""
done

