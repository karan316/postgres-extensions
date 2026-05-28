#!/bin/bash
# docker-entrypoint-wrapper.sh
# Custom entrypoint that validates extensions, configures shared_preload_libraries
# and SSL, then delegates to the official PostgreSQL entrypoint.
#
# Flow:
#   1. Validate EXTENSIONS env var against supported list
#   2. Write shared_preload_libraries to dynamic config
#   3. Generate SSL certificates if not provided
#   4. Launch background process to CREATE EXTENSION after PG is ready
#   5. Exec into official docker-entrypoint.sh

set -euo pipefail

SCRIPTS_DIR="/scripts"

# ---------------------------------------------------------------------------
# Only run extension/SSL setup when starting postgres
# ---------------------------------------------------------------------------
if [ "${1:-}" = 'postgres' ] || [[ "${1:-}" == -* ]]; then

    echo "INFO: [entrypoint] Configuring postgres-extensions image..."

    # --- Validate & configure extensions ---
    source "${SCRIPTS_DIR}/configure-extensions.sh"

    # --- Set up SSL certificates ---
    source "${SCRIPTS_DIR}/configure-ssl.sh"

    # --- Background: enable extensions after PG accepts connections ---
    "${SCRIPTS_DIR}/enable-extensions.sh" &

    echo "INFO: [entrypoint] Starting PostgreSQL..."

    # Delegate to official entrypoint with our config file.
    # User-supplied -c flags are preserved and override our config.
    exec docker-entrypoint.sh "$@" -c config_file=/etc/postgresql/postgresql.conf
else
    # Non-postgres command (e.g. psql, bash) — pass through directly
    exec docker-entrypoint.sh "$@"
fi
