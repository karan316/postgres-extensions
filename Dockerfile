ARG PG_VERSION=18
FROM postgres:${PG_VERSION}-bookworm

# Re-declare ARG after FROM (Docker requirement)
ARG PG_VERSION=18
ARG PGVECTOR_VERSION=0.8.2
ARG PGMQ_VERSION=1.11.1

LABEL org.opencontainers.image.source="https://github.com/karan316/postgres-extensions"
LABEL org.opencontainers.image.description="PostgreSQL ${PG_VERSION} with pre-built extensions"
LABEL org.opencontainers.image.licenses="MIT"

# ---------------------------------------------------------------------------
# 1. Install APT-based extensions and runtime dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-${PG_VERSION}-postgis-3 \
    postgresql-${PG_VERSION}-postgis-3-scripts \
    postgresql-${PG_VERSION}-cron \
    postgresql-${PG_VERSION}-partman \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Compile source-based extensions, then clean up build dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    postgresql-server-dev-${PG_VERSION} \
    # pgvector
    && cd /tmp \
    && git clone --branch v${PGVECTOR_VERSION} --depth 1 https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make OPTFLAGS="" \
    && make install \
    # pgmq
    && cd /tmp \
    && git clone --branch v${PGMQ_VERSION} --depth 1 https://github.com/pgmq/pgmq.git \
    && cd pgmq/pgmq-extension \
    && make \
    && make install \
    # Cleanup
    && cd / \
    && rm -rf /tmp/pgvector /tmp/pgmq \
    && apt-get purge -y --auto-remove \
        build-essential \
        git \
        postgresql-server-dev-${PG_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 3. Copy scripts and configuration
# ---------------------------------------------------------------------------
COPY scripts/ /scripts/
COPY config/postgresql.conf /etc/postgresql/postgresql.conf

RUN chmod +x /scripts/*.sh \
    && mkdir -p /etc/postgresql/conf.d \
    && mkdir -p /var/lib/postgresql/ssl

# ---------------------------------------------------------------------------
# 4. Entrypoint & healthcheck
# ---------------------------------------------------------------------------
ENTRYPOINT ["/scripts/docker-entrypoint-wrapper.sh"]
CMD ["postgres"]

HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD pg_isready -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}"

EXPOSE 5432
