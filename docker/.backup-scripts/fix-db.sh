#!/bin/bash

# Database Fix Script
# Manually creates required users and databases if initialization failed

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Supabase Database Fix Script${NC}"
echo "================================="

# Get password from .env
POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d'=' -f2)
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -e "${RED}❌ POSTGRES_PASSWORD not found in .env file${NC}"
    exit 1
fi

echo "Using POSTGRES_PASSWORD from .env file"

# Check if database container is running
if ! docker ps --format "table {{.Names}}" | grep -q "^supabase-db$"; then
    echo -e "${RED}❌ Database container is not running${NC}"
    echo "Starting database container..."
    docker compose up -d db
    sleep 10
fi

echo -e "${GREEN}✅ Database container is running${NC}"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
for i in $(seq 1 30); do
    if docker exec supabase-db pg_isready -U postgres -h localhost >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
        break
    fi
    sleep 2
done

echo ""
echo -e "${BLUE}🔧 Creating/fixing supabase_admin user...${NC}"

# Create supabase_admin user
docker exec supabase-db psql -U postgres -d postgres <<-EOSQL
	BEGIN;
	  -- Drop user if exists (to recreate with correct password)
	  DROP USER IF EXISTS supabase_admin;
	  
	  -- Create supabase_admin user
	  CREATE USER supabase_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
	  ALTER USER supabase_admin WITH PASSWORD '${POSTGRES_PASSWORD}';
	  
	  -- Grant necessary privileges
	  GRANT CONNECT ON DATABASE postgres TO supabase_admin;
	  GRANT USAGE ON SCHEMA public TO supabase_admin;
	  GRANT CREATE ON SCHEMA public TO supabase_admin;
	COMMIT;
EOSQL

echo -e "${GREEN}✅ supabase_admin user created${NC}"

echo ""
echo -e "${BLUE}🔧 Creating/fixing _supabase database...${NC}"

# Create _supabase database
docker exec supabase-db psql -U postgres <<-EOSQL
	-- Drop database if exists (to recreate cleanly)
	DROP DATABASE IF EXISTS _supabase;
	
	-- Create _supabase database
	CREATE DATABASE _supabase WITH OWNER postgres;
EOSQL

echo -e "${GREEN}✅ _supabase database created${NC}"

echo ""
echo -e "${BLUE}🔧 Setting up permissions on _supabase database...${NC}"

# Grant permissions on _supabase database
docker exec supabase-db psql -U postgres -d _supabase <<-EOSQL
	BEGIN;
	  -- Grant all privileges to supabase_admin
	  GRANT ALL PRIVILEGES ON DATABASE _supabase TO supabase_admin;
	  GRANT ALL PRIVILEGES ON SCHEMA public TO supabase_admin;
	  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO supabase_admin;
	  GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO supabase_admin;
	  GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO supabase_admin;
	  
	  -- Grant default privileges for future objects
	  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO supabase_admin;
	  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO supabase_admin;
	  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO supabase_admin;
	COMMIT;
EOSQL

echo -e "${GREEN}✅ Permissions set on _supabase database${NC}"

echo ""
echo -e "${BLUE}🔧 Creating _analytics schema...${NC}"

# Create _analytics schema (required by analytics container)
docker exec supabase-db psql -U postgres -d _supabase <<-EOSQL
	BEGIN;
	  -- Create _analytics schema if it doesn't exist
	  CREATE SCHEMA IF NOT EXISTS _analytics;
	  
	  -- Grant permissions to supabase_admin
	  GRANT ALL PRIVILEGES ON SCHEMA _analytics TO supabase_admin;
	  ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON TABLES TO supabase_admin;
	  ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON SEQUENCES TO supabase_admin;
	  ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON FUNCTIONS TO supabase_admin;
	COMMIT;
EOSQL

echo -e "${GREEN}✅ _analytics schema created${NC}"

echo ""
echo -e "${BLUE}🧪 Testing connections...${NC}"

# Test supabase_admin connection to postgres
echo -n "Testing supabase_admin → postgres database: "
if docker exec supabase-db psql -U supabase_admin -d postgres -c "SELECT current_user;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

# Test supabase_admin connection to _supabase
echo -n "Testing supabase_admin → _supabase database: "
if docker exec supabase-db psql -U supabase_admin -d _supabase -c "SELECT current_user;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

# Test analytics connection string
echo -n "Testing analytics connection string: "
if docker exec supabase-db psql "postgresql://supabase_admin:${POSTGRES_PASSWORD}@localhost:5432/_supabase" -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Database fix complete!${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "1. Restart analytics container: docker compose restart analytics"
echo "2. Or restart all services: ./startup-simple.sh"
echo "3. Check status: ./monitor.sh"
