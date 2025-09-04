#!/bin/bash
# ./install_apps.sh <backend-hostname>
set -e

echo "Running install_apps.sh..."

SITE_NAME="$1"

if [ -z "$SITE_NAME" ]; then
  echo "❌ SITE_NAME is required"
  exit 1
fi

echo "🔄 Getting app frappe_comment_xt..."
bench get-app frappe_comment_xt https://github.com/rtCamp/frappe-comment-xt.git

echo "🔧 Setting up Python and Node requirements..."
bench setup requirements

echo "✅ Installing app frappe_comment_xt on site $SITE_NAME..."
bench --site "$SITE_NAME" install-app frappe_comment_xt

echo "🔄 Clearing cache..."
bench --site "$SITE_NAME" clear-cache
bench --site "$SITE_NAME" clear-website-cache

echo "🔄 Running migrations..."
bench --site "$SITE_NAME" migrate

echo "🔄 Restarting bench services..."
bench restart

echo "Finished install_apps.sh"