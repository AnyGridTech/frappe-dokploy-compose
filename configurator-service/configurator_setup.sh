set -e

retry() {
  local attempts=$1; shift
  local delay=$1; shift
  local cmd="$@"
  echo "Running command: $cmd"
  for i in $(seq 1 $attempts); do
    if eval "$cmd"; then
      return 0
    fi
    sleep $delay
  done

  echo "⛔ All $attempts attempts failed for command: $cmd"
  return 1
}

force_sync_to_volume() {
  local file_path="$1"
  if [ ! -f "$file_path" ]; then
    echo "⚠️  File '$file_path' not found. Cannot sync to volume."
    return 1
  fi
  
  echo "Ensuring changes to '$file_path' are written to the shared volume..."
  python -c "
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
with open(path, 'w') as f:
    f.write(content)
" "$file_path"
  echo "✅ Sync complete for '$file_path'."
}

wait-for-it -t 120 db-service"$ENV":3306
wait-for-it -t 120 redis-cache-service"$ENV":6379
wait-for-it -t 120 redis-queue-service"$ENV":6379

echo "Creating sites/apps.txt"
retry 3 2 "ls -1 apps > sites/apps.txt"

echo "Setting bench configurations"

echo "Setup for production environment"
retry 3 2 "bench set-config -g db_host $DB_HOST"
retry 3 2 "bench set-config -gp db_port $DB_PORT"
retry 3 2 "bench set-config -g redis_cache redis://$REDIS_CACHE"
retry 3 2 "bench set-config -g redis_queue redis://$REDIS_QUEUE"
retry 3 2 "bench set-config -g redis_socketio redis://$REDIS_QUEUE"
retry 3 2 "bench set-config -gp socketio_port $SOCKETIO_PORT"

env="$1"

if [ "$env" = "dev" ]; then
  echo "Development environment setup"
  force_sync_to_volume "/home/frappe/frappe-bench/sites/common_site_config.json" 
fi

BENCH_DIR="/home/frappe/frappe-bench"
echo "Generated common_site_config.json:"
cat "$BENCH_DIR/sites/common_site_config.json"
echo ""

echo "Finished configurator_setup.sh"