#!/usr/bin/env bash
set -euo pipefail
SCRIPT_START=$(date +%s)

# --- CONFIG: altere aqui ---

# Dominio base usado para ArgoCD, Grafana e Apps.
# Exemplo: se DOMAIN="{BASE_DOMAIN}" entao:
#   - ArgoCD  -> https://argocd.{BASE_DOMAIN}
#   - Grafana -> https://grafana.{BASE_DOMAIN}
#   - API     -> https://api.{BASE_DOMAIN}  (ver campo host em ARGO_PROJECTS)
DOMAIN="{BASE_DOMAIN}"

# Senha padrao que sera configurada para o usuario admin do ArgoCD.
# Troque por um valor seguro antes de rodar.
ARGOCD_SENHA_PADRAO="{ARGOCD_PASS}"

# Senha padrao do usuario admin do Grafana.
GRAFANA_ADMIN_PASSWORD="{GRAFANA_PASS}"

# Usuario do Docker Hub que vai receber as imagens da sua app.
# O workflow do GitHub usa este usuario para fazer push da imagem.
DOCKERHUB_USERNAME="{GH_SECRET_DOCKERHUB_USER}"

# Token (Personal Access Token) do Docker Hub.
# Deixe vazio se as imagens forem publicas.
DOCKERHUB_TOKEN="{GH_SECRET_DOCKERHUB_TOKEN}"           # opcional: token do Docker Hub (se imagens privadas)

# Credenciais Git para o ArgoCD acessar repositorios privados.
# Se seus repositorios forem publicos, pode deixar em branco.
GIT_USERNAME="{GITHUB_USER}"
GIT_TOKEN="{GIT_TOKEN}"                 # opcional: PAT do GitHub (se repos privados)

# Projetos ArgoCD:
#   formato: nome|repoURL|path|targetRevision|syncOptions|host
#   - nome           : nome da Application no ArgoCD
#   - repoURL        : URL do repositorio Git com os manifests k8s
#   - path           : pasta dentro do repo onde estao os manifests (ex.: k8s)
#   - targetRevision : branch/tag (ex.: main)
#   - syncOptions    : opcoes extras (ex.: CreateNamespace=true)
#   - host           : subdominio usado no DNS (api -> api.${DOMAIN})
ARGO_PROJECTS=(
  # API backend ({SERVICE_NAME}), apontando para a pasta k8s/backend do repo
  "{SERVICE_NAME}|https://github.com/{GITHUB_USER}/{GITHUB_REPO_BACK}.git|k8s/backend|main|CreateNamespace=true|api"
  # Frontend ({FRONT_NAME}), apontando para a pasta k8s/frontend do repo
  "{FRONT_NAME}|https://github.com/{GITHUB_USER}/{GITHUB_REPO_FRONT}.git|k8s/frontend|main||app"
)

NODE_IP=$(hostname -I | awk '{print $1}')

# ── [1/9] k3s ────────────────────────────────────────────────────────────────
echo "[1/9] k3s..."
curl -sfL https://get.k3s.io | sh -
systemctl enable k3s
systemctl start k3s
echo "Aguardando node ficar Ready..."
until kubectl get nodes 2>/dev/null | grep -q ' Ready'; do sleep 3; done
echo "k3s OK"

# ── [2/9] kubeconfig + CoreDNS hairpin (GCP) ──────────────────────────────────
echo "[2/9] kubeconfig..."
REAL_USER="${SUDO_USER:-$(whoami)}"
REAL_HOME=$(eval echo "~$REAL_USER")
mkdir -p "$REAL_HOME/.kube"
cp /etc/rancher/k3s/k3s.yaml "$REAL_HOME/.kube/config"
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.kube/config"
chmod 600 "$REAL_HOME/.kube/config"
[ -n "$NODE_IP" ] && sed -i "s/127.0.0.1/$NODE_IP/g" "$REAL_HOME/.kube/config"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
grep -q 'export KUBECONFIG' "$REAL_HOME/.bashrc" 2>/dev/null || echo 'export KUBECONFIG=~/.kube/config' >> "$REAL_HOME/.bashrc"

# CoreDNS: aguardar existir e dominios pelo IP interno (evita hairpin NAT no GCP)
echo "  Aguardando CoreDNS..."
for i in $(seq 1 30); do
  kubectl -n kube-system get configmap coredns &>/dev/null && break
  sleep 2
done
COREFILE=$(kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}')
{
  echo "${NODE_IP} $(hostname)"
  echo "${NODE_IP} argocd.${DOMAIN}"
  echo "${NODE_IP} grafana.${DOMAIN}"
  for proj in "${ARGO_PROJECTS[@]}"; do
    IFS='|' read -r _ _ _ _ _ host <<< "$proj"
    [ -n "$host" ] && echo "${NODE_IP} ${host}.${DOMAIN}"
  done
} > /tmp/coredns-hosts
kubectl -n kube-system create configmap coredns \
  --from-file=NodeHosts=/tmp/coredns-hosts \
  --from-literal="Corefile=${COREFILE}" \
  --dry-run=client -o yaml | kubectl apply -f -
sleep 20
echo "kubeconfig OK"

# ── [3/9] Helm ────────────────────────────────────────────────────────────────
echo "[3/9] Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version --short
echo "Helm OK"

# ── [4/9] cert-manager v1.19.3 ───────────────────────────────────────────────
echo "[4/9] cert-manager v1.19.3..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.3/cert-manager.crds.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.3/cert-manager.yaml
kubectl -n cert-manager rollout status deployment/cert-manager --timeout=120s
kubectl -n cert-manager rollout status deployment/cert-manager-cainjector --timeout=120s
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=120s
sleep 10

kubectl apply -f - <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@${DOMAIN}
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: traefik
YAML
echo "cert-manager OK"

# ── [5/9] ArgoCD ──────────────────────────────────────────────────────────────
echo "[5/9] ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=120s

kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"protocol":"TCP","targetPort":8080},{"name":"https","port":443,"protocol":"TCP","targetPort":8080}]}}'

