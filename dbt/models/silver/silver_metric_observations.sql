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
        observed_at,
        metric_name,
        metric_value,
        location_name
    from {{ ref('silver_source_events') }}

),

metric_observations as (

    select
        source,
        dataset,
        observed_at,
        ingestion_date,
        metric_name,
        metric_value,
        location_name,
        loaded_at,
        record_hash,
        md5(
            concat_ws(
                '||',
                source,
                dataset,
                metric_name,
                cast(observed_at as varchar),
                coalesce(location_name, '')
            )
        ) as observation_id
    from source_events
    where
        metric_name is not null
        and metric_value is not null
        and observed_at is not null

)

select *
from metric_observations
