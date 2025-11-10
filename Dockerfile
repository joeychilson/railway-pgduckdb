FROM pgduckdb/pgduckdb:17-v1.0.0

USER root
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=postgres:postgres init-pg-duckdb.sh /docker-entrypoint-initdb.d/0000-init-pg-duckdb.sh
RUN chmod +x /docker-entrypoint-initdb.d/0000-init-pg-duckdb.sh

EXPOSE 5432
