-- Example staging model for state spending
-- Transforms raw.state_spending into a cleaned format

{{ config(
    materialized='view',
    schema='clean'
) }}

SELECT
    *
FROM {{ source('raw', 'state_spending') }}
