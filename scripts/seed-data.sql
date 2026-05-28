-- ==========================================================================
-- Seed Data — Sample data for testing all 11 extensions
-- Run: psql -U postgres -f seed-data.sql
-- ==========================================================================

\echo '================================================'
\echo '  Seeding test data...'
\echo '================================================'

-- --------------------------------------------------------------------------
-- 1. pgvector — Products with vector embeddings
-- --------------------------------------------------------------------------
\echo '  → products (pgvector)'

CREATE TABLE IF NOT EXISTS products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    description text,
    embedding vector(4)
);

TRUNCATE products CASCADE;
INSERT INTO products (name, description, embedding) VALUES
    ('Running Shoes',   'Lightweight running shoes for marathon training',  '[0.2, 0.8, 0.1, 0.3]'),
    ('Hiking Boots',    'Waterproof boots for mountain trails',            '[0.3, 0.7, 0.4, 0.5]'),
    ('Dress Shoes',     'Formal leather shoes for office wear',            '[0.9, 0.1, 0.2, 0.8]'),
    ('Sandals',         'Casual summer sandals with arch support',         '[0.1, 0.6, 0.9, 0.2]'),
    ('Sneakers',        'Everyday casual sneakers',                        '[0.3, 0.7, 0.2, 0.4]');

CREATE INDEX IF NOT EXISTS idx_products_embedding ON products USING hnsw (embedding vector_l2_ops);

-- --------------------------------------------------------------------------
-- 2. pg_trgm — Articles for fuzzy text search
-- --------------------------------------------------------------------------
\echo '  → articles (pg_trgm)'

CREATE TABLE IF NOT EXISTS articles (
    id serial PRIMARY KEY,
    title text NOT NULL
);

TRUNCATE articles CASCADE;
INSERT INTO articles (title) VALUES
    ('Introduction to PostgreSQL'),
    ('Advanced Database Design'),
    ('Building REST APIs with Node.js'),
    ('PostgreSQL Performance Tuning'),
    ('Getting Started with Docker');

CREATE INDEX IF NOT EXISTS idx_articles_title_trgm ON articles USING gin (title gin_trgm_ops);

-- --------------------------------------------------------------------------
-- 3. pgmq — Message queue
-- --------------------------------------------------------------------------
\echo '  → order_events queue (pgmq)'

SELECT pgmq.create('order_events');

SELECT pgmq.send('order_events', '{"event": "order_created", "order_id": 1001, "amount": 59.99}');
SELECT pgmq.send('order_events', '{"event": "order_shipped", "order_id": 1001, "tracking": "TRK123"}');
SELECT pgmq.send('order_events', '{"event": "order_delivered", "order_id": 1001}');

-- --------------------------------------------------------------------------
-- 6. pg_partman — Partitioned sensor readings
-- --------------------------------------------------------------------------
\echo '  → sensor_readings (pg_partman)'

CREATE TABLE IF NOT EXISTS sensor_readings (
    id bigserial,
    sensor_id int NOT NULL,
    temperature numeric(5,2) NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now()
) PARTITION BY RANGE (recorded_at);

SELECT create_parent(
    p_parent_table := 'public.sensor_readings',
    p_control := 'recorded_at',
    p_interval := '1 day'
);

INSERT INTO sensor_readings (sensor_id, temperature, recorded_at) VALUES
    (1, 22.5, now()),
    (2, 18.3, now()),
    (1, 23.1, now() - interval '1 day'),
    (2, 19.8, now() - interval '2 days'),
    (3, 25.0, now() + interval '1 day');

-- --------------------------------------------------------------------------
-- 7. pgcrypto — Users with hashed passwords
-- --------------------------------------------------------------------------
\echo '  → users (pgcrypto)'

CREATE TABLE IF NOT EXISTS users (
    id serial PRIMARY KEY,
    username text UNIQUE NOT NULL,
    password_hash text NOT NULL,
    api_key uuid DEFAULT gen_random_uuid()
);

TRUNCATE users CASCADE;
INSERT INTO users (username, password_hash) VALUES
    ('alice', crypt('password123', gen_salt('bf', 10))),
    ('bob',   crypt('securepass',  gen_salt('bf', 10)));

-- --------------------------------------------------------------------------
-- 8. postgis — Stores with geospatial coordinates
-- --------------------------------------------------------------------------
\echo '  → stores (postgis)'

CREATE TABLE IF NOT EXISTS stores (
    id serial PRIMARY KEY,
    name text NOT NULL,
    location geography(Point, 4326)
);

TRUNCATE stores CASCADE;
INSERT INTO stores (name, location) VALUES
    ('Downtown NYC',      ST_SetSRID(ST_Point(-73.9857, 40.7484), 4326)),
    ('Brooklyn Bridge',   ST_SetSRID(ST_Point(-73.9969, 40.7061), 4326)),
    ('Times Square',      ST_SetSRID(ST_Point(-73.9855, 40.7580), 4326)),
    ('Central Park',      ST_SetSRID(ST_Point(-73.9654, 40.7829), 4326)),
    ('JFK Airport',       ST_SetSRID(ST_Point(-73.7781, 40.6413), 4326));

CREATE INDEX IF NOT EXISTS idx_stores_location ON stores USING gist (location);

-- --------------------------------------------------------------------------
-- 9. uuid-ossp — Sessions with auto-generated UUIDs
-- --------------------------------------------------------------------------
\echo '  → sessions (uuid-ossp)'

CREATE TABLE IF NOT EXISTS sessions (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id int REFERENCES users(id),
    created_at timestamptz DEFAULT now()
);

TRUNCATE sessions CASCADE;
INSERT INTO sessions (user_id) VALUES (1), (1), (2);

-- --------------------------------------------------------------------------
-- 10. btree_gin — Logs with multi-column GIN index
-- --------------------------------------------------------------------------
\echo '  → logs (btree_gin)'

CREATE TABLE IF NOT EXISTS logs (
    id serial PRIMARY KEY,
    level text NOT NULL,
    status_code int NOT NULL,
    message text,
    created_at timestamptz DEFAULT now()
);

TRUNCATE logs CASCADE;
INSERT INTO logs (level, status_code, message) VALUES
    ('INFO',  200, 'Request completed'),
    ('WARN',  429, 'Rate limit exceeded'),
    ('ERROR', 500, 'Internal server error'),
    ('INFO',  200, 'Health check OK'),
    ('ERROR', 503, 'Service unavailable'),
    ('DEBUG', 200, 'Cache hit');

CREATE INDEX IF NOT EXISTS idx_logs_multi_gin ON logs USING gin (level, status_code);

-- --------------------------------------------------------------------------
-- 11. hstore — Feature flags as key-value pairs
-- --------------------------------------------------------------------------
\echo '  → feature_flags (hstore)'

CREATE TABLE IF NOT EXISTS feature_flags (
    id serial PRIMARY KEY,
    app_name text NOT NULL,
    flags hstore NOT NULL DEFAULT ''
);

TRUNCATE feature_flags CASCADE;
INSERT INTO feature_flags (app_name, flags) VALUES
    ('web-app',    'dark_mode => true, beta_ui => false, max_upload_mb => 50'),
    ('mobile-app', 'push_notifications => true, offline_mode => true, max_upload_mb => 25'),
    ('admin',      'dark_mode => true, audit_log => true, max_upload_mb => 100');

\echo ''
\echo '================================================'
\echo '  Seed data loaded successfully!'
\echo '================================================'
