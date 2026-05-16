{{ config(materialized='view') }}

{% set raw_source_events_path = var(
    'raw_source_events_path',
    env_var(
        'DBT_RAW_SOURCE_EVENTS_PATH',
        's3://lakehouse/raw/*/*/*/*.parquet'
    )
) %}

with raw_parquet as (

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
    from read_parquet(
        '{{ raw_source_events_path }}',
        hive_partitioning = true,
        union_by_name = true
    )

),

deduplicated as (

    select
        *,
        row_number() over (
            partition by record_hash
            order by loaded_at desc, observed_at desc
        ) as row_number
    from raw_parquet

)

select
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
from deduplicated
where row_number = 1
