#!/bin/bash

# Supabase Service Monitor
# This script monitors the health and status of all Supabase services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check service health
check_service() {
    local service_name=$1
    local container_name=$2
    local health_url=$3
    
    printf "%-20s " "$service_name:"
    
    # Check if container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "^$container_name$"; then
        echo -e "${RED}STOPPED${NC}"
        return 1
    fi
    
    # Check container health status
    local health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || echo "not_found")
    
    case $health_status in
        "healthy")
            echo -e "${GREEN}HEALTHY${NC}"
            return 0
            ;;
        "unhealthy")
            echo -e "${RED}UNHEALTHY${NC}"
            return 1
            ;;
        "starting")
            echo -e "${YELLOW}STARTING${NC}"
            return 1
            ;;
        "none")
            # No health check defined, check if container is running
            local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not found")
            if [ "$status" = "running" ]; then
                echo -e "${BLUE}RUNNING${NC}"
                return 0
            else
                echo -e "${RED}$status${NC}"
                return 1
            fi
            ;;
        "not_found")
            echo -e "${RED}NOT FOUND${NC}"
            return 1
            ;;
        *)
            echo -e "${YELLOW}UNKNOWN ($health_status)${NC}"
            return 1
            ;;
    esac
}

# Function to check service URL
check_url() {
    local url=$1
    local expected_status=${2:-200}
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_status"; then
        return 0
    else
        return 1
    fi
}

# Main monitoring function
monitor_services() {
    echo -e "${BLUE}🔍 Supabase Service Health Check${NC}"
    echo "=================================="
    
    # Core infrastructure
    check_service "Vector (Logging)" "supabase-vector" "http://localhost:9001/health"
    check_service "Database" "supabase-db" ""
    check_service "Analytics" "supabase-analytics" "http://localhost:4000/health"
    
    echo ""
    
    # Core services
    check_service "Auth" "supabase-auth" "http://localhost:9999/health"
    check_service "REST API" "supabase-rest" ""
    check_service "Realtime" "realtime-dev.supabase-realtime" ""
    check_service "Meta" "supabase-meta" ""
    check_service "Storage" "supabase-storage" "http://localhost:5000/status"
    check_service "ImgProxy" "supabase-imgproxy" ""
    
    echo ""
    
    # Additional services
    check_service "Edge Functions" "supabase-edge-functions" ""
    check_service "Kong (Gateway)" "supabase-kong" ""
    check_service "Pooler" "supabase-pooler" "http://localhost:4000/api/health"
    check_service "Studio" "supabase-studio" ""
    
    echo ""
    echo -e "${BLUE}🌐 Service URLs${NC}"
    echo "==============="
    
    # Check external URLs
    printf "%-20s " "Studio:"
    if check_url "http://localhost:3000" 200; then
        echo -e "${GREEN}http://localhost:3000${NC}"
    else
        echo -e "${RED}http://localhost:3000 (Not accessible)${NC}"
    fi
    
    printf "%-20s " "API Gateway:"
    if check_url "http://localhost:8000" 404; then  # 404 is expected for root
        echo -e "${GREEN}http://localhost:8000${NC}"
    else
        echo -e "${RED}http://localhost:8000 (Not accessible)${NC}"
    fi
    
    printf "%-20s " "Analytics:"
    if check_url "http://localhost:4000/health" 200; then
        echo -e "${GREEN}http://localhost:4000${NC}"
    else
        echo -e "${RED}http://localhost:4000 (Not accessible)${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}💾 Database Connection${NC}"
    echo "====================="
    
    # Test database connection
    if docker exec supabase-db pg_isready -U postgres -h localhost >/dev/null 2>&1; then
        echo -e "Database:            ${GREEN}READY${NC}"
        echo "Connection:          postgresql://postgres:***@localhost:5432/postgres"
        echo "Pooler:              postgresql://postgres:***@localhost:6543/postgres"
    else
        echo -e "Database:            ${RED}NOT READY${NC}"
    fi
}

# Function to show logs for a specific service
show_logs() {
    local service=$1
    echo -e "${BLUE}📋 Logs for $service${NC}"
    echo "=========================="
    docker compose logs --tail=50 -f "$service"
}

# Function to restart a service
restart_service() {
    local service=$1
    echo -e "${YELLOW}🔄 Restarting $service${NC}"
    docker compose restart "$service"
    echo -e "${GREEN}✅ $service restarted${NC}"
}

# Main script logic
case "${1:-monitor}" in
    "monitor"|"status")
        monitor_services
        ;;
    "logs")
        if [ -z "$2" ]; then
            echo "Usage: $0 logs <service-name>"
            echo "Available services: db, auth, rest, realtime, storage, functions, kong, studio, analytics, vector, meta, imgproxy, supavisor"
            exit 1
        fi
        show_logs "$2"
        ;;
    "restart")
        if [ -z "$2" ]; then
            echo "Usage: $0 restart <service-name>"
            exit 1
        fi
        restart_service "$2"
        ;;
    "help")
        echo "Supabase Service Monitor"
        echo ""
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  monitor, status    Show service health status (default)"
        echo "  logs <service>     Show logs for a specific service"
        echo "  restart <service>  Restart a specific service"
        echo "  help              Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                 # Show service status"
        echo "  $0 logs db         # Show database logs"
        echo "  $0 restart auth    # Restart auth service"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
