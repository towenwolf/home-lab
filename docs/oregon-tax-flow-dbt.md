# Oregon Tax Dollar Flow — dbt Project

Transform raw Oregon state spending data into analytics-ready models that power the Sankey visualization showing where every income tax dollar goes.

> This powers the Oregon Tax Dollar Flow visualization — an interactive Sankey showing where your income tax goes.

## TL;DR

```bash
dbt deps && dbt run && dbt test
```

This creates `serve.fct_sankey_links` — the main table for the Sankey API.

---

## Quick Start

1. **Setup**: `cp profiles.yml ~/.dbt/ && dbt deps`
2. **Run**: `dbt run`
3. **Verify**: `dbt test`

See [Detailed Setup](#detailed-setup) for configuration options.

---

## What You Get

After running, these tables are available:

| Table | Purpose |
|-------|---------|
| `serve.fct_sankey_links` | Sankey diagram data |
| `serve.dim_fiscal_year_stats` | Dashboard stats |
| `serve.dim_agency_summary` | Agency breakdown |

### `fct_sankey_links` (Main Model)

The primary model consumed by the API.

```sql
SELECT * FROM serve.fct_sankey_links WHERE fiscal_year = 2023;
```

| Column       | Type    | Description                              |
|--------------|---------|------------------------------------------|
| fiscal_year  | integer | State fiscal year                        |
| source       | text    | Source node name                         |
| target       | text    | Target node name                         |
| source_layer | integer | 0=Tax, 1=GF, 2=Agency, 3=Budget          |
| target_layer | integer | source_layer + 1                         |
| value        | numeric | Per-dollar allocation (×0.816 PIT share) |
| link_type    | text    | Link classification                      |

---

## Project Structure

```
dbt_project/
├── dbt_project.yml       # Project config
├── models/
│   ├── staging/          # Raw data cleaning (1:1 with source)
│   ├── intermediate/     # Business logic & aggregations
│   └── marts/            # Final API-ready tables ← start here
└── macros/               # Reusable SQL helpers
```

### Model Layers

- **staging/** — Light transformations, 1:1 with source tables
- **intermediate/** — Business logic, aggregations, joins
- **marts/** — API-ready final models (what you query)

---

## Detailed Setup

### Install dbt

```bash
pip install dbt-postgres
```

### Configure database connection

Copy `profiles.yml` to `~/.dbt/profiles.yml` and update with your credentials:

```bash
cp profiles.yml ~/.dbt/profiles.yml
```

Or set environment variables:

```bash
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export POSTGRES_DB=oregon
```

### Install dependencies & verify

```bash
dbt deps
dbt debug
```

---

## Common Commands

```bash
# Full run
dbt run

# Run specific model
dbt run --select fct_sankey_links

# Run with upstream dependencies
dbt run --select +fct_sankey_links

# Run tests
dbt test

# Generate documentation
dbt docs generate && dbt docs serve
```

---

## Configuration Variables

Set in `dbt_project.yml` or override at runtime:

```yaml
vars:
  pit_share_of_general_fund: 0.816  # Personal income tax share
  top_vendors_limit: 15              # Vendors shown before "OTHER"
  top_agencies_limit: 15             # Agencies shown before grouping
```

Override at runtime:

```bash
dbt run --vars '{"pit_share_of_general_fund": 0.82}'
```

---

## How It Works

### DAG (Directed Acyclic Graph)

```
raw.state_spending
        │
        ▼
┌───────────────────┐
│ stg_state_spending │  ← View (always fresh)
└───────────────────┘
        │
        ▼
┌─────────────────────┐
│int_fiscal_year_totals│ ← Denominator for per-dollar calc
└─────────────────────┘
        │
        ├──────────┬──────────┬───────────┐
        ▼          ▼          ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│int_agency│ │int_budget│ │int_expend│ │int_vendor│
└──────────┘ └──────────┘ └──────────┘ └──────────┘
        │          │          │           │
        └──────────┴────┬─────┴───────────┘
                        ▼
              ┌─────────────────┐
              │ fct_sankey_links │ ← Main API model
              └─────────────────┘
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
┌──────────────┐                 ┌──────────────┐
│dim_fy_stats  │                 │dim_agency    │
└──────────────┘                 └──────────────┘
```

---

## Development Workflow

```bash
# 1. Make changes to models
vim models/marts/fct_sankey_links.sql

# 2. Compile to see generated SQL
dbt compile --select fct_sankey_links

# 3. Run single model
dbt run --select fct_sankey_links

# 4. Test
dbt test --select fct_sankey_links

# 5. Generate fresh docs
dbt docs generate
```

---

## Data Quality

The project includes:

- **Schema tests** — uniqueness, not_null, accepted_values
- **Relationship tests** — referential integrity between models
- **Custom tests** — Sankey flow conservation (layer sums match)

```bash
# Run all tests
dbt test

# Test specific model
dbt test --select fct_sankey_links
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "relation does not exist" | Run with dependencies: `dbt run --select +fct_sankey_links` |
| Stale data | Force refresh: `dbt run --full-refresh` |
| Connection issues | Check config: `dbt debug` |
