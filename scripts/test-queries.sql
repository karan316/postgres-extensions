-- ==========================================================================
-- Test Queries — Verify all 11 extensions against seeded data
-- Prerequisites: Run seed-data.sql first
-- Run: psql -U postgres -f test-queries.sql
-- ==========================================================================

\echo '================================================'
\echo '  Running extension test queries...'
\echo '================================================'

-- --------------------------------------------------------------------------
-- 1. pgvector — Vector similarity search
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 1. pgvector: Find 3 products most similar to "athletic footwear" ---'
\echo '   Expected: Running Shoes, Sneakers, Hiking Boots'

SELECT name,
       round(( embedding <-> '[0.25, 0.75, 0.15, 0.35]' )::numeric, 4) AS distance
FROM products
ORDER BY embedding <-> '[0.25, 0.75, 0.15, 0.35]'
LIMIT 3;

-- --------------------------------------------------------------------------
-- 2. pg_trgm — Fuzzy text search
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 2. pg_trgm: Fuzzy search for "Postgre" in article titles ---'
\echo '   Expected: Introduction to PostgreSQL, PostgreSQL Performance Tuning'

SELECT title,
       round(word_similarity('Postgre', title)::numeric, 3) AS match_score
FROM articles
WHERE 'Postgre' <% title
ORDER BY match_score DESC;

-- --------------------------------------------------------------------------
-- 3. pgmq — Message queue read
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 3. pgmq: Read next 2 messages from order_events queue ---'
\echo '   Expected: order_created, order_shipped'

SELECT msg_id,
       message->>'event' AS event,
       message->>'order_id' AS order_id
FROM pgmq.read('order_events', 30, 2);

-- --------------------------------------------------------------------------
-- 4. pg_cron — Schedule, list, and unschedule jobs
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 4. pg_cron: Schedule and list cron jobs ---'
\echo '   Expected: 2 jobs with cron schedules'

SELECT cron.schedule('cleanup-old-messages', '0 3 * * *',
    $$DELETE FROM pgmq.q_order_events WHERE enqueued_at < now() - interval '30 days'$$
);
SELECT cron.schedule('daily-vacuum', '0 4 * * *', 'VACUUM ANALYZE products');

SELECT jobid, jobname, schedule, command
FROM cron.job
ORDER BY jobid;

SELECT cron.unschedule('cleanup-old-messages');
SELECT cron.unschedule('daily-vacuum');

-- --------------------------------------------------------------------------
-- 5. pg_stat_statements — Query performance tracking
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 5. pg_stat_statements: Top 5 queries by call count ---'
\echo '   Expected: queries with call counts and execution times'

SELECT calls,
       round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2) AS avg_ms,
       left(query, 80) AS query_preview
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 5;

-- --------------------------------------------------------------------------
-- 6. pg_partman — Show partitions and row distribution
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 6. pg_partman: Daily partitions for sensor_readings ---'
\echo '   Expected: multiple partitions with rows distributed by day'

SELECT child.relname AS partition_name,
       pg_size_pretty(pg_relation_size(child.oid)) AS size,
       (SELECT count(*) FROM sensor_readings s
        WHERE s.recorded_at >= (regexp_match(child.relname, 'p(\d{8})'))[1]::date
          AND s.recorded_at < (regexp_match(child.relname, 'p(\d{8})'))[1]::date + interval '1 day'
       ) AS row_count
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child ON pg_inherits.inhrelid = child.oid
WHERE parent.relname = 'sensor_readings'
  AND child.relname LIKE 'sensor_readings_p%'
ORDER BY child.relname
LIMIT 5;

-- --------------------------------------------------------------------------
-- 7. pgcrypto — Password verification
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 7a. pgcrypto: Verify correct password for alice ---'
\echo '   Expected: password_valid = true'

SELECT username,
       (password_hash = crypt('password123', password_hash)) AS password_valid,
       api_key
FROM users
WHERE username = 'alice';

\echo ''
\echo '--- 7b. pgcrypto: Verify wrong password for bob ---'
\echo '   Expected: password_valid = false'

SELECT username,
       (password_hash = crypt('wrongpassword', password_hash)) AS password_valid
FROM users
WHERE username = 'bob';

-- --------------------------------------------------------------------------
-- 8. postgis — Geospatial proximity search
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 8. postgis: Stores within 5km of Empire State Building ---'
\echo '   Expected: Downtown NYC (0m), Times Square (~1069m), Central Park (~4197m), Brooklyn Bridge (~4792m)'

SELECT name,
       round(ST_Distance(
           location,
           ST_SetSRID(ST_Point(-73.9857, 40.7484), 4326)::geography
       )::numeric) AS distance_meters
FROM stores
WHERE ST_DWithin(
    location,
    ST_SetSRID(ST_Point(-73.9857, 40.7484), 4326)::geography,
    5000
)
ORDER BY distance_meters;

-- --------------------------------------------------------------------------
-- 9. uuid-ossp — Auto-generated UUIDs
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 9. uuid-ossp: Sessions with auto-generated v4 UUIDs ---'
\echo '   Expected: 3 rows, each with a unique UUID'

SELECT id, user_id, created_at
FROM sessions
ORDER BY created_at;

-- --------------------------------------------------------------------------
-- 10. btree_gin — Multi-column GIN index filtering
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 10. btree_gin: Filter ERROR logs with status >= 500 ---'
\echo '   Expected: Internal server error (500), Service unavailable (503)'

SELECT level, status_code, message
FROM logs
WHERE level = 'ERROR' AND status_code >= 500
ORDER BY status_code;

-- --------------------------------------------------------------------------
-- 11. hstore — Key-value queries
-- --------------------------------------------------------------------------
\echo ''
\echo '--- 11a. hstore: Apps with dark_mode enabled ---'
\echo '   Expected: admin (100), web-app (50)'

SELECT app_name,
       flags -> 'dark_mode' AS dark_mode,
       flags -> 'max_upload_mb' AS max_upload_mb
FROM feature_flags
WHERE flags -> 'dark_mode' = 'true'
ORDER BY app_name;

\echo ''
\echo '--- 11b. hstore: All feature flag keys for web-app ---'
\echo '   Expected: beta_ui, dark_mode, max_upload_mb'

SELECT skeys(flags) AS flag_name
FROM feature_flags
WHERE app_name = 'web-app';

\echo ''
\echo '================================================'
\echo '  All extension tests complete!'
\echo '================================================'
