#!/bin/bash
set -e

# This script creates the supabase_admin user with the password from environment variable
# It's executed during PostgreSQL initialization

echo "Creating supabase_admin user with dynamic password..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	BEGIN;
	  -- Create supabase_admin user if it doesn't exist
	  DO
	  \$\$
	  BEGIN
	    IF NOT EXISTS (
	      SELECT 1
	      FROM pg_roles
	      WHERE rolname = 'supabase_admin'
	    )
	    THEN
	      CREATE USER supabase_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
	      ALTER USER supabase_admin WITH PASSWORD '$POSTGRES_PASSWORD';
	    END IF;
	  END
	  \$\$;
	COMMIT;
EOSQL

echo "supabase_admin user created successfully with dynamic password"
