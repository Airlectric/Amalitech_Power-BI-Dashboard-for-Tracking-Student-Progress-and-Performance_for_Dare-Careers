"""Data transformation functions for ETL pipeline."""

import logging
import pandas as pd
import numpy as np
from config import ATTENDANCE_THRESHOLD_MINUTES

logger = logging.getLogger(__name__)


def parse_duration_vectorized(duration_series):
    """Vectorized duration parsing - H:MM:SS to minutes."""
    split = duration_series.str.split(":", expand=True).astype(int)
    return split[0] * 60 + split[1] + split[2] / 60


def extract_date_from_filenames(filename_series):
    """Vectorized date extraction from filenames."""
    date_strings = filename_series.str.replace(".csv", "", regex=False)
    return pd.to_datetime(date_strings, format="%d-%b-%Y")


def extract_week_from_paths(path_series):
    """Vectorized week extraction from paths."""
    return path_series.str.extract(r"Week (\d+)", expand=False).astype(int)


def transform_zoom_attendance(df):
    """Transform raw Zoom attendance data into fact table."""
    logger.info("Transforming Zoom attendance data")

    result = pd.DataFrame()

    result["email"] = df["Email"].str.lower().str.strip()
    result["learner_name"] = df["Name"].str.strip()
    result["duration_minutes"] = parse_duration_vectorized(df["Duration"])
    result["duration_hours"] = result["duration_minutes"] / 60
    result["is_attended"] = (result["duration_minutes"] > ATTENDANCE_THRESHOLD_MINUTES).astype(np.int8)
    result["attendance_date"] = extract_date_from_filenames(df["source_file"])
    result["week_number"] = extract_week_from_paths(df["source_path"])
    result["join_time"] = df["Join Time"]
    result["leave_time"] = df["Leave Time"]
    result["attendance_id"] = np.arange(1, len(result) + 1)

    result = result[[
        "attendance_id", "email", "learner_name", "attendance_date",
        "week_number", "join_time", "leave_time", "duration_minutes",
        "duration_hours", "is_attended"
    ]]

    logger.info(f"Created fact_attendance with {len(result)} records")
    return result


def transform_assessments(labs_df, quizzes_df):
    """Transform labs and quizzes into unified assessment fact table."""
    logger.info("Transforming assessment data")

    labs_melted = labs_df.melt(id_vars=["email"], var_name="week", value_name="score")
    labs_melted["assessment_type"] = "Lab"

    quizzes_melted = quizzes_df.melt(id_vars=["email"], var_name="week", value_name="score")
    quizzes_melted["assessment_type"] = "Quiz"

    combined = pd.concat([labs_melted, quizzes_melted], ignore_index=True)
    combined["email"] = combined["email"].str.lower().str.strip()
    combined["week_number"] = combined["week"].str.extract(r"(\d+)", expand=False).astype(np.int8)
    combined["assessment_id"] = np.arange(1, len(combined) + 1)

    result = combined[["assessment_id", "email", "week_number", "assessment_type", "score"]]

    logger.info(f"Created fact_assessment with {len(result)} records")
    return result


def transform_participation(participation_df, name_email_map):
    """Transform participation records using vectorized explode."""
    logger.info("Transforming participation data")

    df = participation_df.copy()
    df["participants_list"] = df["Participants"].str.split(",")

    exploded = df.explode("participants_list")
    exploded["learner_name"] = exploded["participants_list"].str.strip()

    email_series = pd.Series(name_email_map)
    exploded["email"] = exploded["learner_name"].map(email_series)
    exploded = exploded.dropna(subset=["email"])
    exploded["participation_date"] = pd.to_datetime(exploded["Date"], format="%d-%b-%Y")

    result = pd.DataFrame({
        "participation_id": np.arange(1, len(exploded) + 1),
        "email": exploded["email"].values,
        "learner_name": exploded["learner_name"].values,
        "participation_date": exploded["participation_date"].values,
        "participated": np.int8(1)
    })

    logger.info(f"Created fact_participation with {len(result)} records")
    return result


