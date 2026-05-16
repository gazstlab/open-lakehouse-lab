{{ config(
    materialized='iceberg_table',
    database=var('polaris_catalog_name')
) }}

with freshness as (

    select
        source,
        dataset,
        latest_observed_at,
        latest_loaded_at,
        first_ingestion_date,
        latest_ingestion_date,
        records_count,
        unique_records_count
    from {{ ref('silver_dataset_freshness') }}

)

select
    source,
    dataset,
    latest_ingestion_date as health_date,
    first_ingestion_date,
    latest_observed_at,
    latest_loaded_at,
    records_count,
    unique_records_count,
    records_count - unique_records_count as duplicate_records_count,
    md5(
        concat_ws(
            '||',
            source,
            dataset,
            cast(latest_ingestion_date as varchar)
        )
    ) as pipeline_health_daily_id
from freshness
