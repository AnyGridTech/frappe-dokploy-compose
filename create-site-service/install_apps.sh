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
#!/bin/bash
set -e

echo "Running install_apps.sh..."
trap 'echo "Finished install_apps.sh"' EXIT

# --- Define constants ---
BENCH_DIR="/home/frappe/frappe-bench"
APPS_DIR="$BENCH_DIR/apps"
SITE_NAME="$1"
APPS_JSON_PATH="$2" # pass file path as second argument

# if site name is empty, exit
if [ -z "$SITE_NAME" ]; then
  echo "Site name not provided. Exiting."
  exit 1
fi

# if apps file path is empty, exit
if [ -z "$APPS_JSON_PATH" ]; then
  echo "No apps file path provided. Exiting."
  exit 0
fi

# Check if the file exists
if [ ! -f "$APPS_JSON_PATH" ]; then
  echo "Apps file not found at: $APPS_JSON_PATH"
  exit 1
fi

# Read the JSON content from the file
APPS_JSON=$(cat "$APPS_JSON_PATH")

# if length of apps_json is 0, exit
if [ -z "$APPS_JSON" ] || [ "$APPS_JSON" = "[]" ]; then
  echo "No apps to install. Exiting."
  exit 0
fi

# --- Function to update existing app ---
update_app() {
  local app_name=$1
  local branch=$2

  echo "🔄 Updating app $app_name..."
  cd "$APPS_DIR/$app_name" || exit 1
  
  # Fetch latest changes
  if git fetch origin &>/dev/null; then
    echo "✅ Fetched latest changes from origin"
    
    # If branch is specified, checkout and pull that branch
    if [ -n "$branch" ]; then
      current_branch=$(git rev-parse --abbrev-ref HEAD)
      if [ "$current_branch" != "$branch" ]; then
        echo "🌿 Switching to branch: $branch"
        git checkout "$branch" || git checkout -b "$branch" "origin/$branch"
      fi
    fi
    
    # Pull latest changes
    if git pull origin "$(git rev-parse --abbrev-ref HEAD)" &>/dev/null; then
      echo "✅ Updated to latest changes"
    else
      echo "⚠️  Could not pull changes, continuing with current version"
    fi
  else
    echo "⚠️  Could not fetch from origin, continuing with current version"
  fi
  
  cd "$BENCH_DIR" || exit 1
}

# --- Function to configure git remote ---
configure_git_remote() {
  local app_name=$1
  local repo_url=$2

  cd "$APPS_DIR/$app_name" || exit 1
  
  if ! git remote get-url origin &>/dev/null; then
    echo "⚠️  Git remote 'origin' not configured. Setting it up..."
    if [ -n "$repo_url" ]; then
      git remote add origin "$repo_url" || git remote set-url origin "$repo_url"
      echo "✅ Git remote configured to: $repo_url"
    fi
  else
    echo "✅ Git remote already configured."
  fi
  
  cd "$BENCH_DIR" || exit 1
}

# --- Function to get app from repository ---
get_app_from_repo() {
  local app_name=$1
  local repo_url=$2
  local branch=$3

  echo "🔄 Getting app $app_name..."
  
  if [ -z "$repo_url" ]; then
    bench get-app "$app_name"
  elif [ -z "$branch" ]; then
    bench get-app "$app_name" "$repo_url"
  else
    bench get-app "$app_name" "$repo_url" --branch "$branch"
  fi
}

# --- Function to handle existing app directory ---
handle_existing_app() {
  local app_name=$1
  local repo_url=$2
  local branch=$3

  echo "📂 App $app_name directory exists. Checking git configuration..."
  
  if [ -d "$APPS_DIR/$app_name/.git" ]; then
    configure_git_remote "$app_name" "$repo_url"
    update_app "$app_name" "$branch"
  else
    echo "⚠️  Not a git repository. Removing and re-cloning..."
    rm -rf "$APPS_DIR/$app_name"
    get_app_from_repo "$app_name" "$repo_url" "$branch"
  fi
}

# --- Function to install app on site ---
install_app_on_site() {
  local app_name=$1

  echo "✅ Installing app $app_name on site $SITE_NAME..."
  bench --site "$SITE_NAME" install-app "$app_name"
  echo ""
}

# --- Function to install a single app ---
install_app() {
  local app_name=$1
  local repo_url=$2
  local branch=$3

  echo "📦 Installing app: $app_name"
  echo "🌐 Repo URL: ${repo_url:-<none>}"
  echo "🌿 Branch: ${branch:-<default>}"

  cd "$BENCH_DIR" || exit 1

  if [ -d "$APPS_DIR/$app_name" ]; then
    handle_existing_app "$app_name" "$repo_url" "$branch"
  else
    get_app_from_repo "$app_name" "$repo_url" "$branch"
  fi

  install_app_on_site "$app_name"
}

# --- Main execution ---
echo "$APPS_JSON" | jq -c '.[]' | while read -r app; do
  name=$(echo "$app" | jq -r '.name')
  url=$(echo "$app" | jq -r '.url')
  branch=$(echo "$app" | jq -r '.branch // empty')
  install_app "$name" "$url" "$branch"
done

echo "🔄 Running migrations for all apps..."
bench --site "$SITE_NAME" migrate

echo "🧹 Clearing cache..."
bench --site "$SITE_NAME" clear-cache
bench --site "$SITE_NAME" clear-website-cache

echo "✅ All apps installed successfully."