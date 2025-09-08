#!/usr/bin/env bash
set -euo pipefail

# Pergunta e normaliza para minúsculas
read -rp "Digite o ambiente (test/dev/prod): " ENV
ENV="$(printf '%s' "$ENV" | tr '[:upper:]' '[:lower:]')"

# Execução remota (passa ENV como variável para o shell remoto)
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
    "/home/frappe-$ENV/frappe-bench/env" \
    "/home/frappe-$ENV/maria-db/data" \
    "/home/frappe-$ENV/redis-cache/data" \
    "/home/frappe-$ENV/redis-queue/data"

  echo "✅ Ambiente \"$ENV\" limpo com sucesso!"

  echo "🔎 Estrutura de pastas criada:"
  tree -L 4 "/home/frappe-$ENV" || true
'

echo "🔚 Processo concluído."