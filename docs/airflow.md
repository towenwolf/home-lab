# Airflow

Apache Airflow deployment for orchestrating data pipelines and workflows.

## Docker Compose Services

### 1. postgres (Database)

- **Image**: PostgreSQL 16
- **Purpose**: Metadata database for Airflow. Stores all DAG runs, task states, connections, variables, and user information.
- **Key features**:
  - Data persisted to `/mnt/d/airflow/postgres`
  - Health check ensures the database is ready before dependent services start
  - Credentials configured via environment variables

### 2. airflow-init (One-time Initialization)

- **Image**: Apache Airflow 2.10.4
- **Purpose**: Bootstrap service that runs once to set up Airflow.
- **Actions**:
  - Runs `airflow db migrate` to create/update database schema
  - Creates the initial admin user with credentials from environment variables
- **Key features**:
  - Only starts after Postgres is healthy
  - Exits after completion (not a long-running service)

### 3. airflow-webserver (UI)

- **Image**: Apache Airflow 2.10.4
- **Purpose**: Web interface for monitoring and managing DAGs, viewing logs, triggering runs, and administration.
- **Key features**:
  - Exposed on port **8080**
  - Uses `LocalExecutor` (runs tasks in the scheduler process)
  - RBAC enabled for role-based access control
  - Example DAGs disabled (`LOAD_EXAMPLES: false`)
  - Health check via `/health` endpoint

### 4. airflow-scheduler (Task Execution)

- **Image**: Apache Airflow 2.10.4
- **Purpose**: The brain of Airflow. Monitors DAG files, determines when tasks should run based on schedules/dependencies, and executes tasks.
- **Key features**:
  - Shares the same DAGs/logs/plugins volumes as webserver
  - With LocalExecutor, tasks run as subprocesses on the scheduler
  - Health check verifies the scheduler job is running

## Architecture Notes

This deployment uses **LocalExecutor**, which means:

- No separate worker containers (simpler, less overhead)
- Tasks execute as subprocesses on the scheduler
- Good for light-to-moderate workloads

All Airflow services share:

- The same Fernet key (for encrypting sensitive data like connections)
- Volume mounts for `/dags`, `/logs`, and `/plugins`
- Timezone set to `America/Los_Angeles`

## Environment Variables

Required variables (set in `.env` file):

| Variable | Description |
|----------|-------------|
| `POSTGRES_USER` | PostgreSQL username |
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `POSTGRES_DB` | PostgreSQL database name |
| `AIRFLOW_ADMIN_USER` | Airflow admin username |
| `AIRFLOW_ADMIN_PASSWORD` | Airflow admin password |
| `AIRFLOW_ADMIN_EMAIL` | Airflow admin email |
| `AIRFLOW_FERNET_KEY` | Encryption key for sensitive data |

## Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/mnt/d/airflow/postgres` | `/var/lib/postgresql/data` | PostgreSQL data |
| `/mnt/d/airflow/dags` | `/opt/airflow/dags` | DAG definitions |
| `/mnt/d/airflow/logs` | `/opt/airflow/logs` | Task logs |
| `/mnt/d/airflow/plugins` | `/opt/airflow/plugins` | Custom plugins |
