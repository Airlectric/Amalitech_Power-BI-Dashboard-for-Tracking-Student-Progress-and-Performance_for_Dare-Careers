# Power Query M Code for Data Cleaning & Transformation (Multi-Cohort)

This folder contains M code files (`.pq`) that can be used in Power BI's Power Query Advanced Editor to perform data cleaning and transformation. These queries handle **multiple cohorts/tracks** (AWSCloud and PowerBI Training) and combine them into unified fact and dimension tables.

## Data Structure

The queries expect this folder structure:
```
data/
├── AWSCloud Training/
│   ├── Labs & Quizes/
│   │   └── labs_and_quizzes.xlsx
│   ├── Participation/
│   │   └── participation.xlsx
│   ├── Status of Learners/
│   │   └── participant_status.xlsx
│   └── Zoom Attendance/
│       ├── Week 1/
│       ├── Week 2/
│       └── ...
└── PowerBI Training/
    ├── Labs & Quizes/
    │   └── Labs & Quizes.xlsx
    ├── Participation/
    │   └── Participation records.xlsx
    ├── Status of Learners/
    │   └── Status of Participanat.xlsx
    └── Zoom Attendance/
        ├── Week 1/
        ├── Week 2/
        └── ...
```

## Files Overview

| File | Description | Dependencies |
|------|-------------|--------------|
| `fact_attendance.pq` | Combines Zoom attendance from ALL cohorts, handles both duration formats | None (load first) |
| `fact_assessment.pq` | Unpivots Labs/Quizzes from ALL cohorts into normalized records | None |
| `fact_participation.pq` | Explodes participant names from ALL cohorts | Requires `fact_attendance` |
| `dim_learner.pq` | Creates learner dimension from ALL cohorts with derived fields | Requires `fact_attendance` |
| `dim_date.pq` | Generates shared date dimension with calendar attributes | Requires `fact_attendance`, `fact_participation` |
| `dim_week.pq` | Creates shared week dimension (unique week_number for 1:* relationships) | Requires `fact_attendance` |

## Loading Order (Important!)

Due to dependencies between queries, load them in this order:

1. **fact_attendance** - Load first (no dependencies)
2. **fact_assessment** - Load second (no dependencies)
3. **fact_participation** - Load third (needs fact_attendance)
4. **dim_learner** - Load fourth (needs fact_attendance)
5. **dim_date** - Load fifth (needs fact_attendance, fact_participation)
6. **dim_week** - Load last (needs fact_attendance)

## How to Use in Power BI

### Method 1: Copy-Paste into Advanced Editor

1. Open Power BI Desktop
2. Go to **Home** → **Transform data** (Power Query Editor)
3. Click **New Source** → **Blank Query**
4. Right-click the new query → **Advanced Editor**
5. Delete all existing code
6. Copy the entire content from the `.pq` file
7. Paste into the Advanced Editor
8. Click **Done**
9. Rename the query to match the filename (e.g., `fact_attendance`)

### Method 2: Create Query from File

1. Open Power BI Desktop
2. Go to **Home** → **Transform data**
3. Click **New Source** → **More...** → **Other** → **Blank Query**
4. In the formula bar, type:
   ```
   = Text.FromBinary(File.Contents("C:\path\to\powerquery\fact_attendance.pq"))
   ```
5. This loads the M code as text - you'll need to copy it to a new query's Advanced Editor

## Configuration Required

**Update File Paths**: Before using each query, update the file paths to match your local folder structure:

```m
// Change this line in each query:
Folder.Files("C:\Users\DanielAgudeyDoe\Desktop\Lib\Course Projects\DEM08-PowerBI\data")

// To your actual path:
Folder.Files("C:\YourPath\DEM08-PowerBI\data")
```

## Key Features (Multi-Cohort Support)

### Automatic Track Detection
- Extracts track/cohort name from folder path (e.g., "AWSCloud", "PowerBI")
- All tables include a `track` column for filtering and analysis

### Flexible Duration Parsing
- **AWSCloud format**: Plain minutes (`66`)
- **PowerBI format**: H:MM:SS (`1:46:00`)
- Automatically detects and parses both formats

### Dynamic File Discovery
- Uses `Folder.Files()` to recursively find all relevant files
- Handles different filenames across cohorts automatically

## Transformation Steps by Query

### fact_attendance
- Loads all CSVs from `Zoom Attendance` folders in BOTH cohorts
- Extracts **track name** from parent folder
- Extracts week number from folder path (`Week 1`, `Week 2`, etc.)
- Extracts attendance date from filename (`05-Aug-2024.csv`)
- **Handles both duration formats** (plain minutes AND H:MM:SS)
- Calculates `duration_hours` and `is_attended` flag (threshold: 30 min)
- Adds surrogate key `attendance_id`

