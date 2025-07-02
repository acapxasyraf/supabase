#!/bin/bash

# Analytics Setup Script
# Ensures proper database setup for analytics container

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔧 Setting up Analytics Database Requirements${NC}"

# Get password from .env
POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d'=' -f2)

# Ensure analytics can connect properly
echo "Setting up analytics database permissions..."

docker exec supabase-db psql -U postgres -d _supabase <<-EOSQL
BEGIN;
    -- Ensure supabase_admin has all necessary privileges
    GRANT ALL PRIVILEGES ON DATABASE _supabase TO supabase_admin;
    GRANT ALL PRIVILEGES ON SCHEMA _analytics TO supabase_admin;
    GRANT ALL PRIVILEGES ON SCHEMA public TO supabase_admin;
    
    -- Grant sequence privileges
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA _analytics TO supabase_admin;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO supabase_admin;
    
    -- Grant table privileges  
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA _analytics TO supabase_admin;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO supabase_admin;
    
    -- Grant function privileges
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA _analytics TO supabase_admin;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO supabase_admin;
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON TABLES TO supabase_admin;
    ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON SEQUENCES TO supabase_admin;
    ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON FUNCTIONS TO supabase_admin;
    
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO supabase_admin;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO supabase_admin;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO supabase_admin;
    
    -- Ensure supabase_admin can create objects
    GRANT CREATE ON SCHEMA _analytics TO supabase_admin;
    GRANT CREATE ON SCHEMA public TO supabase_admin;
    
COMMIT;
EOSQL

echo -e "${GREEN}✅ Analytics database setup complete${NC}"

# Test the connection string that analytics uses
echo "Testing analytics connection..."
CONNECTION_STRING="postgresql://supabase_admin:${POSTGRES_PASSWORD}@db:5432/_supabase"

if docker exec supabase-db psql "$CONNECTION_STRING" -c "SELECT current_database(), current_user;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Analytics connection test successful${NC}"
else
    echo -e "${RED}❌ Analytics connection test failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}🔄 Now restart the analytics container:${NC}"
echo "docker compose restart analytics"
