# Data Careers Power BI Project

## Overview
This project analyzes learner engagement, assessment, and progression data for a Data Careers training program using Power BI. The process involves cleaning, combining, and modeling multiple datasets to enable insightful reporting and analytics.

---

## Data Preparation & Cleaning

### 1. **Raw Data Sources**
- **Zoom Attendance**: Multiple CSV files (by week and date) containing attendance logs.
- **Labs & Quizzes**: Excel file with separate sheets for lab and quiz scores.
- **Participation**: Excel file with daily participation records.
- **Status of Learners**: Excel file with learner status (graduation, certification, etc).

### 2. **Cleaning & Transformation Steps**
- **Attendance Data**:
  - All Zoom CSVs are loaded and combined into a single table.
  - Duration fields are parsed and converted to minutes/hours.
  - Attendance is flagged based on a minimum duration threshold (e.g., 30 minutes).
  - Dates and week numbers are extracted from filenames and folder paths.
  - Each record is assigned a unique attendance ID.

- **Assessment Data**:
  - Labs and quizzes are loaded from their respective Excel sheets.
  - Data is reshaped (melted) to create a unified assessment table with week, type (Lab/Quiz), and score.
  - Emails are standardized (lowercase, trimmed).
  - Each record is assigned a unique assessment ID.

- **Participation Data**:
  - Participation records are split and exploded so each learner/date is a separate row.
  - Learner names are mapped to emails using attendance data.
  - Dates are standardized and each record is assigned a unique participation ID.

- **Status Data**:
  - Learner status is loaded and emails are standardized.
  - Learner names and enrollment dates are derived from attendance data.
  - Cohort and track fields are created.
  - Graduation and certification flags are set, and a current status is derived.

### 3. **Dimension & Fact Table Creation**
- **Fact Tables**:
  - `fact_attendance`: Cleaned attendance records.
  - `fact_assessment`: Unified labs/quizzes scores.
  - `fact_participation`: Cleaned participation records.
- **Dimension Tables**:
  - `dim_learner`: Learner profile and status.
  - `dim_date`: Calendar table covering all relevant dates.
  - `dim_week`: Week metadata (start/end dates, labels).

---

## Power BI Data Modeling

1. **Import Cleaned Data**
   - The cleaned CSVs (from the ETL process) are imported into Power BI as tables.

2. **Relationships**
   - Relationships are created between fact and dimension tables:
     - `fact_attendance.email` → `dim_learner.email`
     - `fact_assessment.email` → `dim_learner.email`
     - `fact_participation.email` → `dim_learner.email`
     - Date fields in facts link to `dim_date.date`
     - Week numbers in facts link to `dim_week.week_number`

3. **Data Types & Formatting**
   - Ensure all date, numeric, and categorical fields are correctly typed.
   - Hide surrogate keys and technical columns from report view.

4. **Calculated Columns & Measures**
   - Create DAX measures for attendance rates, average scores, participation rates, etc.
   - Add calculated columns for cohort analysis, status breakdowns, and time intelligence as needed.

5. **Star Schema**
   - The model follows a star schema: fact tables at the center, dimension tables as lookup/reference.

6. **Report Building**
   - Use the model to build dashboards and reports for tracking learner engagement, assessment performance, and progression.

---

## Notes
All data cleaning, transformation, and output steps were performed prior to import into Power BI.
Power BI is used only for modeling, relationships, DAX, and visualization—no Power Query M code is included here.

---

For further details, see the Power BI file in this repository.