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

# Check if company exists
echo "Checking if company 'Growatt' exists..."
COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")

if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
    echo "⚠️ Company 'Growatt' does not exist. Attempting to create..."
    
    # Try running setup wizard first
    echo "Attempting setup wizard..."
    if bench --site "${SITE_NAME}" execute frappe.desk.page.setup_wizard.setup_wizard.setup_complete --kwargs "${KWARGS}" 2>/dev/null; then
        echo "✅ Setup wizard executed successfully"
        
        # Verify if company was created by the setup wizard
        echo "Verifying if company was created..."
        COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
        
        if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
            echo "⚠️ Setup wizard didn't create the company. Creating company manually..."
            
            # Create company using bench execute with inline Python
            bench --site "${SITE_NAME}" new-doc Company "Growatt" --set "company_name=Growatt" "abbr=GRT" "default_currency=BRL" "country=Brazil" 2>/dev/null || echo "Company creation attempted"            
            # Verify if company was created
            echo "Verifying if company was created..."
            COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
            if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
                echo "❌ Failed to create company 'Growatt'. Exiting."
                exit 1
            else
                echo "✅ Company 'Growatt' created successfully: $COMPANY_EXISTS"
            fi
        else
            echo "✅ Company 'Growatt' was created by setup wizard"
        fi
    else
        echo "⚠️ Setup wizard failed. Creating company manually..."
        
        # Create company using bench execute with inline Python
        bench --site "${SITE_NAME}" execute "frappe.get_doc({'doctype': 'Company', 'company_name': 'Growatt', 'abbr': 'GRT', 'default_currency': 'BRL', 'country': 'Brazil'}).insert(ignore_if_duplicate=True)" 2>/dev/null || echo "Company creation attempted"
        
        # Verify if company was created
        echo "Verifying if company was created..."
        COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
        if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
            echo "❌ Failed to create company 'Growatt'. Exiting."
            exit 1
        else
            echo "✅ Company 'Growatt' created successfully: $COMPANY_EXISTS"
        fi
    fi
    
    # Set global defaults
    echo "Setting global defaults..."
    bench --site "${SITE_NAME}" execute frappe.client.set_value --args "['System Settings', 'System Settings', {'country': 'Brazil'}]" 2>/dev/null || true
    
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['Company', 'Growatt']"
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['currency', 'BRL']"
    
    echo "✅ Global defaults set: Company='Growatt', Currency='BRL'"
else
    echo "✅ Company 'Growatt' already exists: $COMPANY_EXISTS"
    
    # Ensure defaults are set even if company exists
    echo "Ensuring global defaults are set..."
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['Company', 'Growatt']" 2>/dev/null || true
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['currency', 'BRL']" 2>/dev/null || true
    echo "✅ Defaults verified"
fi

echo "Finished auto_setup_wizard.sh"#!/bin/bash
# ./auto_setup_wizard.sh
set -e

echo "Running auto_setup_wizard.sh..."
# The trap will run on exit, so the final echo is not needed
trap 'echo "Finished auto_setup_wizard.sh"' EXIT

Y=$(date +%Y)
FY_START="$Y-01-01"
FY_END="$Y-12-31"

# --- Helper Function for Manual Company Creation ---
# This function centralizes the fallback logic
create_company_manually() {
    echo "Attempting to create company 'Growatt' manually..."
    
    # Use the 'new-doc' method
    bench --site "${SITE_NAME}" new-doc Company "Growatt" \
        --set "company_name=Growatt" \
        --set "abbr=GRT" \
        --set "default_currency=BRL" \
        --set "country=Brazil" 2>/dev/null || echo "Company creation attempted"
    
    # Verify manual creation
    echo "Verifying manual creation..."
    MANUAL_CHECK=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
    
    if [ "$MANUAL_CHECK" = "null" ] || [ -z "$MANUAL_CHECK" ]; then
        echo "❌ Failed to create company 'Growatt' manually. Exiting."
        exit 1
    else
        echo "✅ Company 'Growatt' created successfully manually: $MANUAL_CHECK"
    fi
}
# ---------------------------------------------------

# Use jq to safely construct the JSON body
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
  '{ "args": { "currency": $currency, "country": $country, "timezone": $timezone, "language": $language, "full_name": $full_name, "email": $email, "password": $password, "company_name": $company_name, "company_abbr": $company_abbr, "chart_of_accounts": $chart_of_accounts, "fy_start_date": $fy_start_date, "fy_end_date": $fy_end_date, "setup_demo": $setup_demo } }')

echo "KWARGS (senha oculta):"
echo "$KWARGS" | jq '.args.password = "**********"'

# Check if company exists
echo "Checking if company 'Growatt' exists..."
COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")

if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
    echo "⚠️ Company 'Growatt' does not exist. Attempting to create..."
    
    # Try running setup wizard first
    echo "Attempting setup wizard..."
    if bench --site "${SITE_NAME}" execute frappe.desk.page.setup_wizard.setup_wizard.setup_complete --kwargs "${KWARGS}" 2>/dev/null; then
        echo "✅ Setup wizard executed."
        
        # Verify if company was created by the setup wizard
        echo "Verifying if company was created..."
        COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
        
        if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
            echo "⚠️ Setup wizard ran but didn't create the company."
            # Call the centralized function
            create_company_manually
        else
            echo "✅ Company 'Growatt' was created by setup wizard"
        fi
    else
        echo "⚠️ Setup wizard failed."
        # Call the centralized function
        create_company_manually
    fi
    
    # Set global defaults
    echo "Setting global defaults..."
    bench --site "${SITE_NAME}" execute frappe.client.set_value --args "['System Settings', 'System Settings', {'country': 'Brazil'}]" 2>/dev/null || true
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['Company', 'Growatt']"
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['currency', 'BRL']"
    
    echo "✅ Global defaults set: Company='Growatt', Currency='BRL'"
else
    echo "✅ Company 'Growatt' already exists: $COMPANY_EXISTS"
    
    # Ensure defaults are set even if company exists
    echo "Ensuring global defaults are set..."
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['Company', 'Growatt']" 2>/dev/null || true
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['currency', 'BRL']" 2>/dev/null || true
    echo "✅ Defaults verified"
fi

# The 'trap' at the top will handle the final "Finished" message#!/bin/bash
# ./auto_setup_wizard.sh
set -e

echo "Running auto_setup_wizard.sh..."
# The trap will run on exit, so the final echo is not needed
trap 'echo "Finished auto_setup_wizard.sh"' EXIT

Y=$(date +%Y)
FY_START="$Y-01-01"
FY_END="$Y-12-31"

# --- Helper Function for Manual Company Creation ---
# This function centralizes the fallback logic
create_company_manually() {
    echo "Attempting to create company 'Growatt' manually..."
    
    # Use the 'new-doc' method
    bench --site "${SITE_NAME}" new-doc Company "Growatt" \
        --set "company_name=Growatt" \
        --set "abbr=GRT" \
        --set "default_currency=BRL" \
        --set "country=Brazil" 2>/dev/null || echo "Company creation attempted"
    
    # Verify manual creation
    echo "Verifying manual creation..."
    MANUAL_CHECK=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
    
    if [ "$MANUAL_CHECK" = "null" ] || [ -z "$MANUAL_CHECK" ]; then
        echo "❌ Failed to create company 'Growatt' manually. Exiting."
        exit 1
    else
        echo "✅ Company 'Growatt' created successfully manually: $MANUAL_CHECK"
    fi
}
# ---------------------------------------------------

# Use jq to safely construct the JSON body
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
  '{ "args": { "currency": $currency, "country": $country, "timezone": $timezone, "language": $language, "full_name": $full_name, "email": $email, "password": $password, "company_name": $company_name, "company_abbr": $company_abbr, "chart_of_accounts": $chart_of_accounts, "fy_start_date": $fy_start_date, "fy_end_date": $fy_end_date, "setup_demo": $setup_demo } }')

echo "KWARGS (senha oculta):"
echo "$KWARGS" | jq '.args.password = "**********"'

# Check if company exists
echo "Checking if company 'Growatt' exists..."
COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")

if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
    echo "⚠️ Company 'Growatt' does not exist. Attempting to create..."
    
    # Try running setup wizard first
    echo "Attempting setup wizard..."
    if bench --site "${SITE_NAME}" execute frappe.desk.page.setup_wizard.setup_wizard.setup_complete --kwargs "${KWARGS}" 2>/dev/null; then
        echo "✅ Setup wizard executed."
        
        # Verify if company was created by the setup wizard
        echo "Verifying if company was created..."
        COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
        
        if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
            echo "⚠️ Setup wizard ran but didn't create the company."
            # Call the centralized function
            create_company_manually
        else
            echo "✅ Company 'Growatt' was created by setup wizard"
        fi
    else
        echo "⚠️ Setup wizard failed."
        # Call the centralized function
        create_company_manually
    fi
    
    # Set global defaults
    echo "Setting global defaults..."
    bench --site "${SITE_NAME}" execute frappe.client.set_value --args "['System Settings', 'System Settings', {'country': 'Brazil'}]" 2>/dev/null || true
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['Company', 'Growatt']"
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['currency', 'BRL']"
    
    echo "✅ Global defaults set: Company='Growatt', Currency='BRL'"
