"""Main ETL pipeline for Dare Careers Power BI project."""

import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from config import (
    ZOOM_DIR,
    LABS_QUIZZES_FILE,
    PARTICIPATION_FILE,
    STATUS_FILE,
    OUTPUT_DIR,
    OUTPUT_FILES,
    LOGS_DIR
)
from utils import setup_logging, ensure_output_dir
from loaders import (
    load_zoom_attendance,
    load_labs,
    load_quizzes,
    load_participation,
    load_status
)
from transformers import (
    transform_zoom_attendance,
    transform_assessments,
    transform_participation,
    create_dim_learner,
    create_dim_date,
    create_dim_week,
    create_name_email_mapping
)


def save_dataframe(df, filepath, index=False):
    """Save dataframe to CSV with logging."""
    logger = logging.getLogger(__name__)
    df.to_csv(filepath, index=index)
    logger.info(f"Saved {len(df)} records to {filepath.name}")


def run_pipeline():
    """Execute the full ETL pipeline."""

    ensure_output_dir(LOGS_DIR)
    log_file = LOGS_DIR / "etl_pipeline.log"
    setup_logging(log_file)
    logger = logging.getLogger(__name__)

    logger.info("=" * 60)
    logger.info("STARTING ETL PIPELINE")
    logger.info("=" * 60)

    try:
        # Phase 1: Load
        logger.info("-" * 40)
        logger.info("PHASE 1: Loading raw data")
        logger.info("-" * 40)

        zoom_raw = load_zoom_attendance(ZOOM_DIR)
        labs_raw = load_labs(LABS_QUIZZES_FILE)
        quizzes_raw = load_quizzes(LABS_QUIZZES_FILE)
        participation_raw = load_participation(PARTICIPATION_FILE)
        status_raw = load_status(STATUS_FILE)

        # Phase 2: Transform facts
        logger.info("-" * 40)
        logger.info("PHASE 2: Transforming data")
        logger.info("-" * 40)

        fact_attendance = transform_zoom_attendance(zoom_raw)
        fact_assessment = transform_assessments(labs_raw, quizzes_raw)

        name_email_map = create_name_email_mapping(fact_attendance)
        fact_participation = transform_participation(participation_raw, name_email_map)

        # Phase 3: Create dimensions (derived from facts)
        logger.info("-" * 40)
        logger.info("PHASE 3: Creating dimensions")
        logger.info("-" * 40)

        dim_learner = create_dim_learner(status_raw, fact_attendance)
        dim_date = create_dim_date(fact_attendance, fact_participation)
        dim_week = create_dim_week(fact_attendance)

        # Phase 4: Save
        logger.info("-" * 40)
        logger.info("PHASE 4: Saving cleaned data")
        logger.info("-" * 40)

        save_dataframe(dim_learner, OUTPUT_FILES["dim_learner"])
        save_dataframe(dim_date, OUTPUT_FILES["dim_date"])
        save_dataframe(dim_week, OUTPUT_FILES["dim_week"])
        save_dataframe(fact_attendance, OUTPUT_FILES["fact_attendance"])
        save_dataframe(fact_assessment, OUTPUT_FILES["fact_assessment"])
        save_dataframe(fact_participation, OUTPUT_FILES["fact_participation"])

        # Summary
        logger.info("-" * 40)
        logger.info("PIPELINE SUMMARY")
        logger.info("-" * 40)
        logger.info(f"dim_learner:        {len(dim_learner):>6} records")
        logger.info(f"dim_date:           {len(dim_date):>6} records")
        logger.info(f"dim_week:           {len(dim_week):>6} records")
        logger.info(f"fact_attendance:    {len(fact_attendance):>6} records")
        logger.info(f"fact_assessment:    {len(fact_assessment):>6} records")
        logger.info(f"fact_participation: {len(fact_participation):>6} records")

        logger.info("=" * 60)
        logger.info("ETL PIPELINE COMPLETED SUCCESSFULLY")
        logger.info("=" * 60)

        return True

    except Exception as e:
        logger.error(f"Pipeline failed: {str(e)}", exc_info=True)
        return False


if __name__ == "__main__":
    success = run_pipeline()
    sys.exit(0 if success else 1)
