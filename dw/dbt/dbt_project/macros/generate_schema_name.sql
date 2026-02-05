-- Override dbt's default schema naming behavior
-- By default, dbt creates schemas as: <default_schema>_<custom_schema>
-- This macro makes it use just the custom schema name directly

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
