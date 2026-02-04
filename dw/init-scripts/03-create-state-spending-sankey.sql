-- Clean table for state spending Sankey diagram
-- Aggregates spending flows: Agency → Budget Class → Expenditure Class

CREATE TABLE IF NOT EXISTS clean.state_spending_sankey (
    id SERIAL PRIMARY KEY,
    fiscal_year INTEGER NOT NULL,

    -- Source node
    source_id INTEGER NOT NULL,
    source_name TEXT NOT NULL,
    source_type TEXT NOT NULL,  -- 'agency' or 'budget_class'

    -- Target node
    target_id INTEGER NOT NULL,
    target_name TEXT NOT NULL,
    target_type TEXT NOT NULL,  -- 'budget_class' or 'expend_class'

    total_expense NUMERIC(15,2) NOT NULL,

    CONSTRAINT valid_source_type CHECK (source_type IN ('agency', 'budget_class')),
    CONSTRAINT valid_target_type CHECK (target_type IN ('budget_class', 'expend_class'))
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_sankey_fiscal_year
    ON clean.state_spending_sankey(fiscal_year);
CREATE INDEX IF NOT EXISTS idx_sankey_source_type
    ON clean.state_spending_sankey(source_type);
