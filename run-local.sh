#!/bin/bash
# ./run-local.sh - Run ERPNext Docker Compose locally

set -e

COMPOSE_FILE="docker/erpnext/docker-compose.test.yml"
ENV_FILE="docker/erpnext/.env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  .env file not found at $ENV_FILE"
    echo "Creating .env file..."
    read -sp "Enter MySQL root password: " MYSQL_PASSWORD
    echo ""
    echo "MYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD" > "$ENV_FILE"
    echo "✅ .env file created"
fi

# Parse command line arguments
ACTION="${1:-up}"

case "$ACTION" in
    up)
        echo "🚀 Starting ERPNext services..."
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
        echo "✅ Services started. Use './run-local.sh logs' to view logs"
        ;;
    down)
        echo "🛑 Stopping ERPNext services..."
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down
        ;;
    logs)
        SERVICE="${2:-}"
        if [ -z "$SERVICE" ]; then
            docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f
        else
            docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f "$SERVICE"
        fi
        ;;
    ps)
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
        ;;
    restart)
        echo "🔄 Restarting ERPNext services..."
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" restart
        ;;
    clean)
        echo "🧹 Cleaning up..."
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down -v
        echo "⚠️  Warning: This removed all volumes!"
        ;;
    *)
        echo "Usage: ./run-local.sh [command]"
        echo ""
        echo "Commands:"
        echo "  up       - Start services (default)"
        echo "  down     - Stop services"
        echo "  logs     - View logs (optionally specify service name)"
        echo "  ps       - List running services"
        echo "  restart  - Restart services"
        echo "  clean    - Stop services and remove volumes"
        echo ""
        echo "Examples:"
        echo "  ./run-local.sh"
        echo "  ./run-local.sh logs"
        echo "  ./run-local.sh logs create-site-service-test"
        echo "  ./run-local.sh down"
        exit 1
        ;;
esac
