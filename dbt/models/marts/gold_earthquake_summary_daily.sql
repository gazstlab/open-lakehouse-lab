{{ config(
    materialized='iceberg_table',
    database=var('polaris_catalog_name')
) }}

select
    source,
    dataset,
    location_name,
    event_date,
    events_count,
    avg_magnitude,
    max_magnitude,
    latest_loaded_at,
    md5(
        concat_ws(
            '||',
            source,
            dataset,
            coalesce(location_name, ''),
            cast(event_date as varchar)
        )
    ) as earthquake_summary_daily_id
from {{ ref('int_earthquake_summary_daily') }}
