// ============================================================
// FACT_PARTICIPATION - Power Query M Code (Multi-Cohort Version)
// ============================================================
// This query loads and transforms Participation records from
// BOTH cohorts: "AWSCloud Training" and "PowerBI Training"
// 
// Handles different filenames:
// - AWSCloud: participation.xlsx
// - PowerBI: Participation records.xlsx
// 
// IMPORTANT: This query requires a reference to fact_attendance
// to map learner names to email addresses. Make sure to load
// fact_attendance first, then create this query.
// 
// Steps:
// 1. Load all Participation Excel files from both cohorts
// 2. Extract Track name from folder path
// 3. Split comma-separated participants into rows
// 4. Parse participation date
// 5. Merge with fact_attendance to get email addresses
// 6. Add surrogate key (participation_id)
// ============================================================

let
    // ========================================
    // PART A: Find All Participation Excel Files
    // ========================================
    
    // Step 1: Get all files from the data folder
    // NOTE: Update this path to match your local folder location
    Source = Folder.Files("C:\Users\DanielAgudeyDoe\Desktop\Lib\Course Projects\DEM08-PowerBI\data"),
    
    // Step 2: Filter to Excel files in Participation folders
    FilteredExcel = Table.SelectRows(Source, each 
        ([Extension] = ".xlsx" or [Extension] = ".xls") and 
        Text.Contains([Folder Path], "Participation")
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
    ExpandedData = Table.ExpandTableColumn(PromoteHeaders, "SheetData", {"Date", "Participants"}, {"Date", "Participants"}),
    
    // Step 9: Filter out header rows and null values
    FilteredRows = Table.SelectRows(ExpandedData, each 
        [Participants] <> null and [Participants] <> "" and [Participants] <> "Participants"
    ),
    
    // Step 10: Split Participants column by comma into a list
    SplitToList = Table.TransformColumns(FilteredRows, {
        {"Participants", each Text.Split(_, ","), type list}
    }),
    
    // Step 11: Expand the list to individual rows
    ExpandedParticipants = Table.ExpandListColumn(SplitToList, "Participants"),
    
    // Step 12: Clean and trim participant names
    CleanedNames = Table.TransformColumns(ExpandedParticipants, {
        {"Participants", each Text.Trim(_), type text}
    }),
    
    // Step 13: Rename columns
    RenamedColumns = Table.RenameColumns(CleanedNames, {
        {"Participants", "learner_name"},
        {"Date", "date_raw"}
    }),
    
    // Step 14: Parse participation date from "dd-MMM-yyyy" format
    AddParticipationDate = Table.AddColumn(RenamedColumns, "participation_date", each 
        try Date.From(DateTime.FromText(Text.From([date_raw]), [Format="dd-MMM-yyyy"])) 
        otherwise try Date.From([date_raw]) otherwise null
    , type date),
    
    // Step 15: Remove raw date column
    RemoveRawDate = Table.RemoveColumns(AddParticipationDate, {"date_raw"}),
    
    // Step 16: Filter out any empty or null names
    FilteredNames = Table.SelectRows(RemoveRawDate, each 
        [learner_name] <> null and [learner_name] <> ""
    ),
    
    // ========================================
    // PART C: Merge with Attendance to Get Email
    // ========================================
    // IMPORTANT: This requires fact_attendance to be loaded first
    
    // Step 17: Get distinct name-to-email-to-track mapping from fact_attendance
    AttendanceData = fact_attendance,
    NameEmailMapping = Table.Distinct(
        Table.SelectColumns(AttendanceData, {"learner_name", "email", "track"})
    ),
    
    // Step 18: Merge to get email addresses (matching on both learner_name and track)
    MergedWithEmail = Table.NestedJoin(
        FilteredNames, {"learner_name", "track"},
        NameEmailMapping, {"learner_name", "track"},
        "EmailLookup",
        JoinKind.LeftOuter
    ),
    
    // Step 19: Expand email from the merged result
    ExpandedEmail = Table.ExpandTableColumn(MergedWithEmail, "EmailLookup", {"email"}, {"email"}),
    
    // Step 20: Filter out rows where email couldn't be mapped (unmatched learners)
    FilteredWithEmail = Table.SelectRows(ExpandedEmail, each [email] <> null),
    
    // ========================================
    // PART D: Finalize
    // ========================================
    
    // Step 21: Add participated flag (always 1 since they participated)
    AddParticipatedFlag = Table.AddColumn(FilteredWithEmail, "participated", each 1, Int64.Type),
    
    // Step 22: Add surrogate key (participation_id)
    AddIndex = Table.AddIndexColumn(AddParticipatedFlag, "participation_id", 1, 1, Int64.Type),
    
    // Step 23: Reorder columns to final structure
    ReorderedColumns = Table.ReorderColumns(AddIndex, {
        "participation_id", "email", "learner_name", "track", "participation_date", "participated"
    }),
    
    // Step 24: Set final column types
    FinalTypes = Table.TransformColumnTypes(ReorderedColumns, {
        {"participation_id", Int64.Type},
        {"email", type text},
        {"learner_name", type text},
        {"track", type text},
        {"participation_date", type date},
        {"participated", Int64.Type}
    })
in
    FinalTypes
