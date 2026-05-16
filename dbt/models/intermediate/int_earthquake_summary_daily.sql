{{ config(materialized='ephemeral') }}

with observations as (

    select
        source,
        dataset,
        location_name,
        cast(observed_at as date) as event_date,
        metric_value,
        loaded_at
    from {{ ref('silver_metric_observations') }}
    where
        dataset = 'earthquake_sample'
        and metric_name = 'magnitude'

)

select
    source,
    dataset,
    location_name,
    event_date,
    count(*) as events_count,
    avg(metric_value) as avg_magnitude,
    max(metric_value) as max_magnitude,
    max(loaded_at) as latest_loaded_at
from observations
group by
    source,
    dataset,
    location_name,
    event_date
