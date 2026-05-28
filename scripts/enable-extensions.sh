#!/bin/bash
# enable-extensions.sh
# Waits for PostgreSQL to accept connections, then runs
# CREATE EXTENSION IF NOT EXISTS for each requested extension.
# Runs as a background process — started by the entrypoint wrapper.

set -euo pipefail

# Graceful shutdown on container stop
trap 'exit 0' SIGTERM SIGINT

# ---------------------------------------------------------------------------
# Exit early if no extensions requested
# ---------------------------------------------------------------------------
if [[ -z "${EXTENSIONS:-}" ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# Parse the validated extension list
# ---------------------------------------------------------------------------
IFS=',' read -ra REQUESTED <<< "$EXTENSIONS"

# Build PG extension name lookup from exported mapping
declare -A PG_NAMES
if [[ -n "${PG_EXTENSION_MAP:-}" ]]; then
    for pair in ${PG_EXTENSION_MAP}; do
        key="${pair%%=*}"
        val="${pair#*=}"
        PG_NAMES["$key"]="$val"
    done
fi

DB="${POSTGRES_DB:-postgres}"
USER="${POSTGRES_USER:-postgres}"
MAX_RETRIES=60
RETRY=0

# ---------------------------------------------------------------------------
# Wait for PostgreSQL to be ready and the target database to exist
# ---------------------------------------------------------------------------
echo "INFO: [enable-extensions] Waiting for PostgreSQL to accept connections..."

until psql -U "$USER" -d "$DB" -c "SELECT 1" &>/dev/null; do
    RETRY=$((RETRY + 1))
    if [[ $RETRY -ge $MAX_RETRIES ]]; then
        echo "ERROR: [enable-extensions] PostgreSQL not ready after ${MAX_RETRIES}s. Skipping extension creation."
        exit 1
    fi
    sleep 1
done

echo "INFO: [enable-extensions] PostgreSQL is ready. Enabling extensions in database '$DB'..."

# ---------------------------------------------------------------------------
# Create each extension
# ---------------------------------------------------------------------------
FAILED=()

for ext in "${REQUESTED[@]}"; do
    ext=$(echo "$ext" | xargs)
    [[ -z "$ext" ]] && continue

    # Use the PG extension name if mapped, otherwise use the user-facing name
    pg_ext="${PG_NAMES[$ext]:-$ext}"

    echo "INFO: [enable-extensions] CREATE EXTENSION IF NOT EXISTS \"$pg_ext\";"
    if ! psql -v ON_ERROR_STOP=1 -U "$USER" -d "$DB" -c "CREATE EXTENSION IF NOT EXISTS \"$pg_ext\";" 2>&1; then
        echo "WARN: [enable-extensions] Failed to create extension: $ext ($pg_ext)"
        FAILED+=("$ext")
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "WARN: [enable-extensions] Some extensions failed to create: ${FAILED[*]}"
    echo "WARN: [enable-extensions] The database is running but these extensions are not available."
else
    echo "INFO: [enable-extensions] All extensions enabled successfully."
fi
