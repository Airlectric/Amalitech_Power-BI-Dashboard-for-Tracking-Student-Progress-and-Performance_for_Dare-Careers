// ============================================================
// DIM_DATE - Power Query M Code (Multi-Cohort Compatible)
// ============================================================
// This query creates a date dimension table dynamically based
// on the date range from fact_attendance and fact_participation.
// Works with both cohorts - dates are shared across tracks.
// 
// IMPORTANT: This query requires references to fact_attendance
// and fact_participation to determine the date range.
// Make sure to load those queries first.
// 
// Steps:
// 1. Get all dates from fact_attendance and fact_participation
// 2. Determine min and max dates (across all cohorts)
// 3. Generate continuous date range
// 4. Add date attributes (year, month, day, etc.)
// 5. Create date_key (YYYYMMDD format)
// ============================================================

let
    // ========================================
    // PART A: Determine Date Range from Fact Tables
    // ========================================
    // IMPORTANT: Requires fact_attendance and fact_participation to be loaded
    
    // Step 1: Get attendance dates
    AttendanceData = fact_attendance,
    AttendanceDates = Table.SelectColumns(AttendanceData, {"attendance_date"}),
    
    // Step 2: Get participation dates
    ParticipationData = fact_participation,
    ParticipationDates = Table.SelectColumns(ParticipationData, {"participation_date"}),
    RenamedParticipation = Table.RenameColumns(ParticipationDates, {{"participation_date", "attendance_date"}}),
    
    // Step 3: Combine all dates
    AllDates = Table.Combine({AttendanceDates, RenamedParticipation}),
    DistinctDates = Table.Distinct(AllDates),
    
    // Step 4: Get min and max dates
    MinDate = List.Min(DistinctDates[attendance_date]),
    MaxDate = List.Max(DistinctDates[attendance_date]),
    
    // ========================================
    // PART B: Generate Date Range
    // ========================================
    
    // Step 5: Generate list of dates from min to max
    DateList = List.Dates(MinDate, Duration.Days(MaxDate - MinDate) + 1, #duration(1, 0, 0, 0)),
    
    // Step 6: Convert to table
    DateTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"date"}, null, ExtraValues.Error),
    
    // Step 7: Ensure date type
    TypedDate = Table.TransformColumnTypes(DateTable, {{"date", type date}}),
    
    // ========================================
    // PART C: Add Date Attributes
    // ========================================
    
    // Step 8: Create date_key (YYYYMMDD integer format)
    AddDateKey = Table.AddColumn(TypedDate, "date_key", each 
        Date.Year([date]) * 10000 + Date.Month([date]) * 100 + Date.Day([date])
    , Int64.Type),
    
    // Step 9: Add year
    AddYear = Table.AddColumn(AddDateKey, "year", each Date.Year([date]), Int64.Type),
    
    // Step 10: Add month number
    AddMonth = Table.AddColumn(AddYear, "month", each Date.Month([date]), Int64.Type),
    
    // Step 11: Add month name
    AddMonthName = Table.AddColumn(AddMonth, "month_name", each Date.MonthName([date]), type text),
    
    // Step 12: Add day of month
    AddDay = Table.AddColumn(AddMonthName, "day", each Date.Day([date]), Int64.Type),
    
    // Step 13: Add day name
    AddDayName = Table.AddColumn(AddDay, "day_name", each Date.DayOfWeekName([date]), type text),
    
    // Step 14: Add day of week (0 = Monday, 6 = Sunday for consistency with Python)
    AddDayOfWeek = Table.AddColumn(AddDayName, "day_of_week", each 
        let
            // Power Query uses Sunday = 0, so we adjust to Monday = 0
            PQDayOfWeek = Date.DayOfWeek([date], Day.Monday)
        in
            PQDayOfWeek
    , Int64.Type),
    
    // Step 15: Add week of year (ISO week number)
    AddWeekOfYear = Table.AddColumn(AddDayOfWeek, "week_of_year", each Date.WeekOfYear([date]), Int64.Type),
    
    // Step 16: Add is_weekend flag (Saturday = 5, Sunday = 6 when Monday = 0)
    AddIsWeekend = Table.AddColumn(AddWeekOfYear, "is_weekend", each 
        if [day_of_week] >= 5 then 1 else 0
    , Int64.Type),
    
    // ========================================
    // PART D: Finalize
    // ========================================
    
    // Step 17: Reorder columns to final structure
    ReorderedColumns = Table.ReorderColumns(AddIsWeekend, {
        "date_key", "date", "year", "month", "month_name",
        "day", "day_name", "day_of_week", "week_of_year", "is_weekend"
    }),
    
    // Step 18: Set final column types
    FinalTypes = Table.TransformColumnTypes(ReorderedColumns, {
        {"date_key", Int64.Type},
        {"date", type date},
        {"year", Int64.Type},
        {"month", Int64.Type},
        {"month_name", type text},
        {"day", Int64.Type},
        {"day_name", type text},
        {"day_of_week", Int64.Type},
        {"week_of_year", Int64.Type},
        {"is_weekend", Int64.Type}
    })
in
    FinalTypes


// ============================================================
// ALTERNATIVE VERSION (Standalone with Fixed Date Range)
// ============================================================
// If you want to use this query without dependencies,
// use this version with a fixed date range:
// 
// let
//     // Define your date range (adjust as needed)
//     StartDate = #date(2024, 8, 5),
//     EndDate = #date(2024, 10, 11),
//     
//     DateList = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
//     DateTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"date"}, null, ExtraValues.Error),
//     TypedDate = Table.TransformColumnTypes(DateTable, {{"date", type date}}),
//     
//     AddDateKey = Table.AddColumn(TypedDate, "date_key", each 
//         Date.Year([date]) * 10000 + Date.Month([date]) * 100 + Date.Day([date])
//     , Int64.Type),
//     AddYear = Table.AddColumn(AddDateKey, "year", each Date.Year([date]), Int64.Type),
//     AddMonth = Table.AddColumn(AddYear, "month", each Date.Month([date]), Int64.Type),
//     AddMonthName = Table.AddColumn(AddMonth, "month_name", each Date.MonthName([date]), type text),
//     AddDay = Table.AddColumn(AddMonthName, "day", each Date.Day([date]), Int64.Type),
//     AddDayName = Table.AddColumn(AddDay, "day_name", each Date.DayOfWeekName([date]), type text),
//     AddDayOfWeek = Table.AddColumn(AddDayName, "day_of_week", each Date.DayOfWeek([date], Day.Monday), Int64.Type),
//     AddWeekOfYear = Table.AddColumn(AddDayOfWeek, "week_of_year", each Date.WeekOfYear([date]), Int64.Type),
//     AddIsWeekend = Table.AddColumn(AddWeekOfYear, "is_weekend", each 
//         if [day_of_week] >= 5 then 1 else 0
//     , Int64.Type),
//     ReorderedColumns = Table.ReorderColumns(AddIsWeekend, {
//         "date_key", "date", "year", "month", "month_name",
//         "day", "day_name", "day_of_week", "week_of_year", "is_weekend"
//     }),
//     FinalTypes = Table.TransformColumnTypes(ReorderedColumns, {
//         {"date_key", Int64.Type},
//         {"date", type date},
//         {"year", Int64.Type},
//         {"month", Int64.Type},
//         {"month_name", type text},
//         {"day", Int64.Type},
//         {"day_name", type text},
//         {"day_of_week", Int64.Type},
//         {"week_of_year", Int64.Type},
//         {"is_weekend", Int64.Type}
//     })
// in
//     FinalTypes
