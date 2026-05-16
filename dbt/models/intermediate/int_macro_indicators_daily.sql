{{ config(materialized='ephemeral') }}

with observations as (

    select
        source,
        dataset,
        location_name,
        cast(observed_at as date) as metric_date,
        metric_name,
        metric_value,
        loaded_at
    from {{ ref('silver_metric_observations') }}
    where dataset = 'macro_indicator_sample'

)

select
    source,
    dataset,
    location_name,
    metric_date,
    metric_name,
    count(*) as observations_count,
    avg(metric_value) as avg_metric_value,
    max(loaded_at) as latest_loaded_at
from observations
group by
    source,
    dataset,
    location_name,
    metric_date,
    metric_name
