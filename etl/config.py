"""Configuration settings for ETL pipeline."""

from pathlib import Path

# Base paths
BASE_DIR = Path(r"C:\Users\Daniel\Desktop\Amalitech NSS\power bi project")
DATA_DIR = BASE_DIR / "data"
OUTPUT_DIR = BASE_DIR / "cleaned_data"

# Source paths
ZOOM_DIR = DATA_DIR / "Zoom Attendance"
LABS_QUIZZES_FILE = DATA_DIR / "Labs & Quizes" / "Labs & Quizes.xlsx"
PARTICIPATION_FILE = DATA_DIR / "Participation" / "Participation records.xlsx"
STATUS_FILE = DATA_DIR / "Status of Learners" / "Status of Participanat.xlsx"

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
ATTENDANCE_THRESHOLD_MINUTES = 30

# Date settings
PROGRAM_START_DATE = "2024-08-05"
PROGRAM_END_DATE = "2024-10-11"
