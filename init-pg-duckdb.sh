#!/bin/bash
set -e

export PGUSER="${PGUSER:-postgres}"
export PGDATABASE="${PGDATABASE:-postgres}"

echo "Initializing pg_duckdb configuration..."

cat > /tmp/pg_duckdb_config.sql <<EOF
CREATE EXTENSION IF NOT EXISTS pg_duckdb;

ALTER DATABASE $PGDATABASE SET duckdb.force_execution = true;

SET duckdb.motherduck_enabled = false;
ALTER DATABASE $PGDATABASE SET duckdb.motherduck_enabled = false;
EOF

if [ -n "$S3_ACCESS_KEY_ID" ] && [ -n "$S3_SECRET_ACCESS_KEY" ] && [ -n "$S3_REGION" ]; then
  echo "Configuring S3 secret..."

  S3_SQL="-- Create S3 secret
SELECT duckdb.create_simple_secret(
    type := 'S3',
    key_id := '$S3_ACCESS_KEY_ID',
    secret := '$S3_SECRET_ACCESS_KEY',
    region := '$S3_REGION'"

  if [ -n "$S3_SESSION_TOKEN" ]; then
    S3_SQL="$S3_SQL,
    session_token := '$S3_SESSION_TOKEN'"
  fi

  if [ -n "$S3_ENDPOINT" ]; then
    S3_SQL="$S3_SQL,
    endpoint := '${S3_ENDPOINT#https://}'"
  fi

  if [ -n "$S3_URL_STYLE" ]; then
    S3_SQL="$S3_SQL,
    url_style := '$S3_URL_STYLE'"
  else
    S3_SQL="$S3_SQL,
    url_style := 'path'"
  fi

  S3_SQL="$S3_SQL
);"

  cat >> /tmp/pg_duckdb_config.sql <<EOF

$S3_SQL
EOF

  echo "S3 secret configuration added."
else
  echo "S3 credentials not provided. Skipping S3 secret creation."
fi

if [ -n "$DUCKDB_EXTENSIONS" ]; then
  echo "Installing DuckDB extensions: $DUCKDB_EXTENSIONS"

  IFS=',' read -ra EXTENSIONS <<< "$DUCKDB_EXTENSIONS"
  for extension in "${EXTENSIONS[@]}"; do
    extension=$(echo "$extension" | xargs)
    cat >> /tmp/pg_duckdb_config.sql <<EOF

SELECT duckdb.install_extension('$extension');
EOF
  done

  echo "DuckDB extensions configuration added."
fi

echo "Applying pg_duckdb configuration..."

psql -v ON_ERROR_STOP=1 -h /var/run/postgresql -f /tmp/pg_duckdb_config.sql

echo "pg_duckdb configuration completed successfully!"

rm /tmp/pg_duckdb_config.sql
