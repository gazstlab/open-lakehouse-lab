{{ config(materialized='view') }}

select
  cast(source as varchar) as source,
  cast(dataset as varchar) as dataset,
  cast(ingestion_date as date) as ingestion_date,
  cast(loaded_at as timestamp) as loaded_at,
  cast(payload as varchar) as payload
from {{ ref('raw_source_events') }}
