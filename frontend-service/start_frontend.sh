#!/bin/bash
# ./start_frontend.sh

set -e

echo "Running start_frontend.sh..."

echo "� Frontend Configuration:"
echo "  SITE_NAME: ${SITE_NAME}"
echo "  BACKEND: ${BACKEND}"
echo "  FRAPPE_SITE_NAME_HEADER: ${FRAPPE_SITE_NAME_HEADER}"
echo "  SOCKETIO: ${SOCKETIO}"

echo "📁 Checking sites directory:"
ls -la /home/frappe/frappe-bench/sites/ || echo "⚠️ Sites directory not accessible"

echo "📝 Current site:"
cat /home/frappe/frappe-bench/sites/currentsite.txt || echo "⚠️ currentsite.txt not found"

echo "�🚀 Starting frontend reverse-proxy (nginx-entrypoint.sh)..."

bash nginx-entrypoint.sh