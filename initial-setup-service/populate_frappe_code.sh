#!/bin/bash
# ./initial_setup.sh
set -e

echo "Running initial_setup.sh..."

echo "🔎 Checking if bind is already populated..."
if [ ! -d /mnt/apps/frappe ] || [ ! -d /mnt/apps/erpnext ]; then
  echo "📦 Populating /mnt/apps from image..."
  cp -r /home/frappe/frappe-bench/apps/* /mnt/apps/
  chown -R 1000:1000 /mnt/apps || true
  echo "✅ apps/ populated."
else
  echo "✅ apps/ is already populated."
fi

echo "Finished initial_setup.sh"