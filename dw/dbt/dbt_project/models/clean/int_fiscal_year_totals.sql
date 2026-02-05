-- ============================================================================
-- Fiscal Year Totals
-- Grand totals per fiscal year for normalization (per-dollar calculations)
-- ============================================================================

SELECT
    fiscal_year,
    COUNT(*)                            AS transaction_count,
    COUNT(DISTINCT agency_id)           AS agency_count,
    COUNT(DISTINCT vendor_name)         AS vendor_count,
    SUM(expense_amount)                 AS grand_total
FROM {{ ref('stg_state_spending') }}
GROUP BY fiscal_year
ORDER BY fiscal_year
