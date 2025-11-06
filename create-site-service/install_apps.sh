#!/bin/bash
# ./install_apps.sh <site-name> '<apps-json>'
# Example:
# bash ./install_apps.sh your-site-name.com '[
#   {
#     "name": "app1",
#     "url": "https://github.com/app1_repo.git",
#     "branch": "develop"
#   },
#   {
#     "name": "app2",
#     "url": "https://github.com/app2_repo.git",
#     "branch": "main"
#   }
# ]';
set -e

echo "Running install_apps.sh..."
trap 'echo "Finished install_apps.sh"' EXIT

APPS_DIR="/home/frappe/frappe-bench/apps"
SITE_APPS_FILE="/home/frappe/frappe-bench/sites/apps.txt"

SITE_NAME="$1"
APPS_JSON="$2"   # pass JSON array as second argument

# if length of apps_json is 0, exit
if [ -z "$APPS_JSON" ] || [ "$APPS_JSON" = "[]" ]; then
  echo "No apps to install. Exiting."
  exit 0
fi

# if site name is empty, exit
if [ -z "$SITE_NAME" ]; then
  echo "Site name not provided. Exiting."
  exit 1
fi

install_app() {
  local app_name=$1
  local repo_url=$2
  local branch=$3

  echo "📦 Installing app: $app_name"
  echo "🌐 Repo URL: ${repo_url:-<none>}"
  echo "🌿 Branch: ${branch:-<default>}"
  echo ""

  cd "$BENCH_DIR" || exit 1

  if [ ! -d "$APPS_DIR/$app_name" ]; then
    echo "🔄 Getting app $app_name..."
    if [ -z "$repo_url" ]; then
      bench get-app "$app_name"
    elif [ -z "$branch" ]; then
      bench get-app "$app_name" "$repo_url"
    else
      bench get-app "$app_name" "$repo_url" --branch "$branch"
    fi
  else
    echo "✅ App $app_name already exists, skipping get-app."
    echo "✅ Building app $app_name..."
    bench build --app "$app_name"
  fi

  echo "✅ Installing app $app_name on site $SITE_NAME..."
  bench --site "$SITE_NAME" install-app "$app_name"
}

# loop over array of {name, url, branch} objects in APPS_JSON
echo "$APPS_JSON" | jq -c '.[]' | while read -r app; do
  name=$(echo "$app" | jq -r '.name')
  url=$(echo "$app" | jq -r '.url')
  branch=$(echo "$app" | jq -r '.branch // empty')
  install_app "$name" "$url" "$branch"
done

echo "🔧 Setting up Python and Node requirements..."
bench setup requirements

echo "🔄 Clearing cache..."
bench --site "$SITE_NAME" clear-cache
bench --site "$SITE_NAME" clear-website-cache

echo "🔄 Running migrations..."
bench --site "$SITE_NAME" migrate

echo "🔄 Restarting bench services..."
bench restart
