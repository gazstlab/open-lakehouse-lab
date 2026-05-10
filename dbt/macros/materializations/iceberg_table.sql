{% materialization iceberg_table, adapter='duckdb' %}
  {#
    Initial full-refresh Iceberg materialization for Open Lakehouse Lab.

    The MVP deliberately avoids MERGE, UPDATE, DELETE and ALTER TABLE behavior.
    Later stages can evolve this into an incremental strategy after the table
    health and compaction stories are implemented.
  #}

  {% set target_relation = this %}
  {% set full_refresh_mode = should_full_refresh() %}

  {{ run_hooks(pre_hooks) }}

  {% if full_refresh_mode %}
    {% do adapter.drop_relation(target_relation) %}
  {% endif %}

  {% call statement('main') %}
    create or replace table {{ target_relation }} as (
      {{ sql }}
    )
  {% endcall %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}
{% endmaterialization %}
