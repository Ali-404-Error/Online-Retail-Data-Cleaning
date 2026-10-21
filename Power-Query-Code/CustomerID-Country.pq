let
    Source = FinalCleanedData,
    #"Added Conditional Column" = Table.AddColumn(Source, "BlankCounts", each if [CustomerID] = null then 1 else 0),
    #"Grouped Rows" = Table.Group(#"Added Conditional Column", {"Country"}, {{"Lines", each Table.RowCount(_), Int64.Type}, {"BlankLines", each List.Sum([BlankCounts]), type number}}),
    #"Added Custom" = Table.AddColumn(#"Grouped Rows", "BlankShare", each [BlankLines] / [Lines]),
    #"Sorted Rows" = Table.Sort(#"Added Custom",{{"Lines", Order.Descending}})
in
    #"Sorted Rows"