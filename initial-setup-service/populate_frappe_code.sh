#!/bin/bash
# ./populate_frappe_code.sh
set -e

echo "Running populate_frappe_code.sh..."

if [ -d /mnt/apps/frappe ] && [ -d /mnt/apps/erpnext ]; then
  echo "✅ apps/ already populated."
  echo "Finished populate_frappe_code.sh"
  exit 0
fi

# --- BENCH SETUP REQUIREMENTS WORKAROUND START ---
# A imagem base do frappe e erpnext não incluem metadados .git, 
# que são necessários para o 'bench setup requirements'
# utilizado posteriormente no pipeline de inicialização.
# O workaround inicializa um repositório git e cria um primeiro commit vazio
# para tornar o repositório 'válido' para a biblioteca GitPython.

if [ ! -d "/home/frappe/frappe-bench/apps/frappe/.git" ]; then
    echo "Initializing dummy Git repo in apps/frappe..."
    cd /home/frappe/frappe-bench/apps/frappe
    git init -b main > /dev/null
    # Criar um commit inicial vazio para validar o repositório
    git commit --allow-empty -m "Initial commit for compatibility" > /dev/null
    cd /home/frappe/frappe-bench
fi

if [ ! -d "/home/frappe/frappe-bench/apps/erpnext/.git" ]; then
    echo "Initializing dummy Git repo in apps/erpnext..."
    cd /home/frappe/frappe-bench/apps/erpnext
    git init -b main > /dev/null
    # Criar um commit inicial vazio para validar o repositório
    git commit --allow-empty -m "Initial commit for compatibility" > /dev/null
    cd /home/frappe/frappe-bench
fi
# --- BENCH SETUP REQUIREMENTS WORKAROUND END ---

echo "🔎 Inspecting frappe folder"
ls -la /home/frappe/frappe-bench/apps/frappe
echo "🔎 Inspecting erpnext folder"
ls -la /home/frappe/frappe-bench/apps/erpnext

echo "📦 Populating /mnt/apps from image..."
cp -a /home/frappe/frappe-bench/apps/. /mnt/apps/
chown -R 1000:1000 /mnt/apps || true
echo "✅ apps/ populated."

echo "Finished populate_frappe_code.sh"