"""Utility function for ETL pipeline."""

import logging
import sys
from pathlib import Path


def setup_logging(log_file=None):
    """Configure logging for the pipeline."""
    handlers = [logging.StreamHandler(sys.stdout)]

    if log_file:
        handlers.append(logging.FileHandler(log_file))

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)-8s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=handlers
    )
    return logging.getLogger(__name__)


def ensure_output_dir(output_dir):
    """Create output directory if it doesn't exist."""
    Path(output_dir).mkdir(parents=True, exist_ok=True)
