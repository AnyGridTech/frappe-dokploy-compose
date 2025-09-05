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
# Então iniciamos um repositório git com um primeiro commit
# tornando o repositório 'válido' para a biblioteca GitPython.

no_frappe_git="false"
[ ! -d "/home/frappe/frappe-bench/apps/frappe/.git" ] && no_frappe_git=true
no_erpnext_git="false"
[ ! -d "/home/frappe/frappe-bench/apps/erpnext/.git" ] && no_erpnext_git=true

if [ "$no_frappe_git" ] || [ "$no_erpnext_git" ]; then
    echo "⚠️ Detected missing .git directories in apps/frappe or apps/erpnext."
    echo "This may cause 'bench setup requirements' to fail."
    echo "Applying workaround to initialize dummy git repositories..."
    echo "This git repositories are not supposed to be used or commited to."
    echo "Configuring Git author identity..."
    git config --global user.name "troyaks1"
    git config --global user.email "lgotcfg@gmail.com"
    echo "Configuring Git safe directories..."
    git config --global --add safe.directory /home/frappe/frappe-bench/apps/frappe
    git config --global --add safe.directory /home/frappe/frappe-bench/apps/erpnext
fi

if [ "$no_frappe_git" ]; then
    echo "🔄 Initializing dummy Git repo in apps/frappe..."
    cd /home/frappe/frappe-bench/apps/frappe
    git init -b main > /dev/null
    git commit --allow-empty -m "Initial commit for compatibility" > /dev/null
    cd /home/frappe/frappe-bench
fi

if [ "$no_erpnext_git" ]; then
    echo "🔄 Initializing dummy Git repo in apps/erpnext..."
    cd /home/frappe/frappe-bench/apps/erpnext
    git init -b main > /dev/null
    git commit --allow-empty -m "Initial commit for compatibility" > /dev/null
    cd /home/frappe/frappe-bench
fi
# --- BENCH SETUP REQUIREMENTS WORKAROUND END ---

echo "📦 Populating /mnt/apps from image folders..."
cp -a /home/frappe/frappe-bench/apps/. /mnt/apps/
chown -R 1000:1000 /mnt/apps || true
echo "✅ apps/ populated."

echo "Finished populate_frappe_code.sh"