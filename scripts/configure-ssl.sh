#!/bin/bash
# configure-ssl.sh
# Generates a self-signed SSL certificate if none is provided.
# Users can mount custom certs at /var/lib/postgresql/ssl/.
# Sourced by docker-entrypoint-wrapper.sh — runs BEFORE PostgreSQL starts.

set -euo pipefail

SSL_DIR="/var/lib/postgresql/ssl"
SSL_CERT="${SSL_DIR}/server.crt"
SSL_KEY="${SSL_DIR}/server.key"

mkdir -p "$SSL_DIR"

if [[ -f "$SSL_CERT" && -f "$SSL_KEY" ]]; then
    echo "INFO: [ssl] Using existing SSL certificates at ${SSL_DIR}/"
else
    echo "INFO: [ssl] No SSL certificates found. Generating self-signed certificate..."
    openssl req -new -x509 -days 365 -nodes \
        -keyout "$SSL_KEY" \
        -out "$SSL_CERT" \
        -subj "/CN=postgres" \
        -addext "subjectAltName=DNS:localhost,DNS:postgres,IP:127.0.0.1" \
        2>/dev/null
    echo "INFO: [ssl] Self-signed certificate generated (valid for 365 days)."
fi

# PostgreSQL requires strict permissions on the key file
chmod 600 "$SSL_KEY"
chmod 644 "$SSL_CERT"
chown postgres:postgres "$SSL_CERT" "$SSL_KEY"
