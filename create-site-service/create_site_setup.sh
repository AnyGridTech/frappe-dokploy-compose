#!/bin/bash
# ./create_site_setup.sh

set -e

echo "Running create_site_setup.sh"
trap 'echo "Finished create_site_setup.sh"' EXIT

# Validate required environment variables
if [ -z "${SITE_NAME}" ]; then
  echo "⛔ ERROR: SITE_NAME environment variable is not set"
  exit 1
fi

if [ -z "${MYSQL_ROOT_PASSWORD}" ]; then
  echo "⛔ ERROR: MYSQL_ROOT_PASSWORD environment variable is not set"
  exit 1
fi

if [ -z "${MYSQL_ROOT_USERNAME}" ]; then
  echo "⛔ ERROR: MYSQL_ROOT_USERNAME environment variable is not set"
  exit 1
fi

echo "✅ Environment variables validated"
echo "   SITE_NAME: ${SITE_NAME}"
echo "   MYSQL_ROOT_USERNAME: ${MYSQL_ROOT_USERNAME}"
echo "   MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:0:3}********"
if [ -n "${DB_NAME}" ]; then
  echo "   DB_NAME: ${DB_NAME}"
fi

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

echo "✅ Site creation command completed"

# Ensure the site is set as default in the sites directory
BENCH_DIR="/home/frappe/frappe-bench"
echo "${SITE_NAME}" > "${BENCH_DIR}/sites/currentsite.txt"

echo "📝 Current site set to: ${SITE_NAME}"

# ========================================
# POST-CREATION VALIDATION
# ========================================
echo "\n🔍 Validating site creation..."

VALIDATION_FAILED=0

# 1. Verify site directory exists
if [ -d "${BENCH_DIR}/sites/${SITE_NAME}" ]; then
  echo "✅ Site directory exists: ${BENCH_DIR}/sites/${SITE_NAME}"
else
  echo "⛔ VALIDATION FAILED: Site directory not found: ${BENCH_DIR}/sites/${SITE_NAME}"
  VALIDATION_FAILED=1
fi

# 2. Verify site config file exists
if [ -f "${BENCH_DIR}/sites/${SITE_NAME}/site_config.json" ]; then
  echo "✅ Site config file exists"
else
  echo "⛔ VALIDATION FAILED: Site config file not found"
  VALIDATION_FAILED=1
fi

# 3. Verify site is accessible via bench
if bench --site "${SITE_NAME}" list-apps >/dev/null 2>&1; then
  echo "✅ Site is accessible via bench commands"
  echo "   Installed apps:"
  bench --site "${SITE_NAME}" list-apps | sed 's/^/     - /'
else
  echo "⛔ VALIDATION FAILED: Site is not accessible via bench commands"
  VALIDATION_FAILED=1
fi

# 4. Verify database name matches if DB_NAME was provided
if [ -n "${DB_NAME}" ]; then
  echo "\n🔍 Validating database name..."
  ACTUAL_DB_NAME=$(grep -hs ^ "${BENCH_DIR}/sites/${SITE_NAME}/site_config.json" | jq -r '.db_name // empty')
  
  if [ -n "${ACTUAL_DB_NAME}" ]; then
    if [ "${ACTUAL_DB_NAME}" = "${DB_NAME}" ]; then
      echo "✅ Database name matches: ${ACTUAL_DB_NAME}"
    else
      echo "⛔ VALIDATION FAILED: Database name mismatch!"
      echo "   Expected: ${DB_NAME}"
      echo "   Actual: ${ACTUAL_DB_NAME}"
      VALIDATION_FAILED=1
    fi
  else
    echo "⛔ VALIDATION FAILED: Could not read database name from site_config.json"
    VALIDATION_FAILED=1
  fi
else
  echo "\n📝 Database name was auto-generated (DB_NAME not provided)"
  ACTUAL_DB_NAME=$(grep -hs ^ "${BENCH_DIR}/sites/${SITE_NAME}/site_config.json" | jq -r '.db_name // empty')
  if [ -n "${ACTUAL_DB_NAME}" ]; then
    echo "   Generated database name: ${ACTUAL_DB_NAME}"
  fi
fi

# 5. Verify currentsite.txt matches
CURRENT_SITE=$(cat "${BENCH_DIR}/sites/currentsite.txt" 2>/dev/null || echo "")
if [ "${CURRENT_SITE}" = "${SITE_NAME}" ]; then
  echo "✅ Current site is set correctly: ${CURRENT_SITE}"
else
  echo "⚠️ WARNING: Current site mismatch (expected: ${SITE_NAME}, got: ${CURRENT_SITE})"
fi

echo "\n========================================"
if [ ${VALIDATION_FAILED} -eq 0 ]; then
  echo "✅ ALL VALIDATIONS PASSED"
  echo "   Site Name: ${SITE_NAME}"
  if [ -n "${ACTUAL_DB_NAME}" ]; then
    echo "   Database Name: ${ACTUAL_DB_NAME}"
  fi
  echo "========================================"
else
  echo "⛔ VALIDATION FAILED - Site creation may be incomplete"
  echo "========================================"
  exit 1
fi
