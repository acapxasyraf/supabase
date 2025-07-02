#!/bin/bash

# Supabase Environment Checker
# Validates that all required environment variables are set

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    echo "Please create a .env file based on .env.example"
    exit 1
fi

echo -e "${GREEN}🔍 Checking Supabase Environment Configuration${NC}"
echo "=============================================="

# Required variables
REQUIRED_VARS=(
    "POSTGRES_PASSWORD"
    "JWT_SECRET"
    "ANON_KEY"
    "SERVICE_ROLE_KEY"
    "DASHBOARD_USERNAME"
    "DASHBOARD_PASSWORD"
    "SECRET_KEY_BASE"
    "VAULT_ENC_KEY"
    "LOGFLARE_PUBLIC_ACCESS_TOKEN"
    "LOGFLARE_PRIVATE_ACCESS_TOKEN"
)

# Optional but recommended variables
OPTIONAL_VARS=(
    "SITE_URL"
    "API_EXTERNAL_URL"
    "SUPABASE_PUBLIC_URL"
    "OPENAI_API_KEY"
    "SMTP_HOST"
    "SMTP_PORT"
    "SMTP_USER"
    "SMTP_PASS"
)

check_var() {
    local var_name=$1
    local is_required=$2
    
    if grep -q "^${var_name}=" "$ENV_FILE"; then
        local value=$(grep "^${var_name}=" "$ENV_FILE" | cut -d'=' -f2)
        if [ -n "$value" ] && [ "$value" != "your-value-here" ] && [ "$value" != "change-me" ]; then
            echo -e "✅ ${var_name}: ${GREEN}SET${NC}"
            return 0
        else
            if [ "$is_required" = "true" ]; then
                echo -e "❌ ${var_name}: ${RED}EMPTY OR DEFAULT${NC}"
                return 1
            else
                echo -e "⚠️  ${var_name}: ${YELLOW}EMPTY OR DEFAULT${NC}"
                return 0
            fi
        fi
    else
        if [ "$is_required" = "true" ]; then
            echo -e "❌ ${var_name}: ${RED}MISSING${NC}"
            return 1
        else
            echo -e "⚠️  ${var_name}: ${YELLOW}MISSING${NC}"
            return 0
        fi
    fi
}

echo "Required Variables:"
echo "==================="
all_required_ok=true
for var in "${REQUIRED_VARS[@]}"; do
    if ! check_var "$var" "true"; then
        all_required_ok=false
    fi
done

echo ""
echo "Optional Variables:"
echo "==================="
for var in "${OPTIONAL_VARS[@]}"; do
    check_var "$var" "false"
done

echo ""

if [ "$all_required_ok" = "true" ]; then
    echo -e "${GREEN}✅ All required environment variables are set!${NC}"
    echo ""
    echo -e "${GREEN}🚀 You can now start Supabase with:${NC}"
    echo "   ./startup.sh"
    echo "   or"
    echo "   docker compose up -d"
    exit 0
else
    echo -e "${RED}❌ Some required environment variables are missing or empty!${NC}"
    echo ""
    echo -e "${YELLOW}📋 To fix this:${NC}"
    echo "1. Edit the .env file"
    echo "2. Set all required variables to proper values"
    echo "3. Make sure to change any default/placeholder values"
    echo ""
    echo -e "${YELLOW}💡 Security reminder:${NC}"
    echo "- Use strong, unique passwords"
    echo "- Generate proper JWT secrets (at least 32 characters)"
    echo "- Don't use default values in production"
    exit 1
fi