def create_dim_learner(status_df, attendance_df):
    """Create learner dimension table."""
    logger.info("Creating dim_learner")

    result = status_df.copy()
    result["email"] = result["email"].str.lower().str.strip()

    name_lookup = attendance_df[["email", "learner_name"]].drop_duplicates(subset=["email"])
    name_map = name_lookup.set_index("email")["learner_name"]
    result["learner_name"] = result["email"].map(name_map)

    result["is_graduated"] = (result["Graduation Status"] == "Graduate").astype(np.int8)
    result["is_certified"] = (result["Certification Status"] == "Certified").astype(np.int8)
    result["learner_id"] = np.arange(1, len(result) + 1)

    result = result.rename(columns={
        "Graduation Status": "graduation_status",
        "Certification Status": "certification_status"
    })

    result = result[[
        "learner_id", "email", "learner_name", "graduation_status",
        "certification_status", "is_graduated", "is_certified"
    ]]

    logger.info(f"Created dim_learner with {len(result)} records")
    return result


def create_dim_date(fact_attendance, fact_participation):
    """Create date dimension from actual data dates."""
    logger.info("Creating dim_date from actual data")

    # Get all unique dates from fact tables
    attendance_dates = pd.to_datetime(fact_attendance["attendance_date"])
    participation_dates = pd.to_datetime(fact_participation["participation_date"])

    all_dates = pd.concat([attendance_dates, participation_dates]).drop_duplicates().sort_values()

    # Create continuous date range from min to max
    date_range = pd.date_range(start=all_dates.min(), end=all_dates.max(), freq="D")

    dim_date = pd.DataFrame({"date": date_range})
    dim_date["date_key"] = (
        dim_date["date"].dt.year * 10000 +
        dim_date["date"].dt.month * 100 +
        dim_date["date"].dt.day
    )
    dim_date["year"] = dim_date["date"].dt.year
    dim_date["month"] = dim_date["date"].dt.month
    dim_date["month_name"] = dim_date["date"].dt.month_name()
    dim_date["day"] = dim_date["date"].dt.day
    dim_date["day_name"] = dim_date["date"].dt.day_name()
    dim_date["day_of_week"] = dim_date["date"].dt.dayofweek
    dim_date["week_of_year"] = dim_date["date"].dt.isocalendar().week.astype(int)
    dim_date["is_weekend"] = dim_date["day_of_week"].isin([5, 6]).astype(np.int8)

    dim_date = dim_date[[
        "date_key", "date", "year", "month", "month_name",
        "day", "day_name", "day_of_week", "week_of_year", "is_weekend"
    ]]

    logger.info(f"Created dim_date with {len(dim_date)} records (from {all_dates.min().date()} to {all_dates.max().date()})")
    return dim_date


def create_dim_week(fact_attendance):
    """Create week dimension from actual attendance data."""
    logger.info("Creating dim_week from actual data")

    # Get unique weeks and their date ranges from actual data
    attendance = fact_attendance.copy()
    attendance["attendance_date"] = pd.to_datetime(attendance["attendance_date"])

    week_stats = attendance.groupby("week_number").agg(
        week_start_date=("attendance_date", "min"),
        week_end_date=("attendance_date", "max")
    ).reset_index()

    week_stats["week_label"] = "Week " + week_stats["week_number"].astype(str)

    dim_week = week_stats[["week_number", "week_start_date", "week_end_date", "week_label"]]

    logger.info(f"Created dim_week with {len(dim_week)} records")
    return dim_week


def create_name_email_mapping(attendance_df):
    """Create mapping from learner names to emails."""
    mapping = attendance_df.drop_duplicates(subset=["learner_name"]).set_index("learner_name")["email"].to_dict()
    logger.info(f"Created name-to-email mapping with {len(mapping)} entries")
    return mapping
