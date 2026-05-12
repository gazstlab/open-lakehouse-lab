{{ config(materialized='view') }}

with raw_source_events as (

    select *
    from {{ ref('generic_raw_contract') }}

),

staged as (

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
    from raw_source_events

)

select *
from staged
