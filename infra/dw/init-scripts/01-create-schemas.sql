-- Create schemas for data warehouse layers
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS clean;

-- Grant usage on schemas to the default user
GRANT ALL PRIVILEGES ON SCHEMA raw TO CURRENT_USER;
GRANT ALL PRIVILEGES ON SCHEMA clean TO CURRENT_USER;
