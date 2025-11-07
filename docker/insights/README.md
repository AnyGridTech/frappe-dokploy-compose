# Frappe Insights Docker Compose Setup

This directory contains three Docker Compose configurations for Frappe Insights deployment:

## Configurations

### 1. docker-compose.test-local.yml
**Purpose:** Local development/testing  
**Site Name:** `bi-test.growatt.app`  
**Ports:** 
- Frontend: `http://localhost:8000`
- WebSocket: `http://localhost:9000`

**Usage:**
```bash
# Start
docker-compose -f docker-compose.test-local.yml up -d

# View logs
docker logs insights-frappe-1 -f

# Stop
docker-compose -f docker-compose.test-local.yml down

# Clean everything (including volumes)
docker-compose -f docker-compose.test-local.yml down -v
```

**Storage:** Uses Docker named volumes (no bind mounts required)

---

### 2. docker-compose.test-dokploy.yml
**Purpose:** Dokploy test environment deployment  
**Site Name:** `bi-test.growatt.app`  
**Ports:**
- Frontend: `http://localhost:8001`
- WebSocket: `http://localhost:9001`

**Requirements:**
- Create directory: `/home/insights-test/mariadb/data` on host
- dokploy-network must exist

**Usage:**
```bash
# On Dokploy server, create directories
sudo mkdir -p /home/insights-test/mariadb/data
sudo chown -R 999:999 /home/insights-test/mariadb/data

# Start
docker-compose -f docker-compose.test-dokploy.yml up -d
```

**Storage:** Uses bind mounts for persistent data

---

### 3. docker-compose.prod-dokploy.yml
**Purpose:** Dokploy production deployment  
**Site Name:** `bi.growatt.app`  
**Ports:**
- Frontend: `http://localhost:8002`
- WebSocket: `http://localhost:9002`

**Requirements:**
- Create directory: `/home/insights-prod/mariadb/data` on host  
- dokploy-network must exist

**Usage:**
```bash
# On Dokploy server, create directories
sudo mkdir -p /home/insights-prod/mariadb/data
sudo chown -R 999:999 /home/insights-prod/mariadb/data

# Start
docker-compose -f docker-compose.prod-dokploy.yml up -d
```

**Storage:** Uses bind mounts for persistent data

---

## Environment Variables

Create a `.env` file in this directory with:

```env
MYSQL_ROOT_PASSWORD=your_secure_password_here
```

---

## Initial Setup Time

The first startup takes **15-30 minutes** as it:
1. Initializes Python virtual environment
2. Clones Frappe framework
3. Installs Python dependencies
4. Installs Node.js dependencies
5. Gets Insights app
6. Creates the site
7. Installs Insights on the site

Subsequent startups are much faster (< 1 minute).

---

## Default Credentials

After the auto setup wizard runs:
- **URL:** `http://localhost:8000` (or respective port)
- **Username:** `Administrator`
- **Password:** Same as `MYSQL_ROOT_PASSWORD` from your .env file

⚠️ **Important:** The admin password is automatically set to match your MySQL root password for consistency!

---

## Accessing the Site

After setup completes, bench starts and serves the application on:
- **Port 8000:** Frappe web interface
- **Port 9000:** Socket.io for real-time features

---

## Troubleshooting

### Check if setup is complete:
```bash
docker logs insights-frappe-1 --tail 50
```

Look for: `✅ Setup complete! Starting bench...`

### Container keeps restarting:
```bash
# Check logs
docker logs insights-frappe-1

# If bench directory exists but site doesn't:
docker-compose down -v  # This removes volumes
docker-compose up -d    # Start fresh
```

### MariaDB connection issues:
- Ensure MariaDB is healthy: `docker ps` should show "(healthy)" status
- Check environment variable: `MYSQL_ROOT_PASSWORD` must match in .env and compose file

---

## Notes

- All configurations use MariaDB 10.8 (required for Frappe v15)
- Redis is used for caching and job queues
- Insights branch: `develop` (latest features)
- Frappe version: `version-15`
