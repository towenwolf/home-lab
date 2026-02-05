-- ============================================================================
-- Oregon Tax Dollar Flow — Pre-computed Summaries
-- Run against your PostgreSQL database to create materialized views
-- that power the Sankey diagram.
--
-- Source table: raw.state_spending
-- Columns used: fiscal_year, agency, agency_name, budget_class,
--               budget_class_name, expend_class, expend_class_name,
--               vendor, expense, vendor_state
-- ============================================================================

-- Schema for our computed views
CREATE SCHEMA IF NOT EXISTS serve;

-- ────────────────────────────────────────────────────────────────────────────
-- 1. SUMMARY BY FISCAL YEAR
--    Grand totals so we can normalize to $1.00
-- ────────────────────────────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS serve.fiscal_year_totals CASCADE;
CREATE MATERIALIZED VIEW serve.fiscal_year_totals AS
SELECT
    fiscal_year,
    COUNT(*)                          AS transaction_count,
    COUNT(DISTINCT agency)            AS agency_count,
    COUNT(DISTINCT vendor)            AS vendor_count,
    SUM(expense::numeric)             AS grand_total
FROM raw.state_spending
GROUP BY fiscal_year
ORDER BY fiscal_year;

CREATE UNIQUE INDEX ON serve.fiscal_year_totals (fiscal_year);

-- ────────────────────────────────────────────────────────────────────────────
-- 2. LAYER 1: Agency-level allocation (per dollar)
--    YOUR $1 → GENERAL FUND → AGENCY
-- ────────────────────────────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS serve.spending_by_agency CASCADE;
CREATE MATERIALIZED VIEW serve.spending_by_agency AS
WITH totals AS (
    SELECT fiscal_year, SUM(expense::numeric) AS grand_total
    FROM raw.state_spending
    GROUP BY fiscal_year
)
SELECT
    s.fiscal_year,
    s.agency,
    s.agency_name,
    SUM(s.expense::numeric)                              AS total_expense,
    ROUND(SUM(s.expense::numeric) / t.grand_total, 8)   AS pct_of_total,
    ROUND(SUM(s.expense::numeric) / t.grand_total, 8)   AS per_dollar
FROM raw.state_spending s
JOIN totals t USING (fiscal_year)
GROUP BY s.fiscal_year, s.agency, s.agency_name, t.grand_total
ORDER BY s.fiscal_year, total_expense DESC;

CREATE UNIQUE INDEX ON serve.spending_by_agency (fiscal_year, agency);

-- ────────────────────────────────────────────────────────────────────────────
-- 3. LAYER 2: Agency → Budget Class
-- ────────────────────────────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS serve.spending_by_budget_class CASCADE;
CREATE MATERIALIZED VIEW serve.spending_by_budget_class AS
WITH totals AS (
    SELECT fiscal_year, SUM(expense::numeric) AS grand_total
    FROM raw.state_spending
    GROUP BY fiscal_year
)
SELECT
    s.fiscal_year,
    s.agency,
    s.agency_name,
    s.budget_class,
    s.budget_class_name,
    SUM(s.expense::numeric)                              AS total_expense,
    ROUND(SUM(s.expense::numeric) / t.grand_total, 8)   AS per_dollar
FROM raw.state_spending s
JOIN totals t USING (fiscal_year)
GROUP BY s.fiscal_year, s.agency, s.agency_name,
         s.budget_class, s.budget_class_name, t.grand_total
ORDER BY s.fiscal_year, total_expense DESC;

CREATE UNIQUE INDEX ON serve.spending_by_budget_class
    (fiscal_year, agency, budget_class);

-- ────────────────────────────────────────────────────────────────────────────
-- 4. LAYER 3: Budget Class → Expenditure Class
-- ────────────────────────────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS serve.spending_by_expend_class CASCADE;
CREATE MATERIALIZED VIEW serve.spending_by_expend_class AS
WITH totals AS (
    SELECT fiscal_year, SUM(expense::numeric) AS grand_total
    FROM raw.state_spending
    GROUP BY fiscal_year
)
SELECT
    s.fiscal_year,
    s.agency,
    s.agency_name,
    s.budget_class,
    s.budget_class_name,
    s.expend_class,
    s.expend_class_name,
    SUM(s.expense::numeric)                              AS total_expense,
    ROUND(SUM(s.expense::numeric) / t.grand_total, 8)   AS per_dollar
FROM raw.state_spending s
JOIN totals t USING (fiscal_year)
GROUP BY s.fiscal_year, s.agency, s.agency_name,
         s.budget_class, s.budget_class_name,
         s.expend_class, s.expend_class_name, t.grand_total
ORDER BY s.fiscal_year, total_expense DESC;

CREATE UNIQUE INDEX ON serve.spending_by_expend_class
    (fiscal_year, agency, budget_class, expend_class);

