-- Create state spending table in raw schema
CREATE TABLE IF NOT EXISTS raw.state_spending (
    -- Primary key
    id SERIAL PRIMARY KEY,

    -- Source data columns (match SODA API response)
    fiscal_year INTEGER,
    agency INTEGER,
    agency_name TEXT,           -- 'agency_1' in API
    budget_class INTEGER,
    budget_class_name TEXT,     -- 'budget_class_1' in API
    expend_class INTEGER,
    expend_class_name TEXT,     -- 'expend_class_1' in API
    vendor TEXT,
    expense NUMERIC(15,2),
    vendor_state TEXT,          -- 'vendor_st' in API

    -- Metadata columns
    ingested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    source_api TEXT DEFAULT 'data.oregon.gov',
    batch_id UUID                -- Links records from same extraction run
);

-- Index for common queries
CREATE INDEX IF NOT EXISTS idx_state_spending_fiscal_year
    ON raw.state_spending(fiscal_year);
CREATE INDEX IF NOT EXISTS idx_state_spending_agency
    ON raw.state_spending(agency);
CREATE INDEX IF NOT EXISTS idx_state_spending_batch_id
    ON raw.state_spending(batch_id);
