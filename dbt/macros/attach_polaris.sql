{% macro attach_polaris_catalog(force=false) %}
  {#
    Attaches the Apache Polaris REST Catalog to DuckDB.

    This macro is intentionally isolated so later stages can reuse it from
    pre-hooks, run-operation commands, or custom materializations.
  #}

  {% set attach_enabled = env_var('DBT_ENABLE_POLARIS_ATTACH', 'false') | lower in ['1', 'true', 'yes', 'on'] %}

  {% if execute and (force or attach_enabled) %}
    {% set catalog_name = var('polaris_catalog_name', env_var('DBT_POLARIS_CATALOG_NAME', 'lakehouse')) %}
    {% set configured_endpoint = var('polaris_endpoint', env_var('DBT_POLARIS_ENDPOINT', 'http://localhost:8181/api/catalog')) %}
    {% set configured_warehouse = var('polaris_warehouse', env_var('DBT_POLARIS_WAREHOUSE', catalog_name)) %}
    {% set client_id = env_var('DBT_POLARIS_CLIENT_ID', env_var('POLARIS_ROOT_CLIENT_ID', 'root')) %}
    {% set client_secret = env_var('DBT_POLARIS_CLIENT_SECRET', env_var('POLARIS_ROOT_CLIENT_SECRET', 'local-polaris-secret')) %}
    {% set oauth2_scope = env_var('DBT_POLARIS_OAUTH2_SCOPE', 'PRINCIPAL_ROLE:ALL') %}
    {% set access_delegation_mode = env_var('DBT_POLARIS_ACCESS_DELEGATION_MODE', 'vended_credentials') %}

    {% if '/api/catalog' in configured_endpoint %}
      {% set endpoint = configured_endpoint.rstrip('/') %}
    {% else %}
      {% set endpoint = configured_endpoint.rstrip('/') ~ '/api/catalog' %}
    {% endif %}

    {#
      Older local commands used DBT_POLARIS_WAREHOUSE as the S3 base location.
      DuckDB's Iceberg REST attach expects the Polaris catalog/warehouse name.
    #}
    {% if configured_warehouse.startswith('s3://') %}
      {% set warehouse = catalog_name %}
    {% else %}
      {% set warehouse = configured_warehouse %}
    {% endif %}

    {% set oauth2_server_uri = endpoint ~ '/v1/oauth/tokens' %}

    {% do log('Attaching Polaris REST Catalog ' ~ warehouse ~ ' at ' ~ endpoint ~ ' as ' ~ catalog_name, info=True) %}

    {% set sql %}
    LOAD httpfs;
    LOAD iceberg;

    CREATE OR REPLACE SECRET polaris_secret (
      TYPE iceberg,
      CLIENT_ID '{{ client_id }}',
      CLIENT_SECRET '{{ client_secret }}',
      OAUTH2_SERVER_URI '{{ oauth2_server_uri }}',
      OAUTH2_SCOPE '{{ oauth2_scope }}'
    );

    ATTACH IF NOT EXISTS '{{ warehouse }}' AS {{ catalog_name }} (
      TYPE iceberg,
      ENDPOINT '{{ endpoint }}',
      SECRET polaris_secret,
      ACCESS_DELEGATION_MODE '{{ access_delegation_mode }}'
    );
    {% endset %}

    {% do run_query(sql) %}
  {% endif %}
{% endmacro %}