-- ────────────────────────────────────────────────────────────────────────────
-- 5. LAYER 4: Expenditure Class → Top Vendors
--    (Top 15 vendors per agency, remainder grouped as "Other Vendors")
-- ────────────────────────────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS serve.spending_by_vendor CASCADE;
CREATE MATERIALIZED VIEW serve.spending_by_vendor AS
WITH totals AS (
    SELECT fiscal_year, SUM(expense::numeric) AS grand_total
    FROM raw.state_spending
    GROUP BY fiscal_year
),
ranked AS (
    SELECT
        s.fiscal_year,
        s.agency,
        s.agency_name,
        s.budget_class,
        s.budget_class_name,
        s.expend_class,
        s.expend_class_name,
        s.vendor,
        s.vendor_state,
        SUM(s.expense::numeric)                            AS total_expense,
        ROW_NUMBER() OVER (
            PARTITION BY s.fiscal_year, s.agency, s.expend_class
            ORDER BY SUM(s.expense::numeric) DESC
        ) AS vendor_rank
    FROM raw.state_spending s
    GROUP BY s.fiscal_year, s.agency, s.agency_name,
             s.budget_class, s.budget_class_name,
             s.expend_class, s.expend_class_name,
             s.vendor, s.vendor_state
)
SELECT
    r.fiscal_year,
    r.agency,
    r.agency_name,
    r.budget_class,
    r.budget_class_name,
    r.expend_class,
    r.expend_class_name,
    CASE WHEN r.vendor_rank <= 15 THEN r.vendor ELSE 'OTHER VENDORS' END AS vendor,
    CASE WHEN r.vendor_rank <= 15 THEN r.vendor_state ELSE NULL END      AS vendor_state,
    SUM(r.total_expense)                                                  AS total_expense,
    ROUND(SUM(r.total_expense) / t.grand_total, 8)                       AS per_dollar
FROM ranked r
JOIN totals t USING (fiscal_year)
GROUP BY r.fiscal_year, r.agency, r.agency_name,
         r.budget_class, r.budget_class_name,
         r.expend_class, r.expend_class_name,
         CASE WHEN r.vendor_rank <= 15 THEN r.vendor ELSE 'OTHER VENDORS' END,
         CASE WHEN r.vendor_rank <= 15 THEN r.vendor_state ELSE NULL END,
         t.grand_total
ORDER BY r.fiscal_year, total_expense DESC;

-- ────────────────────────────────────────────────────────────────────────────
-- 6. COMBINED SANKEY PAYLOAD
--    Single query that returns all links for the Sankey in one shot.
--    This is what the API endpoint will call.
-- ────────────────────────────────────────────────────────────────────────────
DROP MATERIALIZED VIEW IF EXISTS serve.sankey_links CASCADE;
CREATE MATERIALIZED VIEW serve.sankey_links AS
WITH totals AS (
    SELECT fiscal_year, SUM(expense::numeric) AS grand_total
    FROM raw.state_spending
    GROUP BY fiscal_year
),

-- Link Layer 0→1: Income Tax → General Fund
-- (We model the full dataset as the General Fund for now;
--  multiply by 0.816 to represent PIT share)
link_income_to_gf AS (
    SELECT
        fiscal_year,
        'YOUR $1 INCOME TAX'  AS source,
        'GENERAL FUND'        AS target,
        0                     AS source_layer,
        1                     AS target_layer,
        0.816                 AS value
    FROM totals
),

-- Link Layer 1→2: General Fund → Agency
link_gf_to_agency AS (
    SELECT
        fiscal_year,
        'GENERAL FUND'        AS source,
        agency_name           AS target,
        1                     AS source_layer,
        2                     AS target_layer,
        per_dollar * 0.816    AS value
    FROM serve.spending_by_agency
),

-- Link Layer 2→3: Agency → Budget Class
link_agency_to_budget AS (
    SELECT
        fiscal_year,
        agency_name              AS source,
        budget_class_name        AS target,
        2                        AS source_layer,
        3                        AS target_layer,
        per_dollar * 0.816       AS value
    FROM serve.spending_by_budget_class
),

-- Link Layer 3→4: Budget Class → Expenditure Class
link_budget_to_expend AS (
    SELECT
        fiscal_year,
        budget_class_name        AS source,
        expend_class_name        AS target,
        3                        AS source_layer,
        4                        AS target_layer,
        per_dollar * 0.816       AS value
    FROM serve.spending_by_expend_class
)

SELECT * FROM link_income_to_gf
UNION ALL
SELECT * FROM link_gf_to_agency
UNION ALL
SELECT * FROM link_agency_to_budget
UNION ALL
SELECT * FROM link_budget_to_expend;

-- ────────────────────────────────────────────────────────────────────────────
-- REFRESH HELPER
-- Call this after new data is ingested to recompute everything:
--
--   SELECT serve.refresh_all();
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION serve.refresh_all()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY serve.fiscal_year_totals;
    REFRESH MATERIALIZED VIEW CONCURRENTLY serve.spending_by_agency;
    REFRESH MATERIALIZED VIEW CONCURRENTLY serve.spending_by_budget_class;
    REFRESH MATERIALIZED VIEW serve.spending_by_expend_class;
    REFRESH MATERIALIZED VIEW serve.spending_by_vendor;
    REFRESH MATERIALIZED VIEW serve.sankey_links;
END;
$$ LANGUAGE plpgsql;