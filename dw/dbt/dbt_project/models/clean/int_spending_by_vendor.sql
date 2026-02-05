-- ============================================================================
-- Spending by Vendor
-- Layer 4: Expenditure Class → Top Vendors
-- Top 15 vendors per agency/expend_class, remainder grouped as "Other Vendors"
-- ============================================================================

WITH spending AS (
    SELECT
        fiscal_year,
        agency_id,
        agency_name,
        budget_class_id,
        budget_class_name,
        expend_class_id,
        expend_class_name,
        vendor_name,
        vendor_state,
        expense_amount
    FROM {{ ref('stg_state_spending') }}
),

totals AS (
    SELECT
        fiscal_year,
        grand_total
    FROM {{ ref('int_fiscal_year_totals') }}
),

ranked AS (
    SELECT
        s.fiscal_year,
        s.agency_id,
        s.agency_name,
        s.budget_class_id,
        s.budget_class_name,
        s.expend_class_id,
        s.expend_class_name,
        s.vendor_name,
        s.vendor_state,
        SUM(s.expense_amount) AS total_expense,
        ROW_NUMBER() OVER (
            PARTITION BY s.fiscal_year, s.agency_id, s.expend_class_id
            ORDER BY SUM(s.expense_amount) DESC
        ) AS vendor_rank
    FROM spending s
    GROUP BY
        s.fiscal_year,
        s.agency_id,
        s.agency_name,
        s.budget_class_id,
        s.budget_class_name,
        s.expend_class_id,
        s.expend_class_name,
        s.vendor_name,
        s.vendor_state
)

SELECT
    r.fiscal_year,
    r.agency_id,
    r.agency_name,
    r.budget_class_id,
    r.budget_class_name,
    r.expend_class_id,
    r.expend_class_name,
    CASE WHEN r.vendor_rank <= 15 THEN r.vendor_name ELSE 'OTHER VENDORS' END   AS vendor_name,
    CASE WHEN r.vendor_rank <= 15 THEN r.vendor_state ELSE NULL END             AS vendor_state,
    SUM(r.total_expense)                                                         AS total_expense,
    ROUND(SUM(r.total_expense) / t.grand_total, 8)                              AS per_dollar
FROM ranked r
INNER JOIN totals t USING (fiscal_year)
GROUP BY
    r.fiscal_year,
    r.agency_id,
    r.agency_name,
    r.budget_class_id,
    r.budget_class_name,
    r.expend_class_id,
    r.expend_class_name,
    CASE WHEN r.vendor_rank <= 15 THEN r.vendor_name ELSE 'OTHER VENDORS' END,
    CASE WHEN r.vendor_rank <= 15 THEN r.vendor_state ELSE NULL END,
    t.grand_total
ORDER BY r.fiscal_year, total_expense DESC
