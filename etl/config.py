"""Configuration settings for ETL pipeline."""

import os
from pathlib import Path

# Base paths - relative to project root, with env override option
PROJECT_ROOT = Path(os.getenv("PROJECT_ROOT", Path(__file__).parent.parent))
DATA_DIR = PROJECT_ROOT / "data"
OUTPUT_DIR = PROJECT_ROOT / "cleaned_data"

# Source folder/file names - can be overridden via environment variables
ZOOM_FOLDER = os.getenv("ZOOM_FOLDER", "Zoom Attendance")
LABS_FILE = os.getenv("LABS_FILE", "Labs & Quizes/Labs & Quizes.xlsx")
PARTICIPATION_FILE_NAME = os.getenv("PARTICIPATION_FILE", "Participation/Participation records.xlsx")
STATUS_FILE_NAME = os.getenv("STATUS_FILE", "Status of Learners/Status of Participanat.xlsx")

# Constructed paths
ZOOM_DIR = DATA_DIR / ZOOM_FOLDER
LABS_QUIZZES_FILE = DATA_DIR / LABS_FILE
PARTICIPATION_FILE = DATA_DIR / PARTICIPATION_FILE_NAME
STATUS_FILE = DATA_DIR / STATUS_FILE_NAME

# Output files
OUTPUT_FILES = {
    "dim_learner": OUTPUT_DIR / "dim_learner.csv",
    "dim_date": OUTPUT_DIR / "dim_date.csv",
    "dim_week": OUTPUT_DIR / "dim_week.csv",
    "fact_attendance": OUTPUT_DIR / "fact_attendance.csv",
    "fact_assessment": OUTPUT_DIR / "fact_assessment.csv",
    "fact_participation": OUTPUT_DIR / "fact_participation.csv",
}

# Business rules
ATTENDANCE_THRESHOLD_MINUTES = int(os.getenv("ATTENDANCE_THRESHOLD", "30"))
