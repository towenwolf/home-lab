-- ============================================================================
-- Spending by Agency
-- Layer 1: YOUR $1 → GENERAL FUND → AGENCY
-- ============================================================================

WITH spending AS (
    SELECT
        fiscal_year,
        agency_id,
        agency_name,
        expense_amount
    FROM {{ ref('stg_state_spending') }}
),

totals AS (
    SELECT
        fiscal_year,
        grand_total
    FROM {{ ref('int_fiscal_year_totals') }}
)

SELECT
    s.fiscal_year,
    s.agency_id,
    s.agency_name,
    SUM(s.expense_amount)                                   AS total_expense,
    ROUND(SUM(s.expense_amount) / t.grand_total, 8)         AS pct_of_total,
    ROUND(SUM(s.expense_amount) / t.grand_total, 8)         AS per_dollar
FROM spending s
INNER JOIN totals t USING (fiscal_year)
GROUP BY
    s.fiscal_year,
    s.agency_id,
    s.agency_name,
    t.grand_total
ORDER BY s.fiscal_year, total_expense DESC
