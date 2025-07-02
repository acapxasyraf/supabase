# Supabase Self-Hosted Access Guide

## 🚀 Getting Started

### Option 1: Optimized Startup (Recommended)
```bash
# Navigate to docker directory
cd "/path/to/supabase/docker"

# Use the optimized startup script
./startup.sh
```

### Option 2: Manual Docker Compose
```bash
# Standard startup
docker compose up -d

# Or with optimized dependencies
docker compose -f docker-compose.yml -f docker-compose.optimized.yml up -d
```

### Option 3: Step-by-step Startup
```bash
# 1. Start core infrastructure
docker compose up -d vector db

# 2. Wait for DB to be ready
docker compose logs db -f

# 3. Start analytics
docker compose up -d analytics

# 4. Start remaining services
docker compose up -d
```

## 📍 Service Access Points

### 🎨 Supabase Studio (Dashboard) ✅
- **URL:** http://localhost:3000
- **Username:** supabase
- **Password:** [DASHBOARD_PASSWORD from .env]
- **Status:** Healthy and accessible
- **Features:**
  - Database management
  - Authentication settings
  - API documentation
  - Real-time subscriptions
  - Storage browser
  - Edge functions manager

### 🗄️ PostgreSQL Database
- **Host:** localhost
- **Port:** 5432
- **Database:** postgres
- **Username:** postgres
- **Password:** [POSTGRES_PASSWORD from .env]
- **Connection String:** 
  ```
  postgresql://postgres:[POSTGRES_PASSWORD]@localhost:5432/postgres
  ```

### 🔄 Database Pooler (Supavisor)
- **Host:** localhost
- **Port:** 6543 (transaction pooling)
- **Connection String:**
  ```
  postgresql://postgres:[POSTGRES_PASSWORD]@localhost:6543/postgres
  ```

### 🌐 API Gateway (Kong)
- **Base URL:** http://localhost:8000
- **Headers required:**
  ```
  Authorization: Bearer [ANON_KEY or SERVICE_ROLE_KEY]
  apikey: [ANON_KEY or SERVICE_ROLE_KEY]
  ```

### 🔐 Authentication API
- **Base URL:** http://localhost:8000/auth/v1
- **Endpoints:**
  - Sign up: `POST /signup`
  - Sign in: `POST /signin`
  - Sign out: `POST /signout`
  - User info: `GET /user`

### 📊 REST API (PostgREST)
- **Base URL:** http://localhost:8000/rest/v1
- **Auto-generated from your database schema**
- **Example:** `GET /rest/v1/your_table`

### ⚡ Real-time API
- **WebSocket URL:** ws://localhost:8000/realtime/v1/websocket
- **HTTP URL:** http://localhost:8000/realtime/v1
- **Features:**
  - Database changes
  - Presence
  - Broadcast

### 🗂️ Storage API
- **Base URL:** http://localhost:8000/storage/v1
- **Endpoints:**
  - Upload: `POST /object/[bucket]/[path]`
  - Download: `GET /object/[bucket]/[path]`
  - List: `GET /object/list/[bucket]`

### ⚡ Edge Functions
- **Base URL:** http://localhost:8000/functions/v1
- **Deploy location:** `./volumes/functions/`
- **Invoke:** `POST /functions/v1/[function-name]`

### 📈 Analytics (Logflare) ✅
- **Dashboard URL:** http://localhost:4000
- **Status:** Healthy and monitoring all services
- **Access Token:** [LOGFLARE_PUBLIC_ACCESS_TOKEN from .env]
- **Features:**
  - Real-time log monitoring
  - Service health tracking
  - Custom dashboards
  - Alert configuration

## 🔧 Development Workflow

### 1. Database Management
```bash
# Connect to database
docker exec -it supabase-db psql -U postgres

# View logs
docker compose logs db -f

# Reset database
./reset.sh
```

### 2. Edge Functions Development
```bash
# Create function directory
mkdir -p ./volumes/functions/my-function

# Create function
cat > ./volumes/functions/my-function/index.ts << 'EOF'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  return new Response(
    JSON.stringify({ message: "Hello from Supabase Edge Functions!" }),
    { headers: { "Content-Type": "application/json" } }
  )
})
EOF

# Function will be auto-deployed
# Test: curl -X POST http://localhost:8000/functions/v1/my-function
```

### 3. Storage Setup
```bash
# Create storage bucket via Studio or API
curl -X POST http://localhost:8000/storage/v1/bucket \
  -H "Authorization: Bearer [SERVICE_ROLE_KEY]" \
  -H "Content-Type: application/json" \
  -d '{"id": "my-bucket", "name": "My Bucket", "public": true}'
```

### 4. Authentication Testing
```bash
# Sign up user
curl -X POST http://localhost:8000/auth/v1/signup \
  -H "Content-Type: application/json" \
  -H "apikey: [ANON_KEY]" \
  -d '{"email": "test@example.com", "password": "password123"}'
```

## 🔍 Troubleshooting

### Common Issues

1. **Services won't start:**
   ```bash
   # Check logs
   docker compose logs [service-name]
   
   # Restart specific service
   docker compose restart [service-name]
   ```

2. **Database connection issues:**
   ```bash
   # Check database health
   docker exec supabase-db pg_isready -U postgres
   
   # View database logs
   docker compose logs db
   ```

3. **Port conflicts:**
   ```bash
   # Check what's using ports
   lsof -i :3000  # Studio
   lsof -i :8000  # Kong
   lsof -i :5432  # Database
   ```

4. **Reset everything:**
   ```bash
   ./reset.sh
   ```

### Health Checks
```bash
# Check all container status
docker compose ps

# Check specific service health
curl http://localhost:8000/health  # Kong
curl http://localhost:4000/health  # Analytics
curl http://localhost:3000/api/health  # Studio
```

## 🔐 Security Notes

- Change all default passwords in `.env` before production
- Use SERVICE_ROLE_KEY only for administrative tasks
- Use ANON_KEY for client-side applications
- Enable Row Level Security (RLS) on your tables
- Configure proper CORS settings for your domain

## 📚 Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Self-hosting Guide](https://supabase.com/docs/guides/self-hosting)
- [API Reference](https://supabase.com/docs/reference)
- [Edge Functions Documentation](https://supabase.com/docs/guides/functions)
