"""Utility functions for ETL pipeline."""

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


def parse_duration_to_minutes(duration_str):
    """Convert H:MM:SS format to total minutes."""
    parts = duration_str.split(":")
    hours = int(parts[0])
    minutes = int(parts[1])
    seconds = int(parts[2])
    return hours * 60 + minutes + seconds / 60


def extract_date_from_filename(filename):
    """Extract date from filename like '05-Aug-2024.csv'."""
    import pandas as pd
    date_str = Path(filename).stem
    return pd.to_datetime(date_str, format="%d-%b-%Y")


def extract_week_from_path(filepath):
    """Extract week number from path like 'Week 1/05-Aug-2024.csv'."""
    path = Path(filepath)
    week_folder = path.parent.name
    return int(week_folder.replace("Week ", ""))


def normalize_email(email):
    """Standardize email format."""
    return email.lower().strip()


def normalize_name(name):
    """Standardize name format."""
    return name.strip()


def ensure_output_dir(output_dir):
    """Create output directory if it doesn't exist."""
    Path(output_dir).mkdir(parents=True, exist_ok=True)
