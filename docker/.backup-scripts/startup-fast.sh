#!/bin/bash

# Supabase Docker Startup Script - Fast Version
# Starts services in the right order without waiting for health checks

set -e

echo "🚀 Starting Supabase services in optimized order..."

echo "📋 Step 1: Core infrastructure (Vector + Database)"
docker compose up -d vector db

echo "⏳ Waiting 10 seconds for database to initialize..."
sleep 10

echo "📊 Step 2: Analytics (depends on database)"
docker compose up -d analytics

echo "⏳ Waiting 5 seconds for analytics to start..."
sleep 5

echo "🔧 Step 3: Core services"
docker compose up -d auth rest realtime meta imgproxy storage

echo "⏳ Waiting 5 seconds for core services..."
sleep 5

echo "⚡ Step 4: Additional services"
docker compose up -d functions kong supavisor

echo "⏳ Waiting 5 seconds for additional services..."
sleep 5

echo "🎨 Step 5: Studio dashboard"
docker compose up -d studio

echo ""
echo "🎉 All Supabase services have been started!"
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
echo "ℹ️  Services are starting up. Use './monitor.sh' to check their status."
echo "📋 To view logs: './monitor.sh logs <service-name>'"
echo ""
echo "✨ Give it a minute or two and then access Studio at http://localhost:3000"
