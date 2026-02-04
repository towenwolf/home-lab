# dbt Project

Transforms raw data into analytical schemas.

## Structure

```
dbt_project/
├── dbt_project.yml    # Project config
└── models/            # Your SQL models (SELECT statements)
    └── staging/       # Staging models
```

## Usage

```bash
cd shared/dbt
docker compose up -d

# Test connection
docker exec -it dbt dbt debug

# Run all models
docker exec -it dbt dbt run
```
