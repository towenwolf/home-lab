#!/bin/bash
# Test script for PostgreSQL Data Warehouse connection
# Connects to the DWH and runs basic connectivity checks

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source .env file if it exists
if [[ -f "${REPO_ROOT}/.env" ]]; then
    set -a
    source "${REPO_ROOT}/.env"
    set +a
fi

# Configuration - uses environment variables or defaults
DW_HOST="${POSTGRES_HOST:-localhost}"
DW_PORT="${POSTGRES_PORT:-5433}"
DW_USER="${POSTGRES_USER:-postgres}"
DW_PASSWORD="${POSTGRES_PASSWORD:-}"
DW_DATABASE="${POSTGRES_DB:-postgres}"

echo "=== Testing PostgreSQL DWH Connection ==="
echo ""
echo "Host: ${DW_HOST}"
echo "Port: ${DW_PORT}"
echo "Database: ${DW_DATABASE}"
echo "User: ${DW_USER}"
echo ""

# Export password for psql
export PGPASSWORD="${DW_PASSWORD}"

# Helper function to run psql
run_psql() {
    psql -h "${DW_HOST}" -p "${DW_PORT}" -U "${DW_USER}" -d "${DW_DATABASE}" "$@"
}

# Test 1: Basic connection
echo "1. Testing basic connection..."
if run_psql -c "SELECT 1 AS connection_test;" > /dev/null 2>&1; then
    echo "   ✓ Connection successful"
else
    echo "   ✗ Connection failed"
    exit 1
fi

echo ""
echo "---"
echo ""

# Test 2: Check PostgreSQL version
echo "2. PostgreSQL version..."
run_psql -t -c "SELECT version();"

echo ""
echo "---"
echo ""

# Test 3: List schemas
echo "3. Available schemas..."
run_psql -c "\dn"

echo ""
echo "---"
echo ""

# Test 4: List tables in all schemas
echo "4. Tables in database..."
run_psql -c "
SELECT 
    schemaname AS schema,
    tablename AS table,
    tableowner AS owner
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;
"

echo ""
echo "---"
echo ""

# Test 5: Check database size
echo "5. Database size..."
run_psql -c "
SELECT 
    pg_database.datname AS database,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
WHERE datname = current_database();
"

echo ""
echo "=== All tests passed ==="
