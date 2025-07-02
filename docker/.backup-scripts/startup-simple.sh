#!/bin/bash

# Supabase Docker Startup Script - Simple Version
# This script ensures proper container startup order without complex JSON parsing

set -e

echo "🚀 Starting Supabase with optimized container order..."

# Function to check if container is running
is_container_running() {
    local container_name=$1
    docker ps --format "table {{.Names}}" | grep -q "^$container_name$"
}

# Function to wait for container to be running
wait_for_container() {
    local container_name=$1
    local timeout=${2:-120}
    local service_name=$3
    
    echo "⏳ Starting and waiting for $service_name..."
    
    for i in $(seq 1 $timeout); do
        if is_container_running "$container_name"; then
            echo "✅ $service_name is running"
            return 0
        fi
        sleep 2
    done
    
    echo "❌ $service_name failed to start within ${timeout}s"
    return 1
}

# Function to wait for database to be ready
wait_for_database() {
    echo "⏳ Waiting for database to be ready..."
    
    for i in $(seq 1 60); do
        if docker exec supabase-db pg_isready -U postgres -h localhost >/dev/null 2>&1; then
            echo "✅ Database is ready"
            return 0
        fi
        sleep 2
    done
    
    echo "❌ Database failed to become ready"
    return 1
}

# Function to wait for database initialization to complete
wait_for_database_init() {
    echo "⏳ Waiting for database initialization to complete..."
    
    # Wait for supabase_admin user to be created
    for i in $(seq 1 30); do
        if docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='supabase_admin'" 2>/dev/null | grep -q "1"; then
            echo "✅ supabase_admin user exists"
            break
        fi
        echo "   Waiting for supabase_admin user... (attempt $i/30)"
        sleep 3
    done
    
    # Wait for _supabase database to be created
    for i in $(seq 1 30); do
        if docker exec supabase-db psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "_supabase"; then
            echo "✅ _supabase database exists"
            break
        fi
        echo "   Waiting for _supabase database... (attempt $i/30)"
        sleep 3
    done
    
    # Test supabase_admin connection to _supabase database
    echo "🔐 Testing supabase_admin database connection..."
    if docker exec supabase-db psql -U supabase_admin -d _supabase -c "SELECT version();" >/dev/null 2>&1; then
        echo "✅ supabase_admin can connect to _supabase database"
        return 0
    else
        echo "❌ supabase_admin cannot connect to _supabase database"
        echo "   This will cause analytics to fail. Checking logs..."
        docker compose logs db --tail=20
        return 1
    fi
}

# Function to check service health via HTTP
check_http_health() {
    local url=$1
    local service_name=$2
    local timeout=${3:-60}
    
    echo "⏳ Checking $service_name health..."
    
    for i in $(seq 1 $timeout); do
        if curl -s -f "$url" >/dev/null 2>&1; then
            echo "✅ $service_name is healthy"
            return 0
        fi
        sleep 2
    done
    
    echo "⚠️  $service_name may not be fully ready (continuing anyway)"
    return 0
}

echo "📋 Step 1: Starting logging infrastructure..."
docker compose up -d vector
wait_for_container "supabase-vector" 60 "Vector (Logging)"

echo ""
echo "🗄️  Step 2: Starting database..."
docker compose up -d db
wait_for_container "supabase-db" 120 "Database"
wait_for_database
wait_for_database_init

echo ""
echo "📊 Step 3: Starting analytics..."
docker compose up -d analytics
wait_for_container "supabase-analytics" 180 "Analytics"
check_http_health "http://localhost:4000/health" "Analytics"

echo ""
echo "🔧 Step 4: Starting core services..."
docker compose up -d auth rest realtime meta imgproxy
wait_for_container "supabase-auth" 60 "Auth Service"
wait_for_container "supabase-rest" 60 "REST API"
wait_for_container "realtime-dev.supabase-realtime" 60 "Realtime"
wait_for_container "supabase-meta" 60 "Meta API"
wait_for_container "supabase-imgproxy" 60 "Image Proxy"

echo ""
echo "📁 Step 5: Starting storage..."
docker compose up -d storage
wait_for_container "supabase-storage" 60 "Storage"

echo ""
echo "⚡ Step 6: Starting edge functions..."
docker compose up -d functions
wait_for_container "supabase-edge-functions" 60 "Edge Functions"

echo ""
echo "🌐 Step 7: Starting API gateway..."
docker compose up -d kong
wait_for_container "supabase-kong" 60 "Kong (API Gateway)"

echo ""
echo "🔄 Step 8: Starting database pooler..."
docker compose up -d supavisor
wait_for_container "supabase-pooler" 60 "Database Pooler"

echo ""
echo "🎨 Step 9: Starting Studio dashboard..."
docker compose up -d studio
wait_for_container "supabase-studio" 60 "Studio Dashboard"

echo ""
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
echo ""
echo "🔍 To monitor services: ./monitor.sh"
echo "📋 To view logs: ./monitor.sh logs <service-name>"
echo ""
echo "✨ Supabase is ready to use!"
