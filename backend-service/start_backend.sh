#!/bin/bash
# ./start_backend.sh
set -e

echo "Running start_backend.sh..."

echo "🔧 Running bench setup requirements..."
cd /home/frappe/frappe-bench
bench setup requirements || {
  echo "❌ bench setup requirements failed"
  exit 1
}
echo "✅ Requirements installed"

echo "🚀 Starting gunicorn (frappe.app:application)..."

CPU_CORES=$(nproc --all || echo 1)
WORKERS=$(( 2 * CPU_CORES + 1 ))
THREADS=4

echo "🖥️  Detected $CPU_CORES CPU cores"
echo "⚙️  Configuring gunicorn with $WORKERS workers and $THREADS threads per worker"

/home/frappe/frappe-bench/env/bin/gunicorn \
  --chdir=/home/frappe/frappe-bench/sites \
  --bind=0.0.0.0:8000 \
  --threads=$THREADS \
  --workers=$WORKERS \
  --worker-class=gthread \
  --worker-tmp-dir=/dev/shm \
  --timeout=120 \
  --preload \
  frappe.app:application
