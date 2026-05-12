{{ config(materialized='view') }}

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
from {{ source('raw_sources', 'raw_source_events') }}
