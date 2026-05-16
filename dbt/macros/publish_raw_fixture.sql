{% macro publish_raw_fixture_parquet() %}
  {#
    Publishes a deterministic Raw Parquet fixture to MinIO.

    The path follows the canonical Raw contract:
    s3://lakehouse/raw/source=<source>/dataset=<dataset>/ingestion_date=<date>/*.parquet
  #}

  {% set raw_root = var('raw_fixture_root', env_var('DBT_RAW_FIXTURE_ROOT', 's3://lakehouse/raw')) %}

  {% do log('Publishing deterministic Raw Parquet fixture to ' ~ raw_root, info=True) %}

  {% set sql %}
    LOAD httpfs;

    COPY (
      select
        cast(source as varchar) as source,
        cast(dataset as varchar) as dataset,
        cast(ingestion_date as date) as ingestion_date,
        cast(loaded_at as timestamp) as loaded_at,
        cast(record_hash as varchar) as record_hash,
        cast(raw_payload as varchar) as raw_payload,
        cast(observed_at as timestamp) as observed_at,
        cast(metric_name as varchar) as metric_name,
        cast(metric_value as double) as metric_value,
        cast(location_name as varchar) as location_name
      from (
        values
          (
            'fixture',
            'weather_sample',
            '2026-05-10',
            '2026-05-10T00:00:00Z',
            'fixture_weather_sample_20260510_000000',
            '{"city":"Tubarao","temperature_celsius":22.5,"observed_at":"2026-05-10T00:00:00Z"}',
            '2026-05-10T00:00:00Z',
            'temperature_celsius',
            22.5,
            'Tubarao'
          ),
          (
            'fixture',
            'earthquake_sample',
            '2026-05-10',
            '2026-05-10T00:01:00Z',
            'fixture_earthquake_sample_20260510_000100',
            '{"place":"sample location","magnitude":4.2,"observed_at":"2026-05-10T00:01:00Z"}',
            '2026-05-10T00:01:00Z',
            'magnitude',
            4.2,
            'sample location'
          ),
          (
            'fixture',
            'macro_indicator_sample',
            '2026-05-10',
            '2026-05-10T00:02:00Z',
            'fixture_macro_indicator_sample_20260510_000200',
            '{"indicator":"sample_rate","value":10.75,"observed_at":"2026-05-10T00:02:00Z"}',
            '2026-05-10T00:02:00Z',
            'sample_rate',
            10.75,
            'fixture economy'
          )
      ) as fixture(
        source,
        dataset,
        ingestion_date,
        loaded_at,
        record_hash,
        raw_payload,
        observed_at,
        metric_name,
        metric_value,
        location_name
      )
    )
    TO '{{ raw_root }}' (
      FORMAT parquet,
      PARTITION_BY (source, dataset, ingestion_date),
      OVERWRITE_OR_IGNORE true,
      FILENAME_PATTERN 'fixture_{i}'
    );
  {% endset %}

  {% do run_query(sql) %}
{% endmacro %}
