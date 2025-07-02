#!/bin/bash

# Supabase Self-Hosted Health Check Script
# This script provides a comprehensive status report of all Supabase services

set -e

echo "🔍 Supabase Self-Hosted Health Check"
echo "======================================"
echo ""

# Function to check HTTP service
check_http() {
    local service_name="$1"
    local url="$2"
    local expected_code="$3"
    
    if response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null); then
        if [ "$response_code" = "$expected_code" ]; then
            echo "✅ $service_name: Healthy (HTTP $response_code)"
        else
            echo "⚠️  $service_name: Unexpected response (HTTP $response_code, expected $expected_code)"
        fi
    else
        echo "❌ $service_name: Not accessible"
    fi
}

# Function to check Docker container status
check_container() {
    local container_name="$1"
    local service_name="$2"
    
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name.*healthy"; then
        echo "✅ $service_name: Container healthy"
    elif docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name.*Up"; then
        echo "⚠️  $service_name: Container running but not healthy"
    elif docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name"; then
        echo "❌ $service_name: Container exists but not running"
    else
        echo "❌ $service_name: Container not found"
    fi
}

echo "📊 Container Status:"
echo "-------------------"
check_container "supabase-db" "Database"
check_container "supabase-studio" "Studio Dashboard"
check_container "supabase-auth" "Authentication"
check_container "supabase-rest" "REST API"
check_container "realtime-dev.supabase-realtime" "Realtime"
check_container "supabase-storage" "Storage"
check_container "supabase-edge-functions" "Edge Functions"
check_container "supabase-kong" "API Gateway"
check_container "supabase-pooler" "Database Pooler"
check_container "supabase-analytics" "Analytics"
check_container "supabase-meta" "Meta API"
check_container "supabase-imgproxy" "Image Proxy"
check_container "supabase-vector" "Vector/Logs"

echo ""
echo "🌐 Service Accessibility:"
echo "-------------------------"
check_http "Studio Dashboard" "http://localhost:3000" "200"
check_http "API Gateway" "http://localhost:8000" "401"
check_http "Analytics Dashboard" "http://localhost:4000" "302"

echo ""
echo "🔌 Database Connectivity:"
echo "-------------------------"
if docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; then
    echo "✅ PostgreSQL: Ready and accepting connections"
else
    echo "❌ PostgreSQL: Not ready"
fi

# Check if key tables exist
if docker exec supabase-db psql -U postgres -d postgres -c "SELECT 1 FROM auth.users LIMIT 1;" >/dev/null 2>&1; then
    echo "✅ Auth Schema: Present and accessible"
else
    echo "⚠️  Auth Schema: Missing or inaccessible"
fi

if docker exec supabase-db psql -U postgres -d _supabase -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Analytics Database: Present and accessible"
else
    echo "⚠️  Analytics Database: Missing or inaccessible"
fi

echo ""
echo "📋 Quick Access URLs:"
echo "--------------------"
echo "🎨 Studio Dashboard:  http://localhost:3000"
echo "📈 Analytics:         http://localhost:4000"
echo "🌐 API Gateway:       http://localhost:8000"
echo "🗄️  Database (direct): postgresql://postgres:[password]@localhost:5432/postgres"
echo "🔄 Database (pooled): postgresql://postgres:[password]@localhost:6543/postgres"

echo ""
echo "💡 Tips:"
echo "--------"
echo "• If services show warnings, try: docker compose restart [service]"
echo "• For detailed logs: docker compose logs [service] -f"
echo "• For complete reset: ./reset.sh"
echo "• Full documentation: ./ACCESS_GUIDE.md"

echo ""
echo "Health check completed! ✨"
