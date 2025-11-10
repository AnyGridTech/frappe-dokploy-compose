#!/bin/bash
# ./populate_frappe_code.sh <?env>
set -e

echo "Running populate_frappe_code.sh..."
trap 'echo "Finished populate_frappe_code.sh"' EXIT

BENCH_DIR_APP="/home/frappe/frappe-bench"
BENCH_DIR_HOST="/mnt"

populate_frappe_code() {
    echo "📦 Populating $BENCH_DIR_HOST from image folders..."
    cp -a "$BENCH_DIR_APP/apps/." "$BENCH_DIR_HOST/"
    chown -R 1000:1000 "$BENCH_DIR_HOST" || true
    echo "✅ apps/ populated."
}

env="$1"

if [ "$env" = "dev" ]; then
    echo "Development environment detected."
    populate_frappe_code
    exit 0
fi

if [ -d "$BENCH_DIR_HOST/frappe/.git" ] && [ -d "$BENCH_DIR_HOST/erpnext/.git" ]; then
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
[ ! -d "$BENCH_DIR_APP/apps/frappe/.git" ] && no_frappe_git=true
no_erpnext_git="false"
[ ! -d "$BENCH_DIR_APP/apps/erpnext/.git" ] && no_erpnext_git=true

if [ "$no_frappe_git" ] || [ "$no_erpnext_git" ]; then
    echo "⚠️ Detected missing .git directories in apps/frappe or apps/erpnext."
    echo "This may cause 'bench setup requirements' to fail."
    echo "Applying workaround to initialize dummy git repositories..."
    echo "This git repositories are not supposed to be used or commited to."
    echo "Configuring Git author identity..."
    git config --global user.name "troyaks1"
    git config --global user.email "lgotcfg@gmail.com"
    echo "Configuring Git safe directories..."
    git config --global --add safe.directory $BENCH_DIR_APP/apps/frappe
    git config --global --add safe.directory $BENCH_DIR_APP/apps/erpnext
fi

if [ "$no_frappe_git" ]; then
    echo "🔄 Initializing dummy Git repo in apps/frappe..."
    cd $BENCH_DIR_APP/apps/frappe
    git init -b main > /dev/null
    git commit --allow-empty -m "Initial commit for compatibility" > /dev/null
    cd $BENCH_DIR_APP
fi

if [ "$no_erpnext_git" ]; then
    echo "🔄 Initializing dummy Git repo in apps/erpnext..."
    cd $BENCH_DIR_APP/apps/erpnext
    git init -b main > /dev/null
    git commit --allow-empty -m "Initial commit for compatibility" > /dev/null
    cd $BENCH_DIR_APP
fi
# --- BENCH SETUP REQUIREMENTS WORKAROUND END ---

populate_frappe_code

echo "Fixing permissions..."
# The volume is mounted at /mnt in this specific container
chown -R 1000:1000 /mnt

echo "✅ Population complete."