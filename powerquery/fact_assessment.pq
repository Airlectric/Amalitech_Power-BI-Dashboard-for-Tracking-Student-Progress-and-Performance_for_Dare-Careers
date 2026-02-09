// ============================================================
// FACT_ASSESSMENT - Power Query M Code (Multi-Cohort Version)
// ============================================================
// This query loads and transforms Labs and Quizzes data from
// BOTH cohorts: "AWSCloud Training" and "PowerBI Training"
// 
// Handles different filenames:
// - AWSCloud: labs_and_quizzes.xlsx
// - PowerBI: Labs & Quizes.xlsx
// 
// Steps:
// 1. Load all Excel files from Labs & Quizes folders
// 2. Extract Track name from folder path
// 3. Process Labs and Quizzes sheets
// 4. Unpivot week columns to rows
// 5. Combine all data
// 6. Add surrogate key (assessment_id)
// ============================================================

let
    // ========================================
    // PART A: Find All Labs & Quizzes Excel Files
    // ========================================
    
    // Step 1: Get all files from the data folder
    // NOTE: Update this path to match your local folder location
    Source = Folder.Files("C:\Users\DanielAgudeyDoe\Desktop\Lib\Course Projects\DEM08-PowerBI\data"),
    
    // Step 2: Filter to Excel files in Labs & Quizes folders
    FilteredExcel = Table.SelectRows(Source, each 
        ([Extension] = ".xlsx" or [Extension] = ".xls") and 
        Text.Contains([Folder Path], "Labs & Quizes")
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
    // PART B: Process Each Excel File
    // ========================================
    
    // Step 4: Load Excel workbooks
    AddWorkbook = Table.AddColumn(AddTrack, "Workbook", each 
        Excel.Workbook([Content], null, true)
    ),
    
    // Step 5: Expand workbook to get sheets
    ExpandedWorkbook = Table.ExpandTableColumn(AddWorkbook, "Workbook", {"Name", "Data"}, {"SheetName", "SheetData"}),
    
    // Step 6: Filter to only Labs and Quizzes sheets
    FilteredSheets = Table.SelectRows(ExpandedWorkbook, each 
        [SheetName] = "Labs" or [SheetName] = "Quizzes"
    ),
    
    // Step 7: Select needed columns
    SelectColumns = Table.SelectColumns(FilteredSheets, {"track", "SheetName", "SheetData"}),
    
    // Step 8: Promote headers in each sheet data
    PromoteHeaders = Table.TransformColumns(SelectColumns, {
        {"SheetData", each Table.PromoteHeaders(_, [PromoteAllScalars=true])}
    }),
    
    // Step 9: Unpivot the sheet data (week columns to rows)
    UnpivotData = Table.AddColumn(PromoteHeaders, "UnpivotedData", each 
        Table.UnpivotOtherColumns([SheetData], {"email"}, "Week", "Score")
    ),
    
    // Step 10: Add assessment type based on sheet name
    AddAssessmentType = Table.AddColumn(UnpivotData, "assessment_type", each 
        if [SheetName] = "Labs" then "Lab" else "Quiz"
    , type text),
    
    // Step 11: Expand the unpivoted data
    ExpandedData = Table.ExpandTableColumn(AddAssessmentType, "UnpivotedData", {"email", "Week", "Score"}, {"email", "Week", "Score"}),
    
    // Step 12: Select final columns
    SelectFinalColumns = Table.SelectColumns(ExpandedData, {"track", "assessment_type", "email", "Week", "Score"}),
    
    // ========================================
    // PART C: Clean and Finalize
    // ========================================
    
    // Step 13: Clean email (lowercase, trim)
    CleanEmail = Table.TransformColumns(SelectFinalColumns, {{"email", each Text.Lower(Text.Trim(_)), type text}}),
    
    // Step 14: Extract week number from "Week X" format
    AddWeekNumber = Table.AddColumn(CleanEmail, "week_number", each 
        let
            WeekText = [Week],
            NumericPart = Text.AfterDelimiter(WeekText, "Week "),
            WeekNum = try Number.FromText(Text.Trim(NumericPart)) otherwise null
        in
            WeekNum
    , Int64.Type),
    
    // Step 15: Rename Score column
    RenamedScore = Table.RenameColumns(AddWeekNumber, {{"Score", "score"}}),
    
    // Step 16: Remove original Week column (we have week_number now)
    RemoveWeekText = Table.RemoveColumns(RenamedScore, {"Week"}),
    
    // Step 17: Convert score to number type
    TypedScore = Table.TransformColumnTypes(RemoveWeekText, {{"score", type number}}),
    
    // Step 18: Filter out any null values
    FilteredData = Table.SelectRows(TypedScore, each [email] <> null and [week_number] <> null),
    
    // Step 19: Add surrogate key (assessment_id)
    AddIndex = Table.AddIndexColumn(FilteredData, "assessment_id", 1, 1, Int64.Type),
    
    // Step 20: Reorder columns to final structure
    ReorderedColumns = Table.ReorderColumns(AddIndex, {
        "assessment_id", "email", "week_number", "track", "assessment_type", "score"
    }),
    
    // Step 21: Set final column types
    FinalTypes = Table.TransformColumnTypes(ReorderedColumns, {
        {"assessment_id", Int64.Type},
        {"email", type text},
        {"week_number", Int64.Type},
        {"track", type text},
        {"assessment_type", type text},
        {"score", type number}
    })
in
    FinalTypes
