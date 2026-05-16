{{ config(
    materialized='iceberg_table',
    database=var('polaris_catalog_name')
) }}

select
    source,
    dataset,
    location_name,
    metric_date,
    metric_name,
    observations_count,
    avg_metric_value,
    latest_loaded_at,
    md5(
        concat_ws(
            '||',
            source,
            dataset,
            metric_name,
            cast(metric_date as varchar)
        )
    ) as macro_indicators_daily_id
from {{ ref('int_macro_indicators_daily') }}
