#!/bin/bash
set -e

SITE_NAME="${SITE_NAME:-bi-test.growatt.app}"
ADMIN_PASSWORD="${MYSQL_ROOT_PASSWORD:-changeme123!}"
MARIADB_HOST="${MARIADB_HOST:-mariadb}"
REDIS_HOST="${REDIS_HOST:-redis}"
PRODUCTION="${PRODUCTION:-false}"

# Check if bench is fully initialized
if [ -f "/home/frappe/frappe-bench/sites/${SITE_NAME}/site_config.json" ]; then
    echo "✅ Bench and site already exist, starting..."
    cd /home/frappe/frappe-bench
    
    if [ "$PRODUCTION" = "true" ]; then
        echo "🚀 Starting in PRODUCTION mode..."
        
        # Calculate optimal workers based on CPU cores
        CPU_CORES=$(nproc --all || echo 1)
        WORKERS=$(( 2 * CPU_CORES + 1 ))
        THREADS=4
        
        echo "🖥️  Detected $CPU_CORES CPU cores"
        echo "⚙️  Starting with $WORKERS gunicorn workers and $THREADS threads per worker"
        
        # Start all services in background
        /home/frappe/frappe-bench/env/bin/gunicorn \
          --chdir=/home/frappe/frappe-bench/sites \
          --bind=0.0.0.0:8000 \
          --threads=$THREADS \
          --workers=$WORKERS \
          --worker-class=gthread \
          --worker-tmp-dir=/dev/shm \
          --timeout=120 \
          --preload \
          frappe.app:application &
        
        bench --site ${SITE_NAME} worker --queue short,default,long &
        bench --site ${SITE_NAME} schedule &
        node apps/frappe/socketio.js &
        
        echo "✅ All services started"
        wait
    else
        echo "🔧 Starting in DEVELOPMENT mode..."
        bench start
    fi
    exit 0
fi

# Check if bench directory already exists (but incomplete)
if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "⚠️  Found existing bench but site doesn't exist. This shouldn't happen."
    echo "Please delete the volume and try again: docker-compose down -v"
    exit 1
fi

echo "🚀 Creating new bench..."

# Initialize bench
cd /home/frappe
bench init --skip-redis-config-generation frappe-bench --version version-15

cd /home/frappe/frappe-bench

# Use containers instead of localhost
echo "⚙️  Configuring database and redis hosts..."
bench set-mariadb-host ${MARIADB_HOST}
bench set-redis-cache-host redis://${REDIS_HOST}:6379
bench set-redis-queue-host redis://${REDIS_HOST}:6379
bench set-redis-socketio-host redis://${REDIS_HOST}:6379

# Remove redis, watch from Procfile
echo "📝 Updating Procfile..."
sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

echo "📦 Getting Insights app..."
bench get-app insights --branch develop

echo "🏗️  Creating new site: ${SITE_NAME}..."
bench new-site ${SITE_NAME} \
  --force \
  --mariadb-root-password ${ADMIN_PASSWORD} \
  --admin-password ${ADMIN_PASSWORD} \
  --no-mariadb-socket

echo "🔧 Configuring site..."
bench --site ${SITE_NAME} set-config server_script_enabled 1
bench --site ${SITE_NAME} set-config developer_mode 0
bench --site ${SITE_NAME} set-config mute_emails 1

echo "📦 Installing Insights app..."
bench --site ${SITE_NAME} install-app insights

echo "🧹 Clearing cache..."
bench --site ${SITE_NAME} clear-cache

bench use ${SITE_NAME}

echo "✅ Setup complete! Starting bench..."

if [ "$PRODUCTION" = "true" ]; then
    echo "🚀 Starting in PRODUCTION mode..."
    
    # Calculate optimal workers based on CPU cores
    CPU_CORES=$(nproc --all || echo 1)
    WORKERS=$(( 2 * CPU_CORES + 1 ))
    THREADS=4
    
    echo "🖥️  Detected $CPU_CORES CPU cores"
    echo "⚙️  Starting with $WORKERS gunicorn workers and $THREADS threads per worker"
    
    # Start all services in background
    /home/frappe/frappe-bench/env/bin/gunicorn \
      --chdir=/home/frappe/frappe-bench/sites \
      --bind=0.0.0.0:8000 \
      --threads=$THREADS \
      --workers=$WORKERS \
      --worker-class=gthread \
      --worker-tmp-dir=/dev/shm \
      --timeout=120 \
      --preload \
      frappe.app:application &
    
    bench --site ${SITE_NAME} worker --queue short,default,long &
    bench --site ${SITE_NAME} schedule &
    node apps/frappe/socketio.js &
    
    echo "✅ All services started"
    wait
else
    echo "🔧 Starting in DEVELOPMENT mode..."
    bench start
fi
