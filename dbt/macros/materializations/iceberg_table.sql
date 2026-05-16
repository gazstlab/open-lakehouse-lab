{% materialization iceberg_table, adapter='duckdb' %}
  {#
    Initial full-refresh Iceberg materialization for Open Lakehouse Lab.

    The MVP deliberately avoids MERGE, UPDATE, DELETE and ALTER TABLE behavior.
    Later stages can evolve this into an incremental strategy after the table
    health and compaction stories are implemented.
  #}

  {% set target_relation = this %}

  {% if target_relation.database is none %}
    {% do exceptions.raise_compiler_error('iceberg_table materialization requires a database/catalog config.') %}
  {% endif %}

  {{ run_hooks(pre_hooks) }}

  {% do attach_polaris_catalog(force=true) %}

  {% call statement('create_schema') %}
    create schema if not exists {{ adapter.quote(target_relation.database) }}.{{ adapter.quote(target_relation.schema) }}
  {% endcall %}

  {% call statement('drop_existing_table') %}
    drop table if exists {{ target_relation }}
  {% endcall %}

  {% call statement('main') %}
    create table {{ target_relation }} as (
      {{ sql }}
    )
  {% endcall %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}
{% endmaterialization %}
