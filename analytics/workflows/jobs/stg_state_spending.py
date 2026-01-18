"""
Oregon State Spending Data Extraction Job

Extracts data from the SODA API (data.oregon.gov) and loads into PostgreSQL.
Source: https://data.oregon.gov/resource/y9g9-xsxs.json
"""

import logging
import os
import time
import uuid
from decimal import Decimal
from typing import Generator

import psycopg2
from psycopg2.extras import execute_values
import requests

logger = logging.getLogger(__name__)

# Configuration
SODA_API_BASE = "https://data.oregon.gov/resource/y9g9-xsxs.json"
BATCH_SIZE = 50000
RATE_LIMIT_DELAY = 1

# Retry configuration
MAX_RETRIES = 3
RETRY_DELAY_429 = 60
RETRY_DELAY_5XX = 5
RETRY_DELAY_CONN = 10

# Schedule configuration
SCHEDULE = {
    'day_of_week': os.environ.get('STATE_SPENDING_SCHEDULE_DAY', 'sun'),
    'hour': int(os.environ.get('STATE_SPENDING_SCHEDULE_HOUR', '2')),
    'minute': int(os.environ.get('STATE_SPENDING_SCHEDULE_MINUTE', '0')),
}


def get_db_connection():
    """Create database connection from environment variables."""
    return psycopg2.connect(
        host=os.environ.get('DB_HOST', 'localhost'),
        port=os.environ.get('DB_PORT', '5432'),
        database=os.environ.get('DB_NAME', 'dw'),
        user=os.environ.get('DB_USER', 'analytics'),
        password=os.environ.get('DB_PASSWORD', 'analytics')
    )


def fetch_page(offset: int, app_token: str) -> list[dict]:
    """Fetch a single page of data from the SODA API with retry logic."""
    headers = {'X-App-Token': app_token}
    params = {
        '$limit': BATCH_SIZE,
        '$offset': offset,
        '$order': ':id'
    }

    for attempt in range(MAX_RETRIES):
        try:
            response = requests.get(
                SODA_API_BASE,
                headers=headers,
                params=params,
                timeout=60
            )

            if response.status_code == 200:
                return response.json()

            if response.status_code == 429:
                wait_time = RETRY_DELAY_429 * (2 ** attempt)
                logger.warning(f"Rate limited (429). Waiting {wait_time}s before retry {attempt + 1}/{MAX_RETRIES}")
                time.sleep(wait_time)
                continue

            if 500 <= response.status_code < 600:
                wait_time = RETRY_DELAY_5XX * (2 ** attempt)
                logger.warning(f"Server error ({response.status_code}). Waiting {wait_time}s before retry {attempt + 1}/{MAX_RETRIES}")
                time.sleep(wait_time)
                continue

            response.raise_for_status()

        except requests.exceptions.ConnectionError as e:
            wait_time = RETRY_DELAY_CONN * (2 ** attempt)
            logger.warning(f"Connection error: {e}. Waiting {wait_time}s before retry {attempt + 1}/{MAX_RETRIES}")
            time.sleep(wait_time)
        except requests.exceptions.Timeout as e:
            wait_time = RETRY_DELAY_CONN * (2 ** attempt)
            logger.warning(f"Timeout: {e}. Waiting {wait_time}s before retry {attempt + 1}/{MAX_RETRIES}")
            time.sleep(wait_time)

    raise Exception(f"Failed to fetch data after {MAX_RETRIES} retries (offset={offset})")


def fetch_all_data(app_token: str) -> Generator[list[dict], None, None]:
    """Generator that fetches all data from the API with pagination."""
    offset = 0
    total_fetched = 0

    while True:
        logger.info(f"Fetching batch at offset {offset}...")
        batch = fetch_page(offset, app_token)

        if not batch:
            logger.info(f"No more data. Total records fetched: {total_fetched}")
            break

        total_fetched += len(batch)
        logger.info(f"Fetched {len(batch)} records (total: {total_fetched})")

        yield batch

        if len(batch) < BATCH_SIZE:
            logger.info(f"Last batch received. Total records fetched: {total_fetched}")
            break

        offset += BATCH_SIZE
        time.sleep(RATE_LIMIT_DELAY)


def transform_record(record: dict, batch_id: uuid.UUID) -> tuple:
    """Transform a SODA API record to database tuple."""
    def safe_int(value):
        if value is None:
            return None
        try:
            return int(value)
        except (ValueError, TypeError):
            return None

    def safe_decimal(value):
        if value is None:
            return None
        try:
            return Decimal(str(value))
        except (ValueError, TypeError):
            return None

    return (
        safe_int(record.get('fiscal_year')),
        safe_int(record.get('agency')),
        record.get('agency_1'),
        safe_int(record.get('budget_class')),
        record.get('budget_class_1'),
        safe_int(record.get('expend_class')),
        record.get('expend_class_1'),
        record.get('vendor'),
        safe_decimal(record.get('expense')),
        record.get('vendor_st'),
        str(batch_id)
    )


def insert_batch(cursor, records: list[dict], batch_id: uuid.UUID) -> int:
    """Insert a batch of records into the database."""
    if not records:
        return 0

    transformed = [transform_record(r, batch_id) for r in records]

    insert_sql = """
        INSERT INTO raw.state_spending (
            fiscal_year, agency, agency_name, budget_class, budget_class_name,
            expend_class, expend_class_name, vendor, expense, vendor_state, batch_id
        ) VALUES %s
    """

    execute_values(cursor, insert_sql, transformed)
    return len(transformed)


def run():
    """Main extraction function."""
    app_token = os.environ.get('SODA_APP_TOKEN')
    if not app_token:
        logger.error("SODA_APP_TOKEN environment variable not set")
        return False

    batch_id = uuid.uuid4()
    logger.info(f"Starting state_spending extraction with batch_id: {batch_id}")

    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        logger.info("Truncating raw.state_spending table...")
        cursor.execute("TRUNCATE TABLE raw.state_spending")
        conn.commit()
        logger.info("Table truncated successfully")

        total_inserted = 0

        for batch in fetch_all_data(app_token):
            inserted = insert_batch(cursor, batch, batch_id)
            total_inserted += inserted
            conn.commit()
            logger.info(f"Committed batch. Total inserted: {total_inserted}")

        logger.info(f"Extraction complete. Total records inserted: {total_inserted}")
        logger.info(f"Batch ID: {batch_id}")
        return True

    except Exception as e:
        conn.rollback()
        logger.error(f"Error during extraction: {e}")
        return False
    finally:
        cursor.close()
        conn.close()
