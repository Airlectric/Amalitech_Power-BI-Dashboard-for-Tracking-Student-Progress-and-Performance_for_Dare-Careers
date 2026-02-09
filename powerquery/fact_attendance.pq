// ============================================================
// FACT_ATTENDANCE - Power Query M Code (Multi-Cohort Version)
// ============================================================
// This query loads and transforms Zoom attendance CSVs from
// BOTH cohorts: "AWSCloud Training" and "PowerBI Training"
// 
// Key Features:
// - Handles both duration formats (plain minutes & H:MM:SS)
// - Extracts track/cohort name from folder path
// - Combines data from all cohorts into single fact table
// 
// Steps:
// 1. Load all CSV files from data folder recursively
// 2. Extract Track name from folder path
// 3. Extract Week Number from folder path
// 4. Extract Attendance Date from filename
// 5. Parse Duration (handles both formats)
// 6. Calculate derived fields (is_attended, duration_hours)
// 7. Add surrogate key (attendance_id)
// ============================================================

let
    // Step 1: Get all files from the main data folder (contains both cohorts)
    // NOTE: Update this path to match your local folder location
    Source = Folder.Files("C:\Users\DanielAgudeyDoe\Desktop\Lib\Course Projects\DEM08-PowerBI\data"),
    
    // Step 2: Filter to only CSV files in Zoom Attendance folders
    FilteredCSV = Table.SelectRows(Source, each 
        [Extension] = ".csv" and Text.Contains([Folder Path], "Zoom Attendance")
    ),
    
    // Step 3: Extract Track/Cohort name from folder path
    AddTrack = Table.AddColumn(FilteredCSV, "track", each 
        let
            FolderPath = [Folder Path],
            // Extract the cohort folder name (e.g., "AWSCloud Training" or "PowerBI Training")
            AfterData = Text.AfterDelimiter(FolderPath, "data\"),
            TrackName = Text.BeforeDelimiter(AfterData, "\"),
            // Clean up the track name (remove " Training" suffix for cleaner display)
            CleanTrack = Text.Replace(TrackName, " Training", "")
        in
            CleanTrack
    , type text),
    
    // Step 4: Add custom column to extract Week Number from folder path
    AddWeekNumber = Table.AddColumn(AddTrack, "week_number", each 
        let
            FolderPath = [Folder Path],
            WeekMatch = Text.BetweenDelimiters(FolderPath, "Week ", "\"),
            WeekNum = if WeekMatch = "" or WeekMatch = null then 
                try Number.FromText(Text.BeforeDelimiter(Text.AfterDelimiter(FolderPath, "Week "), "\")) otherwise null
            else 
                try Number.FromText(WeekMatch) otherwise null
        in
            WeekNum
    , Int64.Type),
    
    // Step 5: Add custom column to extract Attendance Date from filename
    AddAttendanceDate = Table.AddColumn(AddWeekNumber, "attendance_date", each 
        let
            FileName = Text.Replace([Name], ".csv", ""),
            ParsedDate = try Date.From(DateTime.FromText(FileName, [Format="dd-MMM-yyyy"])) otherwise null
        in
            ParsedDate
    , type date),
    
    // Step 6: Load CSV content from each file
    AddContent = Table.AddColumn(AddAttendanceDate, "CSVData", each 
        Csv.Document([Content], [Delimiter=",", Columns=6, Encoding=65001, QuoteStyle=QuoteStyle.None])
    ),
    
    // Step 7: Expand the CSV data
    ExpandedData = Table.ExpandTableColumn(AddContent, "CSVData", 
        {"Column1", "Column2", "Column3", "Column4", "Column5", "Column6"}, 
        {"Name_Raw", "Email_Raw", "JoinTime_Raw", "LeaveTime_Raw", "Duration_Raw", "Role_Raw"}
    ),
    
    // Step 8: Keep only needed columns
    SelectColumns = Table.SelectColumns(ExpandedData, 
        {"track", "week_number", "attendance_date", "Name_Raw", "Email_Raw", "JoinTime_Raw", "LeaveTime_Raw", "Duration_Raw"}
    ),
    
    // Step 9: Filter out header rows and empty rows
    FilterHeaders = Table.SelectRows(SelectColumns, each 
        [Name_Raw] <> "Name" and [Name_Raw] <> null and [Name_Raw] <> ""
    ),
    
    // Step 10: Clean and transform columns
    CleanEmail = Table.TransformColumns(FilterHeaders, {{"Email_Raw", each Text.Lower(Text.Trim(_)), type text}}),
    CleanName = Table.TransformColumns(CleanEmail, {{"Name_Raw", each Text.Trim(_), type text}}),
    
    // Step 11: Rename columns to final names
    RenamedColumns = Table.RenameColumns(CleanName, {
        {"Email_Raw", "email"},
        {"Name_Raw", "learner_name"},
        {"JoinTime_Raw", "join_time"},
        {"LeaveTime_Raw", "leave_time"},
        {"Duration_Raw", "duration_raw"}
    }),
    
    // Step 12: Parse Duration - HANDLES BOTH FORMATS:
    // - Plain number (minutes): "66" - used by AWSCloud
    // - H:MM:SS format: "1:46:00" - used by PowerBI
    AddDurationMinutes = Table.AddColumn(RenamedColumns, "duration_minutes", each 
        let
            DurationText = Text.Trim([duration_raw]),
            // Check if it contains colons (H:MM:SS format)
            HasColons = Text.Contains(DurationText, ":"),
            TotalMinutes = if HasColons then
                // Parse H:MM:SS format
                let
                    Parts = Text.Split(DurationText, ":"),
                    PartCount = List.Count(Parts),
                    Hours = if PartCount >= 1 then try Number.FromText(Parts{0}) otherwise 0 else 0,
                    Minutes = if PartCount >= 2 then try Number.FromText(Parts{1}) otherwise 0 else 0,
                    Seconds = if PartCount >= 3 then try Number.FromText(Parts{2}) otherwise 0 else 0
                in
                    Hours * 60 + Minutes + Seconds / 60
            else
                // Plain number (already in minutes)
                try Number.FromText(DurationText) otherwise 0
        in
            TotalMinutes
    , type number),
    
    // Step 13: Calculate duration in hours
    AddDurationHours = Table.AddColumn(AddDurationMinutes, "duration_hours", each [duration_minutes] / 60, type number),
    
    // Step 14: Calculate is_attended flag (threshold: 30 minutes)
    // A learner is considered "attended" if they were present for more than 30 minutes
    AttendanceThreshold = 30,
    AddIsAttended = Table.AddColumn(AddDurationHours, "is_attended", each 
        if [duration_minutes] > AttendanceThreshold then 1 else 0
    , Int64.Type),
    
    // Step 15: Remove the raw duration column
    RemoveRawDuration = Table.RemoveColumns(AddIsAttended, {"duration_raw"}),
    
    // Step 16: Add surrogate key (attendance_id)
    AddIndex = Table.AddIndexColumn(RemoveRawDuration, "attendance_id", 1, 1, Int64.Type),
    
    // Step 17: Reorder columns to final structure
    ReorderedColumns = Table.ReorderColumns(AddIndex, {
        "attendance_id", "email", "learner_name", "attendance_date",
        "week_number", "track", "join_time", "leave_time", "duration_minutes",
        "duration_hours", "is_attended"
    }),
    
    // Step 18: Set final column types
    FinalTypes = Table.TransformColumnTypes(ReorderedColumns, {
        {"attendance_id", Int64.Type},
        {"email", type text},
        {"learner_name", type text},
        {"attendance_date", type date},
        {"week_number", Int64.Type},
        {"track", type text},
        {"join_time", type text},
        {"leave_time", type text},
        {"duration_minutes", type number},
        {"duration_hours", type number},
        {"is_attended", Int64.Type}
    })
in
    FinalTypes
