#!/bin/bash
# ./auto_setup_wizard.sh <backend-hostname>
set -e

BACKEND_HOSTNAME="$1"

# 2. Verifica se o argumento foi realmente passado.
if [ -z "$BACKEND_HOSTNAME" ]; then
  echo "ERRO: O hostname do backend (test, dev, prod) não foi passado como argumento."
  echo "Uso: bash ./auto_setup_wizard.sh <backend-hostname>"
  echo "Exemplo: bash ./auto_setup_wizard.sh backend-service-test (ou -prod ou -dev)"
  exit 1
fi

echo "--- Iniciando setup wizard para o backend: $BACKEND_HOSTNAME ---"

echo "Waiting for backend ($BACKEND_HOSTNAME) to be available..."
wait-for-it -t 120 "$BACKEND_HOSTNAME:8000"
echo "Backend is available. Waiting 5 seconds for it to stabilize..."
sleep 5
echo "Running automated setup_wizard..."

Y=$(date +%Y)
FY_START="$Y-01-01"
FY_END="$Y-12-31"

# Use jq to safely construct the JSON body
# The --arg flag handles escaping of any special characters in the password
JSON_BODY=$(jq -n \
  --arg currency "BRL" \
  --arg country "Brazil" \
  --arg timezone "America/Sao_Paulo" \
  --arg language "English" \
  --arg full_name "Luan Gabriel" \
  --arg email "lgotcfg@gmail.com" \
  --arg password "$MYSQL_ROOT_PASSWORD" \
  --arg company_name "Growatt" \
  --arg company_abbr "GRT" \
  --arg chart_of_accounts "Brazil - Chart of Accounts" \
  --arg fy_start_date "$FY_START" \
  --arg fy_end_date "$FY_END" \
  --argjson setup_demo 0 \
  '{
    "currency": $currency,
    "country": $country,
    "timezone": $timezone,
    "language": $language,
    "full_name": $full_name,
    "email": $email,
    "password": $password,
    "company_name": $company_name,
    "company_abbr": $company_abbr,
    "chart_of_accounts": $chart_of_accounts,
    "fy_start_date": $fy_start_date,
    "fy_end_date": $fy_end_date,
    "setup_demo": $setup_demo
  }')

echo "$JSON_BODY"

set +e
# 3. Usa o hostname dinâmico na chamada curl.
http_code=$(curl -v -L \
  -o body.tmp \
  -w '%{http_code}' \
  -u "Administrator:$MYSQL_ROOT_PASSWORD" \
  -H "Host: $SITE_NAME" \
  -H "Content-Type: application/json" \
  -d "$JSON_BODY" \
  "http://${BACKEND_HOSTNAME}:8000/api/method/frappe.desk.page.setup_wizard.setup_wizard.setup_complete")
rc=$?
set -e

body=$(cat body.tmp)

echo "Curl exit code: $rc"
echo "HTTP status: $http_code"
echo "Host header: ${SITE_NAME:-not_set}"
echo "MYSQL_ROOT_PASSWORD length: ${#MYSQL_ROOT_PASSWORD}"
echo "---- Resposta recebida ----"
cat body.tmp

rm -f body.tmp

# Checagem final
if [ "$rc" -ne 0 ] || [ "$http_code" -ge 400 ]; then
  echo "😢 automated setup_wizard failed. curl exit code=\"$rc\" http_status=\"$http_code\""
  echo "---- JSON enviado ----"
  echo "$JSON_BODY"
  echo "---- Resposta recebida ----"
  echo "$body"
  exit 1
else
  echo "🚀 automated setup_wizard finished successfully for backend: $BACKEND_HOSTNAME"
fi