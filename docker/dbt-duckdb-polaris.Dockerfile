FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DBT_PROFILES_DIR=/app/dbt \
    DBT_DUCKDB_EXTENSION_DIRECTORY=/home/dbt/.duckdb/extensions

WORKDIR /app

RUN useradd --create-home --shell /usr/sbin/nologin dbt \
    && python -m pip install --no-cache-dir --upgrade pip==26.1.1 \
    && python -m pip install --no-cache-dir \
        dbt-core==1.10.15 \
        dbt-duckdb==1.9.6 \
        duckdb==1.4.2

USER dbt

RUN python -c "import duckdb; con = duckdb.connect(':memory:'); con.execute('INSTALL httpfs'); con.execute('INSTALL avro'); con.execute('INSTALL iceberg')"

COPY --chown=dbt:dbt dbt/ /app/dbt/

WORKDIR /app/dbt

CMD ["dbt", "--help"]
