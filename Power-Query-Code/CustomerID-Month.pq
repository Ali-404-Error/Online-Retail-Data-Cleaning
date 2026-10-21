let
    Source = FinalCleanedData,
    #"Added Conditional Column" = Table.AddColumn(Source, "BlankCounts", each if [CustomerID] = null then 1 else 0),
    #"Inserted Start of Month" = Table.AddColumn(#"Added Conditional Column", "Start of Month", each Date.StartOfMonth([InvoiceDate]), type datetime),
    #"Grouped Rows" = Table.Group(#"Inserted Start of Month", {"Start of Month"}, {{"Lines", each Table.RowCount(_), Int64.Type}, {"BlankLines", each List.Sum([BlankCounts]), type number}}),
    #"Added Custom" = Table.AddColumn(#"Grouped Rows", "BlankShare", each [BlankLines] / [Lines]),
    #"Sorted Rows" = Table.Sort(#"Added Custom",{{"Start of Month", Order.Ascending}})
in
    #"Sorted Rows"