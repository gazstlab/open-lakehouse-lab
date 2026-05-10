{% macro attach_polaris_catalog() %}
  {#
    Attaches the Apache Polaris REST Catalog to DuckDB.

    This macro is intentionally isolated so later stages can reuse it from
    pre-hooks, run-operation commands, or custom materializations.
  #}

  {% set catalog_name = var('polaris_catalog_name', env_var('DBT_POLARIS_CATALOG_NAME', 'lakehouse')) %}
  {% set endpoint = var('polaris_endpoint', env_var('DBT_POLARIS_ENDPOINT', 'http://localhost:8181')) %}
  {% set warehouse = var('polaris_warehouse', env_var('DBT_POLARIS_WAREHOUSE', 's3://lakehouse/warehouse')) %}

  {% set sql %}
    INSTALL httpfs;
    INSTALL iceberg;
    LOAD httpfs;
    LOAD iceberg;

    ATTACH '{{ endpoint }}' AS {{ catalog_name }} (
      TYPE iceberg,
      ENDPOINT_TYPE rest,
      WAREHOUSE '{{ warehouse }}'
    );
  {% endset %}

  {% do run_query(sql) %}
{% endmacro %}
