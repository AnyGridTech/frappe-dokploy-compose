#!/usr/bin/env bash
set -euo pipefail

# Pergunta projeto, sem normalizar maiusculo ou minusculo.
echo "Abaixo será pedido o nome do prejeto que está o serviço a ser limpo."
echo "O nome pode ser qualquer coisa, mas geralmente deixamos como 'erp'"
read -rp "Digite o nome do projeto: " PROJECT_NAME

echo "Abaixo será pedido o nome do serviço a ser limpo."
echo "O nome pode ser qualquer coisa, ex: test, dev, prod, luan, luigi, marco, etc..."
read -rp "Digite o serviço: " SERVICE_NAME

echo "Abaixo será pedido o tipo do serviço."
echo "O tipo pode ser: 'applications', 'compose', 'mariadb', 'mongo', 'mysql', 'postgres' ou 'redis'."
read -rp "Digite o tipo do serviço: " SERVICE_TYPE

# Se não for dos tipos acima, precisa dar erro.
if [[ ! "$SERVICE_TYPE" =~ ^(applications|compose|mariadb|mongo|mysql|postgres|redis)$ ]]; then
  echo "❌ Tipo de serviço inválido: $SERVICE_TYPE"
  exit 1
fi

# Info de login no dokploy
echo "Entre com as credenciais de login no dokploy"
read -rp "Usuário: " DOKPLOY_USER
read -rp "Senha: " DOKPLOY_PASSWORD

URL="https://erp-devops.growatt.app"

# Fazer login
TOKEN="$(curl -X POST "$URL/api/auth/sign-in/email" 
  -H "Content-Type: application/json"
  -d "{\"username\":\"$DOKPLOY_USER\",\"password\":\"$DOKPLOY_PASSWORD\"}" | jq -r '.token'
)"

# Pegar todos os projetos ativos no dokploy
DOKPLOY_PROJECTS="$(curl -X GET "$URL/api/project.all"
  -H "Authorization: Bearer $TOKEN"
  -H "Content-Type: application/json"
)"

# Exemplo em JS do codigo abaixo para pegar o SERVICE_ID:
# projectLoop:
# let SERVICE_ID
# for (let project of DOKPLOY_PROJECTS) {
#   if (project.name !== PROJECT_NAME) continue;
#   for (let service of project[SERVICE_TYPE]) {
#     if (service.name === SERVICE_NAME) {
#       const id_name = SERVICE_NAME + 'Id'
#       SERVICE_ID = service[id_name];
#       break projectLoop;
#     }
#   }
# }
SERVICE_ID=$(
  echo "$DOKPLOY_PROJECTS" \
  | jq -r \
    --arg project_name "$PROJECT_NAME" \
    --arg service_type "$SERVICE_TYPE" \
    --arg service_name "$SERVICE_NAME" '
      .[]                                   # percorre os projetos
      | select(.name == $project_name)      # só o projeto certo
      | .[$service_type][]?                 # percorre os serviços do tipo
      | select(.name == $service_name)      # só o serviço certo
      | .[$service_name + "Id"]             # pega o campo dinamicamente
      | select(. != null)                   # ignora se for nulo
      ' | head -n1                          # pega só o primeiro (break)
)

if [[ -z "$SERVICE_ID" ]]; then
  echo "❌ Service $SERVICE_NAME not found in project $PROJECT_NAME"
  exit 1
fi

# Deletar o serviço
# Recriar o serviço

# Limpar os arquivos do serviços na VPS
ssh -o StrictHostKeyChecking=no root@213.199.60.213 ENV="$ENV" '
  set -euo pipefail

  cd /
  echo "🔎 Verificando se o tree 🌳 está instalado..."
  if ! command -v tree >/dev/null 2>&1; then
    echo "📦 Instalando tree..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y --no-install-recommends tree || {
      apt-get update -y && apt-get install -y --no-install-recommends tree
    }
  else
    echo "✅ tree já está instalado."
  fi

  MOUNT_PATH="/home/frappe-$ENV"
  echo "🔎 Verificando se $MOUNT_PATH está em uso por containers..."

  IDS="$(docker ps -q)"
  if [ -n "$IDS" ]; then
    # --format em ASPAS DUPLAS; cuidado com $ no awk (use \$)
    CONTAINERS="$(docker inspect --format "{{.Name}} {{range .Mounts}}{{.Source}}{{printf \" \"}}{{end}}" $IDS 2>/dev/null \
      | grep -F "$MOUNT_PATH" || true)"
  else
    CONTAINERS=""
  fi

  if [ -n "$CONTAINERS" ]; then
    echo "❌ Não é seguro remover $MOUNT_PATH."
    echo "📦 Containers ativos utilizando o diretório:"
    echo "$CONTAINERS" | awk "{c=\$1; \$1=\"\"; sub(/^ /,\"\"); print \"  - Container:\" c \" → Mounts:\" \$0}"
    exit 1
  else
    echo "🗑️ Removendo arquivos antigos de $MOUNT_PATH..."
    rm -rf --one-file-system "$MOUNT_PATH"
  fi
  
  echo "🧹 Limpando volumes órfãos do Docker..."

  docker volume ls -q | while read vol; do
    if ! docker ps -a --filter volume="$vol" --format '{{.ID}}' | grep -q .; then
      echo "Removendo volume órfão: $vol"
      docker volume rm "$vol"
    fi
  done

  echo "✅ Volumes órfãos removidos."

  echo "📁 Recriando pastas necessárias..."
  mkdir -p \
    "/home/frappe-$ENV/frappe-bench/logs" \
    "/home/frappe-$ENV/frappe-bench/apps/frappe" \
    "/home/frappe-$ENV/frappe-bench/sites" \
    "/home/frappe-$ENV/maria-db/data" \
    "/home/frappe-$ENV/redis-cache/data" \
    "/home/frappe-$ENV/redis-queue/data"

  echo "✅ Ambiente \"$ENV\" limpo com sucesso!"

  echo "🔎 Estrutura de pastas criada:"
  tree -L 4 "/home/frappe-$ENV" || true
'

echo "🔚 Processo concluído."