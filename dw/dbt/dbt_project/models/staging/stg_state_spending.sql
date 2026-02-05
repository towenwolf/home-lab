-- Example staging model for state spending
-- Transforms raw.state_spending into a cleaned format

-- models/staging/stg_state_spending.sql

SELECT
    id,
    fiscal_year,
    
    -- IDs
    agency AS agency_id,
    budget_class AS budget_class_id,
    expend_class AS expend_class_id,
    
    -- Clean up names (trim whitespace, standardize case)
    TRIM(agency_name) AS agency_name,
    TRIM(budget_class_name) AS budget_class_name,
    TRIM(expend_class_name) AS expend_class_name,
    
    -- Vendor info
    TRIM(vendor) AS vendor_name,
    UPPER(TRIM(vendor_state)) AS vendor_state,
    
    -- Money
    COALESCE(expense, 0) AS expense_amount,
    
    -- Metadata (keep for lineage)
    ingested_at,
    batch_id

FROM {{ source('raw', 'state_spending') }}

-- Optional: filter out bad records
WHERE fiscal_year IS NOT NULL
  AND expense IS NOT NULL
