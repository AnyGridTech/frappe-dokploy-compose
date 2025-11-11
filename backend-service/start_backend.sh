#!/bin/bash
# ./start_backend.sh
set -e

echo "Running start_backend.sh..."

env="$1"
if [ "$env" = "dev" ]; then
  echo "🚀 Starting backend in development mode..."
  cd /home/frappe/frappe-bench || exit 1
  if [ ! -f "Procfile" ]; then
    echo "web: bench serve --port 8000" > Procfile
    echo "watch: bench watch" >> Procfile
  fi
  bench start
  exit 0
fi

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

echo "🏗️ Building production assets..."
bench build --verbose

echo "⚙️ Generating Nginx config for frontend..."
bench setup nginx --yes