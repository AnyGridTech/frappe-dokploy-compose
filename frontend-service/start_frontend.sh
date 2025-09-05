#!/bin/bash
# ./start_frontend.sh

set -e

echo "Running start_frontend.sh..."

echo "🔧 Running bench setup requirements..."
cd /home/frappe/frappe-bench
bench setup requirements || {
  echo "❌ bench setup requirements failed"
  exit 1
}
echo "✅ Requirements installed"

echo "🚀 Starting frontend reverse-proxy (nginx-entrypoint.sh)..."

bash nginx-entrypoint.sh