## Infra Public Template

Template público para subir um ambiente completo (k3s, cert‑manager, ArgoCD, Prometheus/Grafana + apps) totalmente parametrizado com **chaves `{VARIAVEL}`**.

Este repo foi pensado para alguém clonar, ajustar um único bloco de CONFIG e gerar todos os arquivos finais (bootstrap, k8s, workflows, Dockerfiles) já com os valores reais.

---

### 1. Estrutura do repositório

- `bootstrap/`
  - `bootstrap.sh`: script principal que sobe k3s, cert‑manager, ArgoCD, Prometheus/Grafana, secrets de Docker/Git e cria as Applications no ArgoCD com base em `ARGO_PROJECTS`.
- `k8s/`
  - `backend/`:
    - `deployment.yaml`: Deployment da API (`{SERVICE_NAME}`), escutando em 8081, imagem `{DOCKERHUB_USERNAME}/{DOCKERHUB_REPO_BACK}:latest`.
    - `service.yaml`: Service ClusterIP `{SERVICE_NAME}`, porta 80 → targetPort 8081.
    - `ingress.yaml`: Ingress Traefik para `https://api.{DOMAIN}`, com TLS gerenciado pelo cert‑manager.
    - `rate-limit-middleware.yaml`: Middleware de rate limit para a API.
  - `frontend/`:
    - `deployment.yaml`: Deployment do frontend (`{FRONT_NAME}`), porta 80, imagem `{DOCKERHUB_USERNAME}/{DOCKERHUB_REPO_FRONT}:latest`.
    - `service.yaml`: Service ClusterIP `{FRONT_NAME}`, porta 80 → targetPort 80.
    - `ingress.yaml`: Ingress Traefik para `https://app.{DOMAIN}`, com TLS.
    - `rate-limit-middleware.yaml`: Middleware de rate limit para o frontend.
  - `README.md`: detalhes do layout e portas internas.
- `.github/workflows/`
  - `docker-build.yml`: pipeline genérico de CI/CD que:
    - faz login no Docker Hub usando secrets,
    - builda/pusha a imagem `{DOCKERHUB_USERNAME}/{DOCKERHUB_REPO_BACK}:tag`,
    - chama o ArgoCD para dar sync na app `{SERVICE_NAME}`.
- `docker/`
  - `backend/`:
    - `Dockerfile.java`: template para API Java/Maven.
    - `Dockerfile.node`: template para API Node.js.
    - `Dockerfile.go`: template para API Go.
    - `Dockerfile.python`: template para API Python.
  - `frontend/`:
    - `Dockerfile.frontend`: template para SPA (React, Vite, Vue, etc.) que gera build em `dist/`.
- `configure-template.sh`
  - script que lê o bloco de CONFIG do topo e substitui **todas** as chaves `{VARIAVEL}` nos arquivos do repo.
- `configure-github-secrets.sh`
  - script opcional para criar/atualizar os GitHub Secrets (Docker Hub + ArgoCD), inserindo seus **personal tokens/senhas** nesses secrets nos repositórios `{GITHUB_REPO_BACK}` e `{GITHUB_REPO_FRONT}` usando a CLI `gh`.

---

### 2. Blocos de CONFIG

#### 2.1 `configure-template.sh`

Abra `configure-template.sh` e ajuste apenas este bloco:

```bash
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
DOCKERHUB_TOKEN=""              # PAT do Docker Hub (opcional: se quiser que o template injete essa chave também)

# GitHub
GITHUB_USER="your-github-username"
GITHUB_REPO_BACK="myservice-api"
GITHUB_REPO_FRONT=""           # opcional: se tiver repo separado do frontend
GIT_TOKEN=""                   # opcional: PAT do GitHub que o ArgoCD usará para acessar repos privados

# Senhas
ARGOCD_PASS="CHANGE_ME_ADMIN_PASSWORD"
GRAFANA_PASS="CHANGE_ME_GRAFANA_PASSWORD"
```

Depois rode:

```bash
chmod +x configure-template.sh
./configure-template.sh
```

Ele vai substituir as chaves `{DOMAIN}`, `{SERVICE_NAME}`, `{FRONT_NAME}`, `{DOCKERHUB_USERNAME}`, `{DOCKERHUB_REPO_BACK}`, `{DOCKERHUB_REPO_FRONT}`, `{DOCKERHUB_TOKEN}`, `{GITHUB_USER}`, `{GITHUB_REPO_BACK}`, `{GITHUB_REPO_FRONT}`, `{GIT_TOKEN}`, `{ARGOCD_PASS}`, `{GRAFANA_PASS}` nos arquivos:

- `bootstrap/bootstrap.sh`
- `k8s/backend/*`
- `k8s/frontend/*`
- `k8s/README.md`
- `.github/workflows/docker-build.yml`

#### 2.2 `configure-github-secrets.sh`

No `configure-github-secrets.sh` você encontra este bloco:

```bash
DOMAIN="{DOMAIN}"
ARGOCD_PASSWORD="{ARGOCD_PASS}"          # Senha admin do ArgoCD
DOCKERHUB_TOKEN="{DOCKERHUB_TOKEN}"      # PAT do Docker Hub (placeholder que o configure-template.sh pode preencher)
DOCKERHUB_USERNAME="{DOCKERHUB_USERNAME}"
ARGOCD_SERVER="argocd.{DOMAIN}"

GITHUB_REPOS=(
  "{GITHUB_USER}/{GITHUB_REPO_BACK}"
  "{GITHUB_USER}/{GITHUB_REPO_FRONT}"    # opcional: remova se não usar repo separado de frontend
)
```

