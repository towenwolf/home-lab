#!/usr/bin/env python3
"""
Data Warehouse Workflow Scheduler

Runs all workflow jobs on their configured schedules.
"""

import argparse
import logging
import signal
import sys

from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger

from jobs import stg_state_spending, load_state_spending

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Registry of all workflow jobs
JOBS = [
    {
        'id': 'stg_state_spending',
        'name': 'Oregon State Spending (Staging)',
        'func': stg_state_spending.run,
        'schedule': stg_state_spending.SCHEDULE,
    },
    {
        'id': 'load_state_spending',
        'name': 'State Spending (Load)',
        'func': load_state_spending.run,
        'schedule': load_state_spending.SCHEDULE,
    },
]


def run_all_jobs():
    """Run all workflow jobs immediately."""
    logger.info("Running all workflow jobs...")
    for job in JOBS:
        logger.info(f"Running job: {job['name']}")
        try:
            job['func']()
        except Exception as e:
            logger.error(f"Job {job['name']} failed: {e}")
    logger.info("All jobs completed")


def start_scheduler(run_on_startup: bool = False):
    """Start the scheduler with all registered jobs."""
    scheduler = BlockingScheduler()

    # Register all jobs
    for job in JOBS:
        schedule = job['schedule']
        scheduler.add_job(
            job['func'],
            CronTrigger(
                day_of_week=schedule['day_of_week'],
                hour=schedule['hour'],
                minute=schedule['minute']
            ),
            id=job['id'],
            name=job['name']
        )
        logger.info(
            f"Scheduled job '{job['name']}' for {schedule['day_of_week']} "
            f"at {schedule['hour']:02d}:{schedule['minute']:02d}"
        )

    # Run immediately on startup if requested
    if run_on_startup:
        run_all_jobs()

    # Handle graceful shutdown
    def shutdown(signum, frame):
        logger.info("Received shutdown signal, stopping scheduler...")
        scheduler.shutdown(wait=False)
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    logger.info("Scheduler started. Waiting for scheduled jobs...")

    try:
        scheduler.start()
    except (KeyboardInterrupt, SystemExit):
        logger.info("Scheduler stopped")


def main():
    parser = argparse.ArgumentParser(
        description='Data Warehouse Workflow Scheduler'
    )
    parser.add_argument(
        '--run-now',
        action='store_true',
        help='Run all jobs immediately and exit'
    )
    parser.add_argument(
        '--run-on-startup',
        action='store_true',
        help='Run all jobs immediately when starting scheduler'
    )
    parser.add_argument(
        '--job',
        type=str,
        help='Run a specific job by ID and exit'
    )

    args = parser.parse_args()

    if args.job:
        # Run specific job
        job = next((j for j in JOBS if j['id'] == args.job), None)
        if job:
            logger.info(f"Running job: {job['name']}")
            success = job['func']()
            sys.exit(0 if success else 1)
        else:
            logger.error(f"Unknown job: {args.job}")
            logger.info(f"Available jobs: {', '.join(j['id'] for j in JOBS)}")
            sys.exit(1)
    elif args.run_now:
        # Run all jobs and exit
        run_all_jobs()
    else:
        # Start scheduler
        start_scheduler(run_on_startup=args.run_on_startup)


if __name__ == '__main__':
    main()
