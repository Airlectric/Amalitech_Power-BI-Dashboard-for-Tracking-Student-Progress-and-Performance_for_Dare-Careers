// ============================================================
// DIM_WEEK - Power Query M Code (Shared Across Tracks)
// ============================================================
// This query creates a week dimension table from fact_attendance,
// aggregating the start and end dates for each week ACROSS ALL TRACKS.
// 
// DESIGN DECISION: week_number must be UNIQUE for Power BI relationships.
// Week dates are the min/max across both cohorts for each week number.
// Track filtering is done via fact tables, not through DimWeek.
// 
// IMPORTANT: This query requires a reference to fact_attendance
// to determine week date ranges. Load fact_attendance first.
// 
// Steps:
// 1. Load fact_attendance
// 2. Group by week_number only to get min/max dates across all tracks
// 3. Create week_label
// ============================================================

let
    // ========================================
    // PART A: Load and Aggregate from Attendance
    // ========================================
    // IMPORTANT: Requires fact_attendance to be loaded
    
    // Step 1: Get fact_attendance data
    AttendanceData = fact_attendance,
    
    // Step 2: Select only needed columns (NO track - we want unique week_number)
    SelectColumns = Table.SelectColumns(AttendanceData, {"week_number", "attendance_date"}),
    
    // Step 3: Group by week_number ONLY to get min/max dates across ALL tracks
    GroupedByWeek = Table.Group(
        SelectColumns, 
        {"week_number"}, 
        {
            {"week_start_date", each List.Min([attendance_date]), type date},
            {"week_end_date", each List.Max([attendance_date]), type date}
        }
    ),
    
    // ========================================
    // PART B: Add Derived Columns
    // ========================================
    
    // Step 4: Sort by week number
    SortedByWeek = Table.Sort(GroupedByWeek, {{"week_number", Order.Ascending}}),
    
    // Step 5: Create week_label ("Week 1", "Week 2", etc.)
    AddWeekLabel = Table.AddColumn(SortedByWeek, "week_label", each 
        "Week " & Text.From([week_number])
    , type text),
    
    // ========================================
    // PART C: Finalize
    // ========================================
    
    // Step 6: Reorder columns to final structure
    ReorderedColumns = Table.ReorderColumns(AddWeekLabel, {
        "week_number", "week_start_date", "week_end_date", "week_label"
    }),
    
    // Step 7: Set final column types
    FinalTypes = Table.TransformColumnTypes(ReorderedColumns, {
        {"week_number", Int64.Type},
        {"week_start_date", type date},
        {"week_end_date", type date},
        {"week_label", type text}
    })
in
    FinalTypes


// ============================================================
// NOTE: Track-Specific Version (Not Recommended for Relationships)
// ============================================================
// If you need track-specific week date ranges for reporting purposes,
// you can create a SEPARATE table (not used for relationships):
// 
// GroupedByWeekAndTrack = Table.Group(
//     SelectColumns, 
//     {"week_number", "track"}, 
//     {
//         {"week_start_date", each List.Min([attendance_date]), type date},
//         {"week_end_date", each List.Max([attendance_date]), type date}
//     }
// )
// 
// But do NOT use this for relationships - it creates many-to-many issues.
//     FinalTypes = Table.TransformColumnTypes(ReorderedColumns, {
//         {"week_number", Int64.Type},
//         {"week_start_date", type date},
//         {"week_end_date", type date},
//         {"week_label", type text}
//     })
// in
//     FinalTypes
