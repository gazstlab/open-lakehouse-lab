{{ config(materialized='ephemeral') }}

with observations as (

    select
        source,
        dataset,
        location_name,
        cast(observed_at as date) as metric_date,
        metric_value,
        loaded_at
    from {{ ref('silver_metric_observations') }}
    where
        dataset = 'weather_sample'
        and metric_name = 'temperature_celsius'

)

select
    source,
    dataset,
    location_name,
    metric_date,
    count(*) as observations_count,
    avg(metric_value) as avg_temperature_celsius,
    min(metric_value) as min_temperature_celsius,
    max(metric_value) as max_temperature_celsius,
    max(loaded_at) as latest_loaded_at
from observations
group by
    source,
    dataset,
    location_name,
    metric_date
