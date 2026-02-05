-- ============================================================================
-- Sankey Links
-- Combined payload for the Sankey diagram visualization
-- Returns all links in one query for the API endpoint
-- ============================================================================

{% set pit_share = var('pit_share', 0.816) %}

WITH fiscal_years AS (
    SELECT DISTINCT fiscal_year
    FROM {{ ref('int_fiscal_year_totals') }}
),

-- Link Layer 0→1: Income Tax → General Fund
-- Models the PIT share flowing into General Fund
link_income_to_gf AS (
    SELECT
        fiscal_year,
        'YOUR $1 INCOME TAX'    AS source,
        'GENERAL FUND'          AS target,
        0                       AS source_layer,
        1                       AS target_layer,
        {{ pit_share }}         AS value
    FROM fiscal_years
),

-- Link Layer 1→2: General Fund → Agency
link_gf_to_agency AS (
    SELECT
        fiscal_year,
        'GENERAL FUND'          AS source,
        agency_name             AS target,
        1                       AS source_layer,
        2                       AS target_layer,
        per_dollar * {{ pit_share }} AS value
    FROM {{ ref('int_spending_by_agency') }}
),

-- Link Layer 2→3: Agency → Budget Class
link_agency_to_budget AS (
    SELECT
        fiscal_year,
        agency_name             AS source,
        budget_class_name       AS target,
        2                       AS source_layer,
        3                       AS target_layer,
        per_dollar * {{ pit_share }} AS value
    FROM {{ ref('int_spending_by_budget_class') }}
),

-- Link Layer 3→4: Budget Class → Expenditure Class
link_budget_to_expend AS (
    SELECT
        fiscal_year,
        budget_class_name       AS source,
        expend_class_name       AS target,
        3                       AS source_layer,
        4                       AS target_layer,
        per_dollar * {{ pit_share }} AS value
    FROM {{ ref('int_spending_by_expend_class') }}
)

SELECT * FROM link_income_to_gf
UNION ALL
SELECT * FROM link_gf_to_agency
UNION ALL
SELECT * FROM link_agency_to_budget
UNION ALL
SELECT * FROM link_budget_to_expend
