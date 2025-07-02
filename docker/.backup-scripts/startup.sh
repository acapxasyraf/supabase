#!/bin/bash

# Supabase Docker Startup Script
# This script ensures proper container startup order

set -e

echo "🚀 Starting Supabase with optimized container order..."

# Function to wait for container health
wait_for_health() {
    local container_name=$1
    local timeout=${2:-300}
    echo "⏳ Waiting for $container_name to be healthy..."
    
    for i in $(seq 1 $timeout); do
        # Check if container exists and is running
        if ! docker ps --format "table {{.Names}}" | grep -q "^$container_name$"; then
            echo "⏸️  $container_name is not running yet..."
            sleep 2
            continue
        fi
        
        # Check health status
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
        
        case $health_status in
            "healthy")
                echo "✅ $container_name is healthy"
                return 0
                ;;
            "unhealthy")
                echo "❌ $container_name is unhealthy"
                return 1
                ;;
            "starting")
                echo "🔄 $container_name is starting..."
                ;;
            "none")
                # No health check defined, assume healthy if running
                echo "✅ $container_name is running (no health check)"
                return 0
                ;;
            *)
                echo "🔍 $container_name status: $health_status"
                ;;
        esac
        
        sleep 2
    done
    
    echo "❌ $container_name failed to become healthy within ${timeout}s"
    return 1
}

# Step 1: Start core infrastructure (vector for logging)
echo "📋 Step 1: Starting logging infrastructure..."
docker compose up -d vector
wait_for_health "supabase-vector"

# Step 2: Start database
echo "🗄️  Step 2: Starting database..."
docker compose up -d db
wait_for_health "supabase-db"

# Step 3: Start analytics (depends on db)
echo "📊 Step 3: Starting analytics..."
docker compose up -d analytics
wait_for_health "supabase-analytics"

# Step 4: Start core services that depend on db
echo "🔧 Step 4: Starting core services..."
docker compose up -d auth rest realtime meta imgproxy
wait_for_health "supabase-auth"

# Step 5: Start storage (depends on rest and imgproxy)
echo "📁 Step 5: Starting storage..."
docker compose up -d storage
wait_for_health "supabase-storage"

# Step 6: Start edge functions
echo "⚡ Step 6: Starting edge functions..."
docker compose up -d functions

# Step 7: Start API gateway (Kong)
echo "🌐 Step 7: Starting API gateway..."
docker compose up -d kong

# Step 8: Start pooler
echo "🔄 Step 8: Starting database pooler..."
docker compose up -d supavisor
wait_for_health "supabase-pooler"

# Step 9: Start Studio (web interface)
echo "🎨 Step 9: Starting Studio dashboard..."
docker compose up -d studio
wait_for_health "supabase-studio"

echo "🎉 All Supabase services are now running!"
echo ""
echo "📍 Service URLs:"
echo "   • Supabase Studio: http://localhost:3000"
echo "   • API Gateway: http://localhost:8000"
echo "   • Database: localhost:5432"
echo "   • Analytics: http://localhost:4000"
echo "   • Pooler: localhost:6543"
echo ""
echo "🔑 Default credentials:"
echo "   • Database: postgres / $(grep POSTGRES_PASSWORD .env | cut -d'=' -f2)"
echo "   • Studio: $(grep DASHBOARD_USERNAME .env | cut -d'=' -f2) / $(grep DASHBOARD_PASSWORD .env | cut -d'=' -f2)"
