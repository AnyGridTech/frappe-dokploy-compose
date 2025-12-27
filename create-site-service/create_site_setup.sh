#!/bin/bash
# ./create_site_setup.sh

set -e

echo "Running create_site_setup.sh"
trap 'echo "Finished create_site_setup.sh"' EXIT

echo "Using MySQL root password: ${MYSQL_ROOT_PASSWORD:0:3}********"

if bench --site "$SITE_NAME" list-apps >/dev/null 2>&1; then
  echo "✅ Site $SITE_NAME já existe, saindo da execução..."
  exit 0
fi

wait-for-it -t 15 db-service:3306
wait-for-it -t 15 redis-cache-service:6379
wait-for-it -t 15 redis-queue-service:6379

start=$(date +%s)
max_wait_time=10  # 10 seconds
echo "Waiting for sites/common_site_config.json to be created"
echo "Timeout set to $max_wait_time seconds"

until [[ -n $(grep -hs ^ sites/common_site_config.json | jq -r ".db_host // empty") ]] &&
  [[ -n $(grep -hs ^ sites/common_site_config.json | jq -r ".redis_cache // empty") ]] &&
  [[ -n $(grep -hs ^ sites/common_site_config.json | jq -r ".redis_queue // empty") ]];
do
  sleep 2
  if (( $(date +%s) - start > max_wait_time )); then
    echo "⛔ Timeout reached after $max_wait_time seconds waiting for sites/common_site_config.json"
    exit 1
  fi
done

echo "sites/common_site_config.json found"

echo "🔧 Ensuring Python requirements are installed..."
if ! python -m frappe.utils.bench_helper >/dev/null 2>&1; then
  echo "⚠️ Frappe module not found in Python environment, running bench setup requirements..."
  bench setup requirements
  echo "✅ Python requirements installed successfully"
else
  echo "✅ Frappe module already available"
fi

echo "Creating new site named $SITE_NAME..."
echo "Using MySQL root username: $MYSQL_ROOT_USERNAME"
echo "Using MySQL root password: ${MYSQL_ROOT_PASSWORD:0:3}********"

# Prepare database name flag if DB_NAME is provided
DB_NAME_FLAG=""
if [ -n "${DB_NAME}" ]; then
  echo "Using custom database name: $DB_NAME"
  DB_NAME_FLAG="--db-name=${DB_NAME}"
else
  echo "No custom database name provided, using random database name"
fi

bench new-site --mariadb-user-host-login-scope='%' \
  --admin-password=${MYSQL_ROOT_PASSWORD} \
  --db-root-username=root \
  --db-root-password=${MYSQL_ROOT_PASSWORD} \
  --install-app erpnext \
  --set-default \
    ${DB_NAME_FLAG} \
    ${SITE_NAME}

echo "✅ Site created successfully"

# Ensure the site is set as default in the sites directory
BENCH_DIR="/home/frappe/frappe-bench"
echo "${SITE_NAME}" > "${BENCH_DIR}/sites/currentsite.txt"

echo "📝 Current site set to: ${SITE_NAME}"
echo "Contents of currentsite.txt:"
cat "${BENCH_DIR}/sites/currentsite.txt"

# Also verify site directory exists
if [ -d "${BENCH_DIR}/sites/${SITE_NAME}" ]; then
  echo "✅ Site directory exists: ${BENCH_DIR}/sites/${SITE_NAME}"
  ls -la "${BENCH_DIR}/sites/${SITE_NAME}" | head -10
else
  echo "⚠️ Site directory not found: ${BENCH_DIR}/sites/${SITE_NAME}"
fi
