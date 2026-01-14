# Infrastructure

Home lab infrastructure managed with Docker Compose.

## Services

### n8n
Workflow automation platform with PostgreSQL backend and pgAdmin for database management.

**Ports:**
- `5678` - n8n web UI
- `5050` - pgAdmin

**Setup:**
```bash
cd n8n
cp .env.example .env
# Edit .env with your values
docker compose up -d
```

## Configuration

Each service directory contains a `.env.example` file. Copy it to `.env` and configure before running.
