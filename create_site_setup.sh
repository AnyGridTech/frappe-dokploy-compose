#!/bin/bash
# ./create_site_setup.sh

set -e

echo "Running create_site_setup.sh"

wait-for-it -t 120 db-service-test:3306
wait-for-it -t 120 redis-cache-service-test:6379
wait-for-it -t 120 redis-queue-service-test:6379

start=$(date +%s)
max_wait_time=200
echo "Waiting for sites/common_site_config.json to be created"

until [[ -n $(grep -hs ^ sites/common_site_config.json | jq -r ".db_host // empty") ]] &&
  [[ -n $(grep -hs ^ sites/common_site_config.json | jq -r ".redis_cache // empty") ]] &&
  [[ -n $(grep -hs ^ sites/common_site_config.json | jq -r ".redis_queue // empty") ]];
do
  sleep 2
  if (( $(date +%s) - start > max_wait_time )); then
    echo "❌ could not find sites/common_site_config.json with required keys"
    exit 1
  fi
done


echo "sites/common_site_config.json found"
echo "Creating new site..."
bench new-site --mariadb-user-host-login-scope='%' \
  --admin-password=$${MYSQL_ROOT_PASSWORD} \
  --db-root-username=root --db-root-password=$${MYSQL_ROOT_PASSWORD} \
  --install-app erpnext \
  --set-default erp-test.growatt.app

echo "Finished create_site_setup.sh"