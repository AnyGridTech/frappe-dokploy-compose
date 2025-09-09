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

wait-for-it -t 120 db-service"$ENV":3306
wait-for-it -t 120 redis-cache-service"$ENV":6379
wait-for-it -t 120 redis-queue-service"$ENV":6379

echo "Creating sites/apps.txt"
retry 10 5 "ls -1 apps > sites/apps.txt"

echo "Setting bench configurations"
retry 5 5 "bench set-config -g db_host $DB_HOST"
retry 5 5 "bench set-config -gp db_port $DB_PORT"
retry 5 5 "bench set-config -g redis_cache redis://$REDIS_CACHE"
retry 5 5 "bench set-config -g redis_queue redis://$REDIS_QUEUE"
retry 5 5 "bench set-config -g redis_socketio redis://$REDIS_QUEUE"
retry 5 5 "bench set-config -gp socketio_port $SOCKETIO_PORT"

echo "Finished configurator_setup.sh"