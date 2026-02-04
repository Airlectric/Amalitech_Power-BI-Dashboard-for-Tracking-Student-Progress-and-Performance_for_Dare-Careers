import logging
import pandas as pd
import numpy as np
from utils import (
    parse_duration_to_minutes,
    extract_date_from_filename,
    extract_week_from_path,
    normalize_email,
    normalize_name
)
from config import ATTENDANCE_THRESHOLD_MINUTES, PROGRAM_START_DATE, PROGRAM_END_DATE

logger = logging.getLogger(__name__)


def transform_zoom_attendance(df):
    """Transform raw Zoom attendance data into fact table."""
    logger.info("Transforming Zoom attendance data")

    result = df.copy()

    # Normalize email
    result["email"] = result["Email"].apply(normalize_email)

    # Parse duration to minutes
    result["duration_minutes"] = result["Duration"].apply(parse_duration_to_minutes)

    # Calculate hours for reporting
    result["duration_hours"] = result["duration_minutes"] / 60

    # Apply attendance rule (>30 minutes)
    result["is_attended"] = (result["duration_minutes"] > ATTENDANCE_THRESHOLD_MINUTES).astype(int)

    # Extract date from filename
    result["attendance_date"] = result["source_file"].apply(extract_date_from_filename)

    # Extract week number
    result["week_number"] = result["source_path"].apply(extract_week_from_path)

    # Create surrogate key
    result["attendance_id"] = (
        result["email"] + "_" + result["attendance_date"].dt.strftime("%Y%m%d")
    )

    # Select and rename final columns
    fact_attendance = result[[
        "attendance_id",
        "email",
        "Name",
        "attendance_date",
        "week_number",
        "Join Time",
        "Leave Time",
        "duration_minutes",
        "duration_hours",
        "is_attended"
    ]].copy()

    fact_attendance.columns = [
        "attendance_id",
        "email",
        "learner_name",
        "attendance_date",
        "week_number",
        "join_time",
        "leave_time",
        "duration_minutes",
        "duration_hours",
        "is_attended"
    ]

    logger.info(f"Created fact_attendance with {len(fact_attendance)} records")
    return fact_attendance


def transform_assessments(labs_df, quizzes_df):
    """Transform labs and quizzes into unified assessment fact table."""
    logger.info("Transforming assessment data")

    # Unpivot labs
    labs_melted = labs_df.melt(
        id_vars=["email"],
        var_name="week",
        value_name="score"
    )
    labs_melted["assessment_type"] = "Lab"

    # Unpivot quizzes
    quizzes_melted = quizzes_df.melt(
        id_vars=["email"],
        var_name="week",
        value_name="score"
    )
    quizzes_melted["assessment_type"] = "Quiz"

    # Combine
    combined = pd.concat([labs_melted, quizzes_melted], ignore_index=True)

    # Normalize email
    combined["email"] = combined["email"].apply(normalize_email)

    # Extract week number
    combined["week_number"] = combined["week"].str.extract(r"(\d+)").astype(int)

    # Create surrogate key
    combined["assessment_id"] = (
        combined["email"] + "_" +
        combined["assessment_type"].str.lower() + "_" +
        combined["week_number"].astype(str)
    )

    # Select final columns
    fact_assessment = combined[[
        "assessment_id",
        "email",
        "week_number",
        "assessment_type",
        "score"
    ]].copy()

    logger.info(f"Created fact_assessment with {len(fact_assessment)} records")
    return fact_assessment


def transform_participation(participation_df, name_email_map):
    """Transform participation records into fact table."""
    logger.info("Transforming participation data")

    records = []
    for _, row in participation_df.iterrows():
        date = row["Date"]
        participants = [normalize_name(n) for n in row["Participants"].split(",")]

        for name in participants:
            email = name_email_map.get(name)
            if email:
                records.append({
                    "participation_date": date,
                    "learner_name": name,
                    "email": email,
                    "participated": 1
                })

    fact_participation = pd.DataFrame(records)

    # Parse date
    fact_participation["participation_date"] = pd.to_datetime(
        fact_participation["participation_date"],
        format="%d-%b-%Y"
    )

    # Create surrogate key
    fact_participation["participation_id"] = (
        fact_participation["email"] + "_" +
        fact_participation["participation_date"].dt.strftime("%Y%m%d")
    )

    # Reorder columns
    fact_participation = fact_participation[[
        "participation_id",
        "email",
        "learner_name",
        "participation_date",
        "participated"
    ]]

    logger.info(f"Created fact_participation with {len(fact_participation)} records")
    return fact_participation