As chaves `{DOMAIN}`, `{ARGOCD_PASS}`, `{DOCKERHUB_USERNAME}`, `{DOCKERHUB_TOKEN}`, `{GITHUB_USER}`, `{GITHUB_REPO_BACK}`, `{GITHUB_REPO_FRONT}` vêm do `configure-template.sh`.  
Na prática, esse script pega o **PAT do Docker Hub** e a **senha/token do ArgoCD** e grava tudo como *GitHub Secrets* nos repositórios informados.

---

### 3. Placeholders usados

Principais chaves que aparecem nos arquivos:

- **Domínio / URLs**
  - `{DOMAIN}` → domínio base (ex.: `example.com`).
  - `api.{DOMAIN}` → host público da API.
  - `app.{DOMAIN}` → host público do frontend.
- **Serviços / Apps**
  - `{SERVICE_NAME}` → nome da aplicação backend (Deployment, Service, Application no ArgoCD).
  - `{FRONT_NAME}` → nome da aplicação frontend.
- **Docker Hub**
  - `{DOCKERHUB_USERNAME}` → usuário do Docker Hub.
  - `{DOCKERHUB_REPO_BACK}` → nome do repositório da imagem backend.
  - `{DOCKERHUB_REPO_FRONT}` → nome do repositório da imagem frontend.
- **GitHub**
  - `{GITHUB_USER}` → dono dos repositórios no GitHub.
  - `{GITHUB_REPO_BACK}` → repo backend que contém a pasta `k8s/backend`.
  - `{GITHUB_REPO_FRONT}` → repo frontend (separado), que contém `k8s/frontend` (opcional).
  - `{GIT_TOKEN}` → PAT do GitHub usado pelo ArgoCD para acessar repos privados.
- **Senhas**
  - `{ARGOCD_PASS}` → senha padrão do usuário `admin` do ArgoCD.
  - `{GRAFANA_PASS}` → senha padrão do `admin` do Grafana.

---

### 4. Fluxo de uso (alto nível)

1. **Clonar o template**
   ```bash
   git clone https://github.com/pedrolwmunhoz/infra-public-template.git
   cd infra-public-template
   ```
2. **Editar o CONFIG do `configure-template.sh`** com seu domínio, nomes de serviços, Docker Hub, GitHub, senhas.
3. **Rodar `./configure-template.sh`** para aplicar as chaves em todos os arquivos.
4. **Copiar o `bootstrap/bootstrap.sh`** para a VM (ex.: k3s rodando em cloud):
   ```bash
   scp bootstrap/bootstrap.sh USUARIO@IP_DA_VM:~/bootstrap.sh
   ```
5. **Rodar o bootstrap na VM**:
   ```bash
   chmod +x bootstrap.sh
   sudo ./bootstrap.sh
   ```
6. **Criar DNS A records** apontando `api.{DOMAIN}`, `app.{DOMAIN}`, `argocd.{DOMAIN}`, `grafana.{DOMAIN}` para o IP externo da VM.
7. **Configurar GitHub Secrets** nos repositórios (`{GITHUB_REPO_BACK}` e, se existir, `{GITHUB_REPO_FRONT}`):
   - manualmente pelo painel do GitHub, **ou**
   - rodando o script (em **qualquer máquina** com `gh` instalado e logado no GitHub; não precisa ser na VM):
     ```bash
     chmod +x configure-github-secrets.sh
     ./configure-github-secrets.sh
     ```

---

### 5. Observações importantes

- O `configure-github-secrets.sh` **não precisa rodar na VM**: rode em qualquer máquina onde o `gh` (GitHub CLI) esteja instalado e logado no GitHub; ele só configura os secrets nos repositórios remotos.
- Os manifests k8s assumem:
  - API escutando em porta **8081** internamente.
  - Frontend escutando em **80** (Nginx ou similar).
- Os ingressos usam **Traefik** como `ingressClassName` e `letsencrypt-prod` como `cluster-issuer` para TLS.
- O pipeline de CI/CD (`.github/workflows/docker-build.yml`) está preparado para:
  - buildar/pushar a imagem backend,
  - chamar o ArgoCD para sincronizar a Application `{SERVICE_NAME}`.
- As pastas `k8s/backend` e `k8s/frontend` deste template devem ser **copiadas para dentro dos repositórios reais** da API e do Front e commitadas lá (o ArgoCD sempre lê a pasta `k8s/` **dentro** do repo da aplicação).

  Exemplo de estrutura final do repo backend:

  ```text
  {GITHUB_REPO_BACK}/
    Dockerfile
    .github/
      workflows/
        docker-build.yml
    k8s/
      backend/
        deployment.yaml
        service.yaml
        ingress.yaml
        rate-limit-middleware.yaml
  ```

  Exemplo de estrutura final do repo frontend:

  ```text
  {GITHUB_REPO_FRONT}/
    Dockerfile
    .github/
      workflows/
        docker-build.yml
    k8s/
      frontend/
        deployment.yaml
        service.yaml
        ingress.yaml
        rate-limit-middleware.yaml
  ```

Se quiser adicionar mais serviços, o fluxo é:

1. Copiar a pasta `k8s/backend` para outro nome, ajustar chaves.
2. Criar mais entradas em `ARGO_PROJECTS` no `bootstrap/bootstrap.sh`.
3. Criar novos workflows/Jobs no `.github/workflows/` usando o mesmo padrão de chaves.

