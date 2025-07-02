\set pguser `echo "$POSTGRES_USER"`

\c _supabase
create schema if not exists _analytics;
alter schema _analytics owner to :pguser;
-- Grant supabase_admin access to _analytics schema
GRANT ALL PRIVILEGES ON SCHEMA _analytics TO supabase_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA _analytics TO supabase_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA _analytics TO supabase_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA _analytics TO supabase_admin;
-- Enable publication for logflare
CREATE PUBLICATION logflare_pub FOR ALL TABLES;
GRANT SELECT ON ALL TABLES IN SCHEMA _analytics TO supabase_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA _analytics GRANT ALL ON TABLES TO supabase_admin;
\c postgres
