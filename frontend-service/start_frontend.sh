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
if [ -f /home/frappe/frappe-bench/sites/currentsite.txt ]; then
  cat /home/frappe/frappe-bench/sites/currentsite.txt
else
  echo "⚠️ currentsite.txt not found, creating it with SITE_NAME: ${SITE_NAME}"
  echo "${SITE_NAME}" > /home/frappe/frappe-bench/sites/currentsite.txt
  cat /home/frappe/frappe-bench/sites/currentsite.txt
fi
echo "🌐 Frontend service will listen on port 8080"
echo "🔗 Backend upstream: ${BACKEND}"
echo "🔗 Socketio upstream: ${SOCKETIO}"
echo "�🚀 Starting frontend reverse-proxy (nginx-entrypoint.sh)..."

bash nginx-entrypoint.sh