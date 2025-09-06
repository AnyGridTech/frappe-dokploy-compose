#!/bin/bash
# ./install_apps.sh <backend-hostname>
set -e

echo "Running install_apps.sh..."
trap 'echo "Finished install_apps.sh"' EXIT

APPS_DIR="/home/frappe/frappe-bench/apps"
SITE_APPS_FILE="/home/frappe/frappe-bench/sites/apps.txt"

install_app() {
  local app_name=$1
  local repo_url=$2

  if [ ! -d "$APPS_DIR/$app_name" ]; then
    echo "🔄 Getting app $app_name..."
    bench get-app "$app_name" "$repo_url"
  else
    echo "✅ App $app_name already exists, skipping get-app."
  fi

  if grep -q "^$app_name$" "$SITE_APPS_FILE"; then
    echo "✅ App $app_name already listed in sites/apps.txt, skipping installation."
  else
    echo "✅ Installing app $app_name on site $SITE_NAME..."
    bench --site "$SITE_NAME" install-app "$app_name"
  fi

  echo "✅ Building app $app_name..."
  bench build --app "$app_name"
}

install_app frappe_comment_xt https://github.com/rtCamp/frappe-comment-xt.git

echo "🔧 Setting up Python and Node requirements..."
bench setup requirements

echo "🔄 Clearing cache..."
bench --site "$SITE_NAME" clear-cache
bench --site "$SITE_NAME" clear-website-cache

echo "🔄 Running migrations..."
bench --site "$SITE_NAME" migrate

echo "🔄 Restarting bench services..."
bench restart