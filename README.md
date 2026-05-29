# Postgres Extensions

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/7gH7a-?referralCode=URrxaF&utm_medium=integration&utm_source=template&utm_campaign=generic)

A production-ready **PostgreSQL 18** Docker image with **11 popular extensions** pre-installed. Enable any combination at deploy time with a single environment variable — no compilation, no extra setup.

## Supported Extensions

| Extension            | Version | Description                                      |
| -------------------- | ------- | ------------------------------------------------ |
| `pgvector`           | 0.8.2   | Vector similarity search (HNSW, IVFFlat)         |
| `pg_trgm`            | 1.6     | Trigram-based fuzzy text search                  |
| `pgmq`               | 1.11.1  | Lightweight message queue (like SQS on Postgres) |
| `pg_cron`            | 1.6     | Cron-based job scheduler                         |
| `pg_stat_statements` | 1.12    | Query performance statistics                     |
| `pg_partman`         | 5.4.3   | Automated table partitioning                     |
| `pgcrypto`           | 1.4     | Cryptographic functions (hashing, encryption)    |
| `postgis`            | 3.6.3   | Geospatial data types and queries                |
| `uuid-ossp`          | 1.1     | UUID generation functions                        |
| `btree_gin`          | 1.3     | GIN indexes for standard data types              |
| `hstore`             | 1.8     | Key-value store column type                      |

## Quick Start

### Docker

```bash
docker run -d \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e EXTENSIONS="pgvector,pg_cron,pgmq" \
  -v pgdata:/var/lib/postgresql \
  -p 5432:5432 \
  ghcr.io/karan316/postgres-extensions:latest
```

### Docker Compose

```yaml
services:
  postgres:
    image: ghcr.io/karan316/postgres-extensions:latest
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp
      EXTENSIONS: "pgvector,pgmq,pg_cron,pg_stat_statements"
    volumes:
      - pgdata:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

Only the extensions you list in `EXTENSIONS` are enabled. Everything else stays dormant. Omit `EXTENSIONS` entirely for vanilla PostgreSQL.

## Deploy on Railway

Click the button above, or:

1. Create a new project on [Railway](https://railway.com)
2. Add a new service → **Docker Image** → `ghcr.io/karan316/postgres-extensions:latest`
3. Add a **volume** mounted at `/var/lib/postgresql`
4. Set environment variables:

| Variable            | Value                   |
| ------------------- | ----------------------- |
| `POSTGRES_PASSWORD` | your password           |
| `POSTGRES_DB`       | `myapp`                 |
| `EXTENSIONS`        | `pgvector,pgmq,pg_cron` |

5. Deploy — extensions are enabled automatically on first boot

> **Changing extensions later:** update the `EXTENSIONS` variable and redeploy. New extensions are added on the next boot; existing ones are unaffected (`CREATE EXTENSION IF NOT EXISTS` is idempotent).

## Environment Variables

| Variable            | Required | Default    | Description                                  |
| ------------------- | -------- | ---------- | -------------------------------------------- |
| `POSTGRES_PASSWORD` | **Yes**  | —          | Superuser password                           |
| `POSTGRES_USER`     | No       | `postgres` | Superuser name                               |
| `POSTGRES_DB`       | No       | `postgres` | Default database                             |
| `EXTENSIONS`        | No       | —          | Comma-separated list of extensions to enable |

### EXTENSIONS format

```bash
# Single extension
EXTENSIONS="pgvector"

# Multiple (spaces around commas are fine)
EXTENSIONS="pgvector, pgmq, pg_cron"

# All 11 extensions
EXTENSIONS="pgvector,pg_trgm,pgmq,pg_cron,pg_stat_statements,pg_partman,pgcrypto,postgis,uuid-ossp,btree_gin,hstore"
```

Invalid extension names cause the container to **exit immediately** with a clear error listing all supported extensions.

## Extension Usage Examples

### pgvector — Similarity search

```sql
CREATE TABLE items (id serial PRIMARY KEY, embedding vector(3));
INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]'), ('[7,8,9]');

-- Find closest vectors
SELECT id, embedding <-> '[3,3,3]' AS distance
FROM items ORDER BY distance LIMIT 2;
```

### pg_trgm — Fuzzy text search

```sql
SELECT title, word_similarity('Postgre', title) AS score
FROM articles
WHERE 'Postgre' <% title
ORDER BY score DESC;
```

### pgmq — Message queue

```sql
SELECT pgmq.create('tasks');
SELECT pgmq.send('tasks', '{"job": "send_email", "to": "user@example.com"}');
SELECT * FROM pgmq.read('tasks', 30, 1);
```

### pg_cron — Scheduled jobs

```sql
SELECT cron.schedule('nightly-cleanup', '0 3 * * *',
    $$DELETE FROM logs WHERE created_at < now() - interval '90 days'$$);
SELECT jobid, jobname, schedule FROM cron.job;
```

### pg_partman — Auto-partitioning

```sql
CREATE TABLE events (id serial, ts timestamptz NOT NULL DEFAULT now(), data text)
    PARTITION BY RANGE (ts);

SELECT create_parent(
    p_parent_table := 'public.events',
    p_control := 'ts',
    p_interval := '1 day'
);
```

### pgcrypto — Password hashing

```sql
-- Hash a password
INSERT INTO users (username, password_hash)
VALUES ('alice', crypt('password123', gen_salt('bf', 10)));

-- Verify a password
SELECT (password_hash = crypt('password123', password_hash)) AS valid
FROM users WHERE username = 'alice';
```

### postgis — Geospatial queries

```sql
-- Find stores within 5km of a point
SELECT name, round(ST_Distance(location,
    ST_SetSRID(ST_Point(-73.9857, 40.7484), 4326)::geography)::numeric) AS meters
FROM stores
WHERE ST_DWithin(location,
    ST_SetSRID(ST_Point(-73.9857, 40.7484), 4326)::geography, 5000)
ORDER BY meters;
```

### hstore — Key-value metadata

```sql
CREATE TABLE configs (id serial, app text, flags hstore);
INSERT INTO configs (app, flags) VALUES ('web', 'dark_mode => true, tier => pro');
SELECT app, flags -> 'tier' AS tier FROM configs WHERE flags -> 'dark_mode' = 'true';
```

## SSL / TLS

SSL is **enabled by default**. A self-signed certificate (4096-bit RSA, valid 365 days, TLS 1.2+) is auto-generated on first boot.

```bash
psql "postgresql://postgres:password@localhost:5432/postgres?sslmode=require"
```

**Bring your own certificates:**

```bash
docker run -d \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e EXTENSIONS="pgvector" \
  -v /path/to/server.crt:/var/lib/postgresql/ssl/server.crt:ro \
  -v /path/to/server.key:/var/lib/postgresql/ssl/server.key:ro \
  -p 5432:5432 \
  ghcr.io/karan316/postgres-extensions:latest
```

## How It Works

```
Container Start
      │
      ▼
┌─────────────────────────────┐
│  1. Validate EXTENSIONS     │  Exits with error if any names are invalid.
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│  2. Configure               │  Writes shared_preload_libraries dynamically
│     shared_preload_libraries│  (pg_cron, pg_stat_statements, pg_partman).
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│  3. Generate SSL certs      │  Self-signed cert if none mounted.
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│  4. Start PostgreSQL        │  Delegates to the official docker-entrypoint.sh.
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│  5. Enable extensions       │  Background process runs
│     (background)            │  CREATE EXTENSION IF NOT EXISTS for each.
└─────────────────────────────┘
```

## Adding a New Extension

1. **Install it in the Dockerfile** (APT or source):

   ```dockerfile
   RUN apt-get update && apt-get install -y postgresql-${PG_VERSION}-my-extension
   ```

2. **Register it in `scripts/extensions.conf`**:

   ```
   # Format: user_name:shared_preload_library:pg_extension_name
   my_extension::
   my_preloaded_ext:my_preloaded_ext:
   ```

3. **Rebuild:** `docker build -t postgres-extensions:18 .`

## Building Locally

```bash
docker build -t postgres-extensions:18 .

# Custom versions
docker build \
  --build-arg PGVECTOR_VERSION=0.8.2 \
  --build-arg PGMQ_VERSION=1.11.1 \
  -t postgres-extensions:18 .
```

## Verifying Extensions

```sql
-- List enabled extensions
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- List all available (installed but not necessarily enabled) extensions
SELECT name, default_version FROM pg_available_extensions ORDER BY name;

-- Check shared_preload_libraries
SHOW shared_preload_libraries;
```

## Notes

- **PostgreSQL 18+ data directory**: Data lives at `/var/lib/postgresql/18/docker`. Mount your volume at `/var/lib/postgresql` (not `/var/lib/postgresql/data`).
- **pg_cron** can only be created in one database per cluster (configured via `POSTGRES_DB`).
- **PostGIS** installs the core `postgis` extension. Additional extensions (`postgis_topology`, `postgis_raster`) can be created manually.
- **SSL certificates** are auto-generated if not provided. For production, mount your own certs or use a reverse proxy.
- Supports **amd64** and **arm64** architectures via the CI workflow.

## License

MIT
