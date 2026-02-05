-- Helper function to add columns idempotently
-- Usage: SELECT add_column_if_not_exists('schema', 'table', 'column', 'type');

CREATE OR REPLACE FUNCTION add_column_if_not_exists(
    _schema TEXT,
    _table TEXT,
    _column TEXT,
    _type TEXT
) RETURNS VOID AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = _schema 
          AND table_name = _table 
          AND column_name = _column
    ) THEN
        EXECUTE format('ALTER TABLE %I.%I ADD COLUMN %I %s', _schema, _table, _column, _type);
        RAISE NOTICE 'Added column %.%.%', _schema, _table, _column;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Migration tracking table
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    filename TEXT PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
