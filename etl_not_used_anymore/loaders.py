import logging
import pandas as pd
from pathlib import Path

logger = logging.getLogger(__name__)


def load_zoom_attendance(zoom_dir):
    """Load and combine all Zoom attendance CSV files."""
    zoom_path = Path(zoom_dir)
    all_files = list(zoom_path.rglob("*.csv"))
    logger.info(f"Found {len(all_files)} Zoom attendance files")

    dfs = []
    for file in all_files:
        df = pd.read_csv(file)
        df["source_file"] = file.name
        df["source_path"] = str(file)
        dfs.append(df)

    combined = pd.concat(dfs, ignore_index=True)
    logger.info(f"Loaded {len(combined)} total attendance records")
    return combined


def load_labs(filepath):
    """Load labs data from Excel."""
    df = pd.read_excel(filepath, sheet_name="Labs")
    logger.info(f"Loaded {len(df)} lab records")
    return df


def load_quizzes(filepath):
    """Load quizzes data from Excel."""
    df = pd.read_excel(filepath, sheet_name="Quizzes")
    logger.info(f"Loaded {len(df)} quiz records")
    return df


def load_participation(filepath):
    """Load participation records from Excel."""
    df = pd.read_excel(filepath)
    logger.info(f"Loaded {len(df)} participation records")
    return df


def load_status(filepath):
    """Load learner status from Excel."""
    df = pd.read_excel(filepath)
    logger.info(f"Loaded {len(df)} status records")
    return df