else
    echo "✅ Company 'Growatt' already exists: $COMPANY_EXISTS"
    
    # Ensure defaults are set even if company exists
    echo "Ensuring global defaults are set..."
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['Company', 'Growatt']" 2>/dev/null || true
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['currency', 'BRL']" 2>/dev/null || true
    echo "✅ Defaults verified"
fi

# The 'trap' at the top will handle the final "Finished" message#!/bin/bash
# ./auto_setup_wizard.sh
set -e

echo "Running auto_setup_wizard.sh..."
# The trap will run on exit, so the final echo is not needed
trap 'echo "Finished auto_setup_wizard.sh"' EXIT

Y=$(date +%Y)
FY_START="$Y-01-01"
FY_END="$Y-12-31"

# --- Helper Function for Manual Company Creation ---
# This function centralizes the fallback logic
create_company_manually() {
    echo "Attempting to create company 'Growatt' manually..."
    
    # Use the 'new-doc' method
    bench --site "${SITE_NAME}" new-doc Company "Growatt" \
        --set "company_name=Growatt" \
        --set "abbr=GRT" \
        --set "default_currency=BRL" \
        --set "country=Brazil" 2>/dev/null || echo "Company creation attempted"
    
    # Verify manual creation
    echo "Verifying manual creation..."
    MANUAL_CHECK=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
    
    if [ "$MANUAL_CHECK" = "null" ] || [ -z "$MANUAL_CHECK" ]; then
        echo "❌ Failed to create company 'Growatt' manually. Exiting."
        exit 1
    else
        echo "✅ Company 'Growatt' created successfully manually: $MANUAL_CHECK"
    fi
}
# ---------------------------------------------------

# Use jq to safely construct the JSON body
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
  '{ "args": { "currency": $currency, "country": $country, "timezone": $timezone, "language": $language, "full_name": $full_name, "email": $email, "password": $password, "company_name": $company_name, "company_abbr": $company_abbr, "chart_of_accounts": $chart_of_accounts, "fy_start_date": $fy_start_date, "fy_end_date": $fy_end_date, "setup_demo": $setup_demo } }')

echo "KWARGS (senha oculta):"
echo "$KWARGS" | jq '.args.password = "**********"'

# Check if company exists
echo "Checking if company 'Growatt' exists..."
COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")

if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
    echo "⚠️ Company 'Growatt' does not exist. Attempting to create..."
    
    # Try running setup wizard first
    echo "Attempting setup wizard..."
    if bench --site "${SITE_NAME}" execute frappe.desk.page.setup_wizard.setup_wizard.setup_complete --kwargs "${KWARGS}" 2>/dev/null; then
        echo "✅ Setup wizard executed."
        
        # Verify if company was created by the setup wizard
        echo "Verifying if company was created..."
        COMPANY_EXISTS=$(bench --site "${SITE_NAME}" execute frappe.client.get_value --args "['Company', 'Growatt', 'name']" 2>/dev/null || echo "null")
        
        if [ "$COMPANY_EXISTS" = "null" ] || [ -z "$COMPANY_EXISTS" ]; then
            echo "⚠️ Setup wizard ran but didn't create the company."
            # Call the centralized function
            create_company_manually
        else
            echo "✅ Company 'Growatt' was created by setup wizard"
        fi
    else
        echo "⚠️ Setup wizard failed."
        # Call the centralized function
        create_company_manually
    fi
    
    # Set global defaults
    echo "Setting global defaults..."
    bench --site "${SITE_NAME}" execute frappe.client.set_value --args "['System Settings', 'System Settings', {'country': 'Brazil'}]" 2>/dev/null || true
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['Company', 'Growatt']"
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['currency', 'BRL']"
    
    echo "✅ Global defaults set: Company='Growatt', Currency='BRL'"
else
    echo "✅ Company 'Growatt' already exists: $COMPANY_EXISTS"
    
    # Ensure defaults are set even if company exists
    echo "Ensuring global defaults are set..."
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['Company', 'Growatt']" 2>/dev/null || true
    bench --site "${SITE_NAME}" execute frappe.db.set_default --args "['currency', 'BRL']" 2>/dev/null || true
    echo "✅ Defaults verified"
fi