#!/bin/bash

# Database Verification Script
# Verifies that the database is properly initialized for Supabase

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Supabase Database Verification${NC}"
echo "=================================="

# Check if database container is running
if ! docker ps --format "table {{.Names}}" | grep -q "^supabase-db$"; then
    echo -e "${RED}❌ Database container is not running${NC}"
    echo "Start it with: docker compose up -d db"
    exit 1
fi

echo -e "${GREEN}✅ Database container is running${NC}"

# Check if PostgreSQL is ready
echo -n "Checking PostgreSQL readiness... "
if docker exec supabase-db pg_isready -U postgres -h localhost >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Ready${NC}"
else
    echo -e "${RED}❌ Not ready${NC}"
    exit 1
fi

# Check databases
echo ""
echo -e "${BLUE}📋 Database List:${NC}"
docker exec supabase-db psql -U postgres -l

# Check if _supabase database exists
echo ""
echo -n "Checking _supabase database... "
if docker exec supabase-db psql -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "_supabase"; then
    echo -e "${GREEN}✅ Exists${NC}"
else
    echo -e "${RED}❌ Missing${NC}"
    echo "The _supabase database is required for analytics"
    exit 1
fi

# Check users
echo ""
echo -e "${BLUE}👥 Database Users:${NC}"
docker exec supabase-db psql -U postgres -d postgres -c "SELECT rolname, rolsuper, rolcreaterole, rolcanlogin FROM pg_roles WHERE rolname LIKE '%supabase%' OR rolname = 'postgres';"

# Check if supabase_admin user exists
echo ""
echo -n "Checking supabase_admin user... "
if docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='supabase_admin'" 2>/dev/null | grep -q "1"; then
    echo -e "${GREEN}✅ Exists${NC}"
else
    echo -e "${RED}❌ Missing${NC}"
    echo "The supabase_admin user is required for analytics and other services"
    exit 1
fi

# Test supabase_admin connection to postgres database
echo ""
echo -n "Testing supabase_admin connection to postgres database... "
if docker exec supabase-db psql -U supabase_admin -d postgres -c "SELECT current_user;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Success${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi

# Test supabase_admin connection to _supabase database
echo -n "Testing supabase_admin connection to _supabase database... "
if docker exec supabase-db psql -U supabase_admin -d _supabase -c "SELECT current_user;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Success${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
    echo "This connection is required for analytics to work"
    exit 1
fi

# Check schemas in _supabase database
echo ""
echo -e "${BLUE}📊 Schemas in _supabase database:${NC}"
docker exec supabase-db psql -U supabase_admin -d _supabase -c "SELECT schema_name FROM information_schema.schemata;"

# Test analytics database connection string
echo ""
echo -n "Testing analytics database connection string... "
POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d'=' -f2)
if [ -n "$POSTGRES_PASSWORD" ]; then
    # Test the exact connection string that analytics uses
    if docker exec supabase-db psql "postgresql://supabase_admin:${POSTGRES_PASSWORD}@localhost:5432/_supabase" -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Analytics connection string works${NC}"
    else
        echo -e "${RED}❌ Analytics connection string failed${NC}"
        echo "This is exactly what's causing the analytics container to crash"
    fi
else
    echo -e "${RED}❌ POSTGRES_PASSWORD not found in .env${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Database verification complete!${NC}"
echo ""
echo -e "${BLUE}💡 If analytics is still failing:${NC}"
echo "1. Check analytics logs: docker compose logs analytics"
echo "2. Restart analytics: docker compose restart analytics"
echo "3. Try the startup script: ./startup-simple.sh"
