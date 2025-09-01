echo "Waiting for backend to be available..."
wait-for-it -t 120 backend-service-test:8000
echo "Backend is available. Waiting 5 seconds for it to stabilize..."
sleep 5
echo "Running automated setup_wizard..."

Y=$(date +%Y)
FY_START="$Y-01-01"
FY_END="$Y-01-31"

# Usando um Here Document, que é muito mais legível que o JSON em uma linha
read -r -d '' JSON_BODY << EOF
{
    "currency": "BRL",
    "country": "Brazil",
    "timezone": "America/Sao_Paulo",
    "language": "English",
    "full_name": "Luan Gabriel",
    "email": "lgotcfg@gmail.com",
    "password": "$MYSQL_ROOT_PASSWORD",
    "company_name": "Growatt",
    "company_abbr": "GRT",
    "chart_of_accounts": "Brazil - Chart of Accounts",
    "fy_start_date": "$FY_START",
    "fy_end_date": "$FY_END",
    "setup_demo": 0
}
EOF

set +e # Desativa o 'exit on error' temporariamente para o curl
http_code=$(curl -sS -L \
  -o body.tmp \
  -w '%{http_code}' \
  -u "Administrator:$MYSQL_ROOT_PASSWORD" \
  -H "Host: $SITE_NAME" \
  -H "Content-Type: application/json" \
  -d "$JSON_BODY" \
  http://backend-service-test:8000/api/method/frappe.desk.page.setup_wizard.setup_wizard.setup_complete)
rc=$?
set -e # Reativa o 'exit on error'

body=$(cat body.tmp)
rm -f body.tmp

# Checagem final e output
if [ "$rc" -ne 0 ] || [ "$http_code" -ge 400 ]; then
  echo "😢 automated setup_wizard failed. curl exit code=\"$rc\" http_status=\"$http_code\""
  echo "---- JSON enviado para o servidor ----"
  echo "$JSON_BODY"
  echo "---- Resposta recebida (body) ----"
  echo "$body"
  exit 1
else
  echo "🚀 automated setup_wizard finished successfully."
fi