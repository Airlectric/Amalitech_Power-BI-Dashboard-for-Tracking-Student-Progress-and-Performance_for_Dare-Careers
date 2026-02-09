// ============================================================
// DIM_LEARNER - Power Query M Code (Multi-Cohort Version)
// ============================================================
// This query creates a learner dimension table from Status files
// in BOTH cohorts: "AWSCloud Training" and "PowerBI Training"
// 
// Handles different filenames:
// - AWSCloud: participant_status.xlsx
// - PowerBI: Status of Participanat.xlsx (note typo)
// 
// IMPORTANT: This query requires a reference to fact_attendance
// to derive learner names, enrollment dates, and track info.
// Make sure to load fact_attendance first, then create this query.
// 
// Steps:
// 1. Load all Status Excel files from both cohorts
// 2. Extract Track name from folder path
// 3. Merge with fact_attendance for names & dates
// 4. Derive cohort from enrollment date
// 5. Create binary flags (is_graduated, is_certified)
// 6. Derive current_status
// 7. Add surrogate key (learner_id)
// ============================================================

let
    // ========================================
    // PART A: Find All Status Excel Files
    // ========================================
    
    // Step 1: Get all files from the data folder
    // NOTE: Update this path to match your local folder location
    Source = Folder.Files("C:\Users\DanielAgudeyDoe\Desktop\Lib\Course Projects\DEM08-PowerBI\data"),
    
    // Step 2: Filter to Excel files in Status of Learners folders
    FilteredExcel = Table.SelectRows(Source, each 
        ([Extension] = ".xlsx" or [Extension] = ".xls") and 
        Text.Contains([Folder Path], "Status of Learners")
    ),
    
    // Step 3: Extract Track/Cohort name from folder path
    AddTrack = Table.AddColumn(FilteredExcel, "track", each 
        let
            FolderPath = [Folder Path],
            AfterData = Text.AfterDelimiter(FolderPath, "data\"),
            TrackName = Text.BeforeDelimiter(AfterData, "\"),
            CleanTrack = Text.Replace(TrackName, " Training", "")
        in
            CleanTrack
    , type text),
    
    // ========================================
    // PART B: Load and Process Each File
    // ========================================
    
    // Step 4: Load Excel workbooks
    AddWorkbook = Table.AddColumn(AddTrack, "Workbook", each 
        Excel.Workbook([Content], null, true)
    ),
    
    // Step 5: Expand workbook to get sheets (take first sheet)
    ExpandedWorkbook = Table.ExpandTableColumn(AddWorkbook, "Workbook", {"Data"}, {"SheetData"}),
    
    // Step 6: Select needed columns
    SelectColumns = Table.SelectColumns(ExpandedWorkbook, {"track", "SheetData"}),
    
    // Step 7: Promote headers in each sheet data
    PromoteHeaders = Table.TransformColumns(SelectColumns, {
        {"SheetData", each Table.PromoteHeaders(_, [PromoteAllScalars=true])}
    }),
    
    // Step 8: Expand sheet data
    ExpandedData = Table.ExpandTableColumn(PromoteHeaders, "SheetData", 
        {"email", "Graduation Status", "Certification Status"}, 
        {"email", "Graduation Status", "Certification Status"}
    ),
    
    // Step 9: Filter out header rows and null values
    FilteredRows = Table.SelectRows(ExpandedData, each 
        [email] <> null and [email] <> "" and [email] <> "email"
    ),
    
    // Step 10: Clean email (lowercase, trim)
    CleanEmail = Table.TransformColumns(FilteredRows, {
        {"email", each Text.Lower(Text.Trim(_)), type text}
    }),
    
    // ========================================
    // PART C: Merge with Attendance for Derived Fields
    // ========================================
    // IMPORTANT: This requires fact_attendance to be loaded first
    
    // Step 11: Get name and first attendance date from fact_attendance
    AttendanceData = fact_attendance,
    
    // Step 12: Get distinct email -> learner_name mapping (per track)
    NameMapping = Table.Distinct(
        Table.SelectColumns(AttendanceData, {"email", "learner_name", "track"})
    ),
    
    // Step 13: Get first attendance date per learner per track (enrollment date)
    GroupedAttendance = Table.Group(
        AttendanceData, 
        {"email", "track"}, 
        {{"enrollment_date", each List.Min([attendance_date]), type date}}
    ),
    
    // Step 14: Merge learner name (matching on email and track)
    MergedWithName = Table.NestedJoin(
        CleanEmail, {"email", "track"},
        NameMapping, {"email", "track"},
        "NameLookup",
        JoinKind.LeftOuter
    ),
    ExpandedName = Table.ExpandTableColumn(MergedWithName, "NameLookup", {"learner_name"}, {"learner_name"}),
    
    // Step 15: Merge enrollment date
    MergedWithEnrollment = Table.NestedJoin(
        ExpandedName, {"email", "track"},
        GroupedAttendance, {"email", "track"},
        "EnrollmentLookup",
        JoinKind.LeftOuter
    ),
    ExpandedEnrollment = Table.ExpandTableColumn(MergedWithEnrollment, "EnrollmentLookup", {"enrollment_date"}, {"enrollment_date"}),
    
    // ========================================
    // PART D: Create Derived Fields
    // ========================================
    
    // Step 16: Derive cohort from enrollment month-year (e.g., "Aug-2024")
    AddCohort = Table.AddColumn(ExpandedEnrollment, "cohort", each 
        if [enrollment_date] = null then null
        else Date.ToText([enrollment_date], "MMM-yyyy")
    , type text),
    
    // Step 17: Rename status columns to lowercase
    RenamedColumns = Table.RenameColumns(AddCohort, {
        {"Graduation Status", "graduation_status"},
        {"Certification Status", "certification_status"}
    }),
    
    // Step 18: Create is_graduated binary flag
    AddIsGraduated = Table.AddColumn(RenamedColumns, "is_graduated", each 
        if [graduation_status] = "Graduate" then 1 else 0
    , Int64.Type),
    
    // Step 19: Create is_certified binary flag
    AddIsCertified = Table.AddColumn(AddIsGraduated, "is_certified", each 
        if [certification_status] = "Certified" then 1 else 0
    , Int64.Type),
    
    // Step 20: Derive current_status based on graduation and certification
    AddCurrentStatus = Table.AddColumn(AddIsCertified, "current_status", each 
        if [is_graduated] = 1 and [is_certified] = 1 then "Certified Graduate"
        else if [is_graduated] = 1 and [is_certified] = 0 then "Graduate"
        else if [is_graduated] = 0 then "In Progress"
        else "Unknown"
    , type text),
    
    // ========================================
    // PART E: Finalize
    // ========================================
    
    // Step 21: Add surrogate key (learner_id)
    AddIndex = Table.AddIndexColumn(AddCurrentStatus, "learner_id", 1, 1, Int64.Type),
    
    // Step 22: Reorder columns to final structure
    ReorderedColumns = Table.ReorderColumns(AddIndex, {
        "learner_id", "email", "learner_name", "cohort", "track",
        "enrollment_date", "graduation_status", "certification_status",
        "current_status", "is_graduated", "is_certified"
    }),
    
    // Step 23: Set final column types
    FinalTypes = Table.TransformColumnTypes(ReorderedColumns, {
        {"learner_id", Int64.Type},
        {"email", type text},
        {"learner_name", type text},
        {"cohort", type text},
        {"track", type text},
        {"enrollment_date", type date},
        {"graduation_status", type text},
        {"certification_status", type text},
        {"current_status", type text},
        {"is_graduated", Int64.Type},
        {"is_certified", Int64.Type}
    })
in
    FinalTypes
//         else "Unknown"
//     , type text),
//     AddIndex = Table.AddIndexColumn(AddCurrentStatus, "learner_id", 1, 1, Int64.Type),
//     ReorderedColumns = Table.ReorderColumns(AddIndex, {
//         "learner_id", "email", "track", "graduation_status", "certification_status",
//         "current_status", "is_graduated", "is_certified"
//     }),
//     FinalTypes = Table.TransformColumnTypes(ReorderedColumns, {
//         {"learner_id", Int64.Type},
//         {"email", type text},
//         {"track", type text},
//         {"graduation_status", type text},
//         {"certification_status", type text},
//         {"current_status", type text},
//         {"is_graduated", Int64.Type},
//         {"is_certified", Int64.Type}
//     })
// in
//     FinalTypes
