{{ config(
    materialized='iceberg_table',
    database=var('polaris_catalog_name')
) }}

with source_events as (

    select
        source,
        dataset,
        ingestion_date,
        loaded_at,
        record_hash,
        observed_at
    from {{ ref('silver_source_events') }}

),

freshness as (

    select
        source,
        dataset,
        max(observed_at) as latest_observed_at,
        max(loaded_at) as latest_loaded_at,
        min(ingestion_date) as first_ingestion_date,
        max(ingestion_date) as latest_ingestion_date,
        count(*) as records_count,
        count(distinct record_hash) as unique_records_count
    from source_events
    group by
        source,
        dataset

)

select *
from freshness
