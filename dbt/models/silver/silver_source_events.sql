{{ config(
    materialized='iceberg_table',
    database=var('polaris_catalog_name')
) }}

with staged_events as (

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
    from {{ ref('stg_raw_source_events') }}

),

deduplicated as (

    select
        *,
        row_number() over (
            partition by record_hash
            order by loaded_at desc, observed_at desc
        ) as row_number
    from staged_events

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
