{{ config(
    materialized='iceberg_table',
    database=var('polaris_catalog_name')
) }}

select
    source,
    dataset,
    location_name,
    metric_date,
    observations_count,
    avg_temperature_celsius,
    min_temperature_celsius,
    max_temperature_celsius,
    latest_loaded_at,
    md5(
        concat_ws(
            '||',
            source,
            dataset,
            coalesce(location_name, ''),
            cast(metric_date as varchar)
        )
    ) as environment_city_daily_id
from {{ ref('int_environment_city_daily') }}