### fact_assessment
- Finds all Labs/Quizzes Excel files in BOTH cohorts
- Extracts **track name** from folder path
- Loads Labs and Quizzes sheets from each file
- Unpivots week columns (Week 1-10) to rows
- Adds `assessment_type` column (Lab/Quiz)
- Extracts numeric week number
- Adds surrogate key `assessment_id`

### fact_participation
- Finds all Participation Excel files in BOTH cohorts
- Extracts **track name** from folder path
- Splits comma-separated participant names into individual rows
- Parses date from `dd-MMM-yyyy` format
- Merges with fact_attendance to get email addresses (matching on name AND track)
- Adds `participated` flag and surrogate key

### dim_learner
- Finds all Status Excel files in BOTH cohorts
- Extracts **track name** from folder path
- Merges with fact_attendance for names and enrollment dates (per track)
- Derives `cohort` from enrollment month-year
- Creates binary flags: `is_graduated`, `is_certified`
- Derives `current_status` (Certified Graduate/Graduate/In Progress)
- Adds surrogate key `learner_id`

### dim_date
- Extracts all dates from fact_attendance and fact_participation (all cohorts)
- Generates continuous date range from min to max
- Adds calendar attributes: year, month, day, day_name, etc.
- Creates `date_key` in YYYYMMDD format
- Adds `is_weekend` flag
- **Shared across all tracks** (dates are not track-specific)

### dim_week
- Groups fact_attendance by week_number ONLY (across all tracks)
- Calculates week start and end dates **across all tracks combined**
- Creates `week_label` (Week 1, Week 2, etc.)
- **Shared across all tracks** to ensure unique week_number for 1:* relationships

## Expected Schema

### fact_attendance
| Column | Type | Description |
|--------|------|-------------|
| attendance_id | Int64 | Surrogate key |
| email | Text | Learner email (lowercase) |
| learner_name | Text | Learner full name |
| attendance_date | Date | Date of attendance |
| week_number | Int64 | Week number (1-10) |
| **track** | **Text** | **Track/cohort name (AWSCloud, PowerBI)** |
| join_time | Text | Join time |
| leave_time | Text | Leave time |
| duration_minutes | Number | Duration in minutes |
| duration_hours | Number | Duration in hours |
| is_attended | Int64 | 1 if attended (>30 min), 0 otherwise |

### fact_assessment
| Column | Type | Description |
|--------|------|-------------|
| assessment_id | Int64 | Surrogate key |
| email | Text | Learner email (lowercase) |
| week_number | Int64 | Week number (1-10) |
| **track** | **Text** | **Track/cohort name** |
| assessment_type | Text | "Lab" or "Quiz" |
| score | Number | Assessment score |

### fact_participation
| Column | Type | Description |
|--------|------|-------------|
| participation_id | Int64 | Surrogate key |
| email | Text | Learner email |
| learner_name | Text | Learner full name |
| **track** | **Text** | **Track/cohort name** |
| participation_date | Date | Date of participation |
| participated | Int64 | Always 1 |

### dim_learner
| Column | Type | Description |
|--------|------|-------------|
| learner_id | Int64 | Surrogate key |
| email | Text | Learner email (lowercase) |
| learner_name | Text | Learner full name |
| cohort | Text | Enrollment month-year (e.g., "Aug-2024") |
| **track** | **Text** | **Track/cohort name (AWSCloud, PowerBI)** |
| enrollment_date | Date | First attendance date |
| graduation_status | Text | "Graduate" or "Non Graduate" |
| certification_status | Text | "Certified" or "Not Certified" |
| current_status | Text | Derived status |
| is_graduated | Int64 | Binary flag |
| is_certified | Int64 | Binary flag |

### dim_date
| Column | Type | Description |
|--------|------|-------------|
| date_key | Int64 | YYYYMMDD format key |
| date | Date | Actual date |
| year | Int64 | Year |
| month | Int64 | Month number |
| month_name | Text | Month name |
| day | Int64 | Day of month |
| day_name | Text | Day name |
| day_of_week | Int64 | 0=Monday, 6=Sunday |
| week_of_year | Int64 | ISO week number |
| is_weekend | Int64 | 1 if Saturday/Sunday |

### dim_week
| Column | Type | Description |
|--------|------|-------------|
| week_number | Int64 | Week number (1-10) - **Primary Key (unique)** |
| week_start_date | Date | First day of week (min across all tracks) |
| week_end_date | Date | Last day of week (max across all tracks) |
| week_label | Text | "Week 1", "Week 2", etc. |

**Note:** dim_week has NO track column to ensure week_number is unique for 1:* relationships with fact tables.

## Troubleshooting

### "Query references another query that doesn't exist"
- Make sure to load queries in the correct order (dependencies first)
- Verify query names match exactly: `fact_attendance`, `fact_participation`, etc.

### "File not found" error
- Update the file paths in the M code to match your local folder structure

### Date parsing errors
- Ensure your date format matches the expected format (dd-MMM-yyyy for dates like "05-Aug-2024")
- Check regional settings if dates are not parsing correctly
