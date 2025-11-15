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

# --- Function to install a single app ---
install_app() {
  local app_name=$1
  local repo_url=$2
  local branch=$3

  echo "📦 Installing app: $app_name"
  echo "🌐 Repo URL: ${repo_url:-<none>}"
  echo "🌿 Branch: ${branch:-<default>}"

  cd "$BENCH_DIR" || exit 1

  # Get the app if it doesn't exist, or update if it does
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
    echo "📂 App $app_name directory exists. Checking for updates..."
    
    cd "$APPS_DIR/$app_name" || exit 1
    
    # Fetch latest changes from remote
    echo "🔄 Fetching latest changes..."
    git fetch origin
    
    # Get current commit hash
    current_commit=$(git rev-parse HEAD)
    
    # Get remote commit hash for the specified branch (or current branch)
    if [ -n "$branch" ]; then
      remote_commit=$(git rev-parse "origin/$branch")
      current_branch=$(git rev-parse --abbrev-ref HEAD)
      
      # Switch to the correct branch if needed
      if [ "$current_branch" != "$branch" ]; then
        echo "🔀 Switching to branch $branch..."
        git checkout "$branch"
      fi
    else
      current_branch=$(git rev-parse --abbrev-ref HEAD)
      remote_commit=$(git rev-parse "origin/$current_branch")
    fi
    
    # Compare commits
    if [ "$current_commit" != "$remote_commit" ]; then
      echo "🔄 Updates available. Pulling latest changes..."
      git pull origin "${branch:-$current_branch}"
      echo "✅ App $app_name updated successfully."
    else
      echo "✅ App $app_name is already up-to-date."
    fi
    
    cd "$BENCH_DIR" || exit 1
  fi

  # Install the app on the site (or update if already installed)
  if bench --site "$SITE_NAME" list-apps | grep -q "^$app_name$"; then
    echo "✅ App $app_name already installed on site $SITE_NAME, ensuring it's updated..."
  else
    echo "✅ Installing app $app_name on site $SITE_NAME..."
    bench --site "$SITE_NAME" install-app "$app_name"
  fi
  echo ""
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