#!/bin/bash
# Run all database migration scripts in order
# Tracks applied migrations to avoid re-running

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source .env file
if [[ -f "${REPO_ROOT}/.env" ]]; then
    set -a
    source "${REPO_ROOT}/.env"
    set +a
fi

# Configuration
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5433}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_PASSWORD="${POSTGRES_PASSWORD:-}"
DB_NAME="${POSTGRES_DB:-postgres}"

export PGPASSWORD="${DB_PASSWORD}"

# Helper to run psql
run_psql() {
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" "$@"
}

# Check if migration was already applied
is_applied() {
    local filename="$1"
    run_psql -tAc "SELECT 1 FROM public.schema_migrations WHERE filename='${filename}'" 2>/dev/null | grep -q 1
}

# Record migration as applied
mark_applied() {
    local filename="$1"
    run_psql -c "INSERT INTO public.schema_migrations (filename) VALUES ('${filename}') ON CONFLICT DO NOTHING" > /dev/null
}

echo "=== Running DW Migrations ==="
echo "Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
echo ""

# Always run helper functions first (creates tracking table if needed)
helper_script="${SCRIPT_DIR}/00-helper-functions.sql"
if [[ -f "$helper_script" ]]; then
    echo "Running: 00-helper-functions.sql (always)..."
    run_psql -f "$helper_script" -v ON_ERROR_STOP=1 > /dev/null
    echo "  ✓ Done"
fi

# Run numbered scripts in order, skip if already applied
for script in "${SCRIPT_DIR}"/[0-9]*.sql; do
    if [[ -f "$script" ]]; then
        filename=$(basename "$script")
        
        # Skip helper functions (already ran)
        if [[ "$filename" == "00-helper-functions.sql" ]]; then
            continue
        fi
        
        if is_applied "$filename"; then
            echo "Skipping: ${filename} (already applied)"
        else
            echo "Running: ${filename}..."
            run_psql -f "$script" -v ON_ERROR_STOP=1
            mark_applied "$filename"
            echo "  ✓ Done"
        fi
    fi
done

echo ""
echo "=== Migrations complete ==="
echo ""
echo "Applied migrations:"
run_psql -c "SELECT filename, applied_at FROM public.schema_migrations ORDER BY applied_at;"
