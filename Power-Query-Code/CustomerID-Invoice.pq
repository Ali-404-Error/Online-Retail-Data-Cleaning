let
    Source = FinalCleanedData,
    #"Added Conditional Column" = Table.AddColumn(Source, "BlankCounts", each if [CustomerID] = null then 1 else 0),
    #"Grouped Rows" = Table.Group(#"Added Conditional Column", {"InvoiceNo"}, {{"Lines", each Table.RowCount(_), Int64.Type}, {"BlankLines", each List.Sum([BlankCounts]), type number}}),
    #"Filtered Rows" = Table.SelectRows(#"Grouped Rows", each [BlankLines] > 0),
    #"Added Custom" = Table.AddColumn(#"Filtered Rows", "IsPartial", each if [BlankLines] < [Lines] then true else false)
in
    #"Added Custom"