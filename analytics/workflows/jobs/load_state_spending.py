"""
State Spending Sankey Transformation Job

Transforms raw.state_spending into clean.state_spending_sankey
for Sankey diagram visualization.

Creates two types of links per fiscal year:
1. Agency → Budget Class (aggregated expenses)
2. Budget Class → Expenditure Class (aggregated expenses)
"""

import logging
import os

import psycopg2

logger = logging.getLogger(__name__)

# Schedule: Run after state_spending extraction (Sunday 3am)
SCHEDULE = {
    'day_of_week': os.environ.get('STATE_SPENDING_SANKEY_SCHEDULE_DAY', 'sun'),
    'hour': int(os.environ.get('STATE_SPENDING_SANKEY_SCHEDULE_HOUR', '3')),
    'minute': int(os.environ.get('STATE_SPENDING_SANKEY_SCHEDULE_MINUTE', '0')),
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


def run():
    """Transform raw state spending data into Sankey format."""
    logger.info("Starting state_spending_sankey transformation")

    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        # Truncate clean table
        logger.info("Truncating clean.state_spending_sankey table...")
        cursor.execute("TRUNCATE TABLE clean.state_spending_sankey")

        # Insert Agency → Budget Class links
        logger.info("Creating Agency → Budget Class links...")
        cursor.execute("""
            INSERT INTO clean.state_spending_sankey (
                fiscal_year,
                source_id, source_name, source_type,
                target_id, target_name, target_type,
                total_expense
            )
            SELECT
                fiscal_year,
                agency, agency_name, 'agency',
                budget_class, budget_class_name, 'budget_class',
                SUM(expense)
            FROM raw.state_spending
            WHERE agency IS NOT NULL
              AND budget_class IS NOT NULL
            GROUP BY
                fiscal_year,
                agency, agency_name,
                budget_class, budget_class_name
        """)
        agency_to_budget_count = cursor.rowcount
        logger.info(f"Inserted {agency_to_budget_count} Agency → Budget Class links")

        # Insert Budget Class → Expenditure Class links
        logger.info("Creating Budget Class → Expenditure Class links...")
        cursor.execute("""
            INSERT INTO clean.state_spending_sankey (
                fiscal_year,
                source_id, source_name, source_type,
                target_id, target_name, target_type,
                total_expense
            )
            SELECT
                fiscal_year,
                budget_class, budget_class_name, 'budget_class',
                expend_class, expend_class_name, 'expend_class',
                SUM(expense)
            FROM raw.state_spending
            WHERE budget_class IS NOT NULL
              AND expend_class IS NOT NULL
            GROUP BY
                fiscal_year,
                budget_class, budget_class_name,
                expend_class, expend_class_name
        """)
        budget_to_expend_count = cursor.rowcount
        logger.info(f"Inserted {budget_to_expend_count} Budget Class → Expenditure Class links")

        conn.commit()

        total_links = agency_to_budget_count + budget_to_expend_count
        logger.info(f"Transformation complete. Total links created: {total_links}")
        return True

    except Exception as e:
        conn.rollback()
        logger.error(f"Error during transformation: {e}")
        return False
    finally:
        cursor.close()
        conn.close()