kubectl apply -n argocd -f - <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - argocd.${DOMAIN}
      secretName: argocd-tls
  rules:
    - host: argocd.${DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
YAML

kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl -n argocd rollout restart deployment argocd-server
kubectl -n argocd rollout status deployment/argocd-server --timeout=120s
echo "ArgoCD OK"

# ── [6/9] Monitoring (Prometheus + Grafana) ───────────────────────────────────
echo "[6/9] Monitoring..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi \
  --set prometheus.prometheusSpec.resources.limits.cpu=500m \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=5Gi \
  --set grafana.adminPassword="${GRAFANA_ADMIN_PASSWORD}" \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.requests.cpu=50m \
  --set grafana.resources.limits.memory=256Mi \
  --set grafana.resources.limits.cpu=200m \
  --set grafana.ingress.enabled=true \
  --set grafana.ingress.ingressClassName=traefik \
  --set "grafana.ingress.hosts[0]=grafana.${DOMAIN}" \
  --set "grafana.ingress.tls[0].secretName=grafana-${DOMAIN//./-}-tls" \
  --set "grafana.ingress.tls[0].hosts[0]=grafana.${DOMAIN}" \
  --set "grafana.ingress.annotations.cert-manager\.io/cluster-issuer=letsencrypt-prod" \
  --set "grafana.ingress.annotations.traefik\.ingress\.kubernetes\.io/router\.entrypoints=web\,websecure" \
  --set alertmanager.enabled=false
echo "Monitoring OK"

# ── [7/9] Secret Docker Hub (image pull) ──────────────────────────────────────
if [ -n "$DOCKERHUB_TOKEN" ]; then
  echo "[7/9] Secret dockerhub-registry..."
  kubectl create secret docker-registry dockerhub-registry \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username="$DOCKERHUB_USERNAME" \
    --docker-password="$DOCKERHUB_TOKEN" \
    --namespace default \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "Secret OK"
fi

# ── [8/9] ArgoCD CLI + Applications ──────────────────────────────────────────
echo "[8/9] ArgoCD CLI + Applications..."
curl -sSL -o /tmp/argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
chmod +x /tmp/argocd
mv /tmp/argocd /usr/local/bin/argocd

# Pegar senha inicial do secret, logar e alterar para a senha padrão
for i in $(seq 1 30); do kubectl -n argocd get secret argocd-initial-admin-secret &>/dev/null && break; sleep 2; done
ARGOCD_INITIAL_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
grep -q "argocd.${DOMAIN}" /etc/hosts || echo "127.0.0.1 argocd.${DOMAIN}" >> /etc/hosts
argocd login "argocd.${DOMAIN}" --username admin --password "$ARGOCD_INITIAL_PASS" --insecure --grpc-web
argocd account update-password --current-password "$ARGOCD_INITIAL_PASS" --new-password "$ARGOCD_SENHA_PADRAO"
sed -i "/argocd.${DOMAIN}/d" /etc/hosts

ARGOCD_PASS="$ARGOCD_SENHA_PADRAO"

grep -q "argocd.${DOMAIN}" /etc/hosts || echo "127.0.0.1 argocd.${DOMAIN}" >> /etc/hosts
argocd login "argocd.${DOMAIN}" --username admin --password "$ARGOCD_PASS" --insecure --grpc-web
sed -i "/argocd.${DOMAIN}/d" /etc/hosts

# Credenciais Git no ArgoCD (repos privados)
if [ -n "$GIT_TOKEN" ]; then
  grep -q "argocd.${DOMAIN}" /etc/hosts || echo "127.0.0.1 argocd.${DOMAIN}" >> /etc/hosts
  argocd repocreds add https://github.com/ --username "$GIT_USERNAME" --password "$GIT_TOKEN" --insecure
  sed -i "/argocd.${DOMAIN}/d" /etc/hosts
fi

# Registry Docker no ArgoCD (imagens/Helm OCI privados)
if [ -n "$DOCKERHUB_TOKEN" ]; then
  grep -q "argocd.${DOMAIN}" /etc/hosts || echo "127.0.0.1 argocd.${DOMAIN}" >> /etc/hosts
  argocd repo add index.docker.io --type helm --enable-oci --username "$DOCKERHUB_USERNAME" --password "$DOCKERHUB_TOKEN" --insecure 2>/dev/null || true
  sed -i "/argocd.${DOMAIN}/d" /etc/hosts
fi

for proj in "${ARGO_PROJECTS[@]}"; do
  IFS='|' read -r name repoURL path targetRevision syncOptions host <<< "$proj"
  SYNC_OPTS=""
  [ -n "$syncOptions" ] && SYNC_OPTS="
    syncOptions:
      - ${syncOptions}"
  REV_LINE=""
  [ -n "$targetRevision" ] && REV_LINE="
    targetRevision: ${targetRevision}"
  echo "  Aplicando: $name"
  kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${name}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${repoURL}
    path: ${path}${REV_LINE}
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true${SYNC_OPTS}
YAML
done
echo "Applications OK"

# ── [9/9] Resumo ─────────────────────────────────────────────────────────────
EXTERNAL_IP=$(curl -s --connect-timeout 2 -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null || curl -s --connect-timeout 2 ifconfig.me 2>/dev/null || echo "IP_EXTERNO_DA_VM")
echo ""
echo "============================================="
echo " AMBIENTE REPLICADO"
echo "============================================="
echo ""
echo "ArgoCD:  https://argocd.${DOMAIN}"
echo "  user:  admin"
echo "  pass:  $ARGOCD_PASS"
echo ""
echo "Grafana: https://grafana.${DOMAIN}"
echo "  user:  admin"
echo "  pass:  $GRAFANA_ADMIN_PASSWORD"
echo ""
for proj in "${ARGO_PROJECTS[@]}"; do
  IFS='|' read -r name _ _ _ _ host <<< "$proj"
  [ -n "$host" ] && echo "$name:   https://${host}.${DOMAIN}"
done
echo ""
echo "DNS: criar registro A (cada host -> $EXTERNAL_IP)"
echo "  argocd.${DOMAIN}"
echo "  grafana.${DOMAIN}"
for proj in "${ARGO_PROJECTS[@]}"; do
  IFS='|' read -r _ _ _ _ _ host <<< "$proj"
  [ -n "$host" ] && echo "  ${host}.${DOMAIN}"
done
echo ""
echo "GCP: na VM, tags de rede: http-server, https-server"
echo ""
echo "Secrets (resumo):"
echo "  ARGOCD_SERVER   = https://argocd.${DOMAIN}"
echo "  USERNAME_ARGO   = admin"
echo "  SENHA_ARGO      = $ARGOCD_PASS"
echo "  GRAFANA_SERVER  = https://grafana.${DOMAIN}"
echo "  USERNAME_GRAFANA = admin"
echo "  SENHA_GRAFANA   = $GRAFANA_ADMIN_PASSWORD"
echo ""
ELAPSED=$(($(date +%s) - SCRIPT_START))
echo "Tempo total: $((ELAPSED / 60)) min $((ELAPSED % 60)) s"
echo "============================================="
