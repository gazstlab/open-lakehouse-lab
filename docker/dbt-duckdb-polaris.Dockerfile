FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DBT_PROFILES_DIR=/app/dbt

WORKDIR /app

RUN useradd --create-home --shell /usr/sbin/nologin dbt \
    && python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir \
        dbt-core==1.10.15 \
        dbt-duckdb==1.9.6 \
        duckdb==1.4.2

COPY dbt/ /app/dbt/

USER dbt

WORKDIR /app/dbt

CMD ["dbt", "--help"]