def create_dim_learner(status_df, attendance_df):
    """Create learner dimension table."""
    logger.info("Creating dim_learner")

    # Start with status data
    dim_learner = status_df.copy()
    dim_learner["email"] = dim_learner["email"].apply(normalize_email)

    # Get name mapping from attendance
    name_map = attendance_df.groupby("email")["learner_name"].first().to_dict()
    dim_learner["learner_name"] = dim_learner["email"].map(name_map)

    # Create binary flags
    dim_learner["is_graduated"] = (dim_learner["Graduation Status"] == "Graduate").astype(int)
    dim_learner["is_certified"] = (dim_learner["Certification Status"] == "Certified").astype(int)

    # Create surrogate key
    dim_learner["learner_id"] = range(1, len(dim_learner) + 1)

    # Rename and select columns
    dim_learner = dim_learner[[
        "learner_id",
        "email",
        "learner_name",
        "Graduation Status",
        "Certification Status",
        "is_graduated",
        "is_certified"
    ]]

    dim_learner.columns = [
        "learner_id",
        "email",
        "learner_name",
        "graduation_status",
        "certification_status",
        "is_graduated",
        "is_certified"
    ]

    logger.info(f"Created dim_learner with {len(dim_learner)} records")
    return dim_learner


def create_dim_date():
    """Create date dimension table."""
    logger.info("Creating dim_date")

    date_range = pd.date_range(start=PROGRAM_START_DATE, end=PROGRAM_END_DATE, freq="D")

    dim_date = pd.DataFrame({"date": date_range})
    dim_date["date_key"] = dim_date["date"].dt.strftime("%Y%m%d").astype(int)
    dim_date["year"] = dim_date["date"].dt.year
    dim_date["month"] = dim_date["date"].dt.month
    dim_date["month_name"] = dim_date["date"].dt.month_name()
    dim_date["day"] = dim_date["date"].dt.day
    dim_date["day_name"] = dim_date["date"].dt.day_name()
    dim_date["day_of_week"] = dim_date["date"].dt.dayofweek
    dim_date["week_of_year"] = dim_date["date"].dt.isocalendar().week
    dim_date["is_weekend"] = dim_date["day_of_week"].isin([5, 6]).astype(int)

    # Reorder
    dim_date = dim_date[[
        "date_key",
        "date",
        "year",
        "month",
        "month_name",
        "day",
        "day_name",
        "day_of_week",
        "week_of_year",
        "is_weekend"
    ]]

    logger.info(f"Created dim_date with {len(dim_date)} records")
    return dim_date


def create_dim_week():
    """Create week dimension table."""
    logger.info("Creating dim_week")

    weeks = []
    start = pd.to_datetime(PROGRAM_START_DATE)

    for week_num in range(1, 11):
        week_start = start + pd.Timedelta(days=(week_num - 1) * 7)
        week_end = week_start + pd.Timedelta(days=4)

        weeks.append({
            "week_number": week_num,
            "week_start_date": week_start,
            "week_end_date": week_end,
            "week_label": f"Week {week_num}"
        })

    dim_week = pd.DataFrame(weeks)

    logger.info(f"Created dim_week with {len(dim_week)} records")
    return dim_week


def create_name_email_mapping(attendance_df):
    """Create mapping from learner names to emails."""
    mapping = dict(zip(
        attendance_df["learner_name"].apply(normalize_name),
        attendance_df["email"]
    ))
    logger.info(f"Created name-to-email mapping with {len(mapping)} entries")
    return mapping
