#!/bin/bash
# ./auto_setup_wizard.sh <backend-hostname>
set -e

echo "Running auto_setup_wizard.sh..."
trap 'echo "Finished auto_setup_wizard.sh"' EXIT

Y=$(date +%Y)
FY_START="$Y-01-01"
FY_END="$Y-12-31"

# Use jq to safely construct the JSON body
# The --arg flag handles escaping of any special characters in the password
KWARGS=$(jq -n \
  --arg currency "BRL" \
  --arg country "Brazil" \
  --arg timezone "America/Sao_Paulo" \
  --arg language "English" \
  --arg full_name "Luan Gabriel" \
  --arg email "lgotcfg@gmail.com" \
  --arg password "$MYSQL_ROOT_PASSWORD" \
  --arg company_name "Growatt" \
  --arg company_abbr "GRT" \
  --arg chart_of_accounts "Standard" \
  --arg fy_start_date "$FY_START" \
  --arg fy_end_date "$FY_END" \
  --argjson setup_demo 0 \
  '{
    "args": {
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
    }
  }')

echo "KWARGS (senha oculta):"
echo "$KWARGS" | jq '.args.password = "**********"'

# Check if setup wizard has been completed
echo "Checking setup status..."
SETUP_COMPLETE=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['System Settings', 'System Settings', 'setup_complete']" 2>/dev/null || echo "0")

echo "Setup complete status: $SETUP_COMPLETE"

if [ "$SETUP_COMPLETE" = "1" ]; then
    echo "⚠️ Setup wizard was already completed previously."
    
    # Check if company exists
    echo "Checking if company 'Growatt' exists..."
    COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
    
    if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
        echo "⚠️ Company does not exist even though setup was completed. Creating company manually..."
        
        # Create company directly
        bench --site "${SITE_NAME}" execute frappe.client.insert --args "{
            'doctype': 'Company',
            'company_name': 'Growatt',
            'abbr': 'GRT',
            'default_currency': 'BRL',
            'country': 'Brazil'
        }"
        
        echo "✅ Company 'Growatt' created successfully"
        
        # Set global defaults
        echo "Setting global defaults..."
        bench --site "${SITE_NAME}" execute frappe.client.set_value --args "['System Settings', 'System Settings', {'country': 'Brazil'}]"
        
        bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['Company', 'Growatt']"
        bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['currency', 'BRL']"
        
        echo "✅ Global defaults set: Company='Growatt', Currency='BRL'"
    else
        echo "✅ Company 'Growatt' already exists: $COMPANY_EXISTS"
    fi
else
    echo "Running setup wizard for the first time..."
    bench --site "${SITE_NAME}" execute frappe.desk.page.setup_wizard.setup_wizard.setup_complete --kwargs "${KWARGS}"
    echo "✅ Setup wizard completed successfully"
fi

echo "Finished auto_setup_wizard.sh"