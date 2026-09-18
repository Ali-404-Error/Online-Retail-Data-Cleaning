let
    Source = Excel.CurrentWorkbook(){[Name="Table1"]}[Content],
    #"Changed To Text" = Table.TransformColumnTypes(Source,{{"StockCode", type text}, {"Description", type text}}),
    #"Uppercased StockCode" = Table.TransformColumns(#"Changed To Text",{{"StockCode", Text.Upper, type text}}),
    #"Trimmed StockCode" = Table.TransformColumns(#"Uppercased StockCode",{{"StockCode", Text.Trim, type text}}),
    #"Uppercased Description" = Table.TransformColumns(#"Trimmed StockCode",{{"Description", Text.Upper, type text}}),
    #"Trimmed Description" = Table.TransformColumns(#"Uppercased Description",{{"Description", Text.Trim, type text}}),
    #"Added IsOperationalNote" = Table.AddColumn(#"Trimmed Description", "IsOperationalNote", each let
    exactWords = {"CHECK"},
    containsWords = {"?", "AMAZON", "FOUND", "ADJUSTMENT", "WRONGLY", "DAMAGED", "RETURNED", "TEST", "MAILOUT", "PUT", "MARKED", "CODED", "SECTION"},
    hasExactMatch = if [Description] = null then false else List.AnyTrue(List.Transform(exactWords, (w) => [Description] = w)),
    hasContainsMatch = if [Description] = null then false else List.AnyTrue(List.Transform(containsWords, (w) => Text.Contains([Description], w)))
in
    ([CustomerID] = null and [UnitPrice] = 0 and [Quantity] < 0) or hasExactMatch or hasContainsMatch),
    #"Added HasBlankDescription" = Table.AddColumn(#"Added IsOperationalNote", "HasBlankDescription", each if [Description] = null then true else false),
    #"Filtered Rows" = Table.SelectRows(#"Added HasBlankDescription", each ([IsOperationalNote] = false) and ([HasBlankDescription] = false)),
    #"Grouped Rows" = Table.Group(#"Filtered Rows", {"StockCode", "Description"}, {{"Count", each Table.RowCount(_), Int64.Type}, {"MedianPrice", each List.Median([UnitPrice]), type number}}),
    #"Grouped Rows1" = Table.Group(#"Grouped Rows", {"StockCode"}, {{"NestedTable", each _, type table [StockCode=text, Description=text, Count=number]}}),
    #"Added DescCount" = Table.AddColumn(#"Grouped Rows1", "DescCount", each Table.RowCount([NestedTable])),
    #"Added TopDescription" = Table.AddColumn(#"Added DescCount", "TopDescription", each Table.Max([NestedTable] , "Count") [Description]),
    #"Added TopDescriptionCount" = Table.AddColumn(#"Added TopDescription", "TopDescriptionCount", each Table.Max([NestedTable], "Count") [Count]),
    #"Added TotalCount" = Table.AddColumn(#"Added TopDescriptionCount", "TotalCount", each List.Sum([NestedTable][Count])),
    #"Added Confidence" = Table.AddColumn(#"Added TotalCount", "Confidence", each [TopDescriptionCount]/[TotalCount]),
    #"Added TopDescriptionPrice" = Table.AddColumn(#"Added Confidence", "TopDescriptionPrice", each Table.Max([NestedTable] , "Count") [MedianPrice]),
    #"Added RunnerUpPrice" = Table.AddColumn(#"Added TopDescriptionPrice", "RunnerUpPrice", each let TopDesc = [TopDescription] in if[DescCount] > 1 then Table.Max(Table.SelectRows([NestedTable], each [Description] <> TopDesc), "Count") [MedianPrice] else null),
    #"Added PriceDivergence" = Table.AddColumn(#"Added RunnerUpPrice", "PriceDivergence", each if[RunnerUpPrice] = null then 0 else Number.Abs([TopDescriptionPrice] - [RunnerUpPrice]) / ((([TopDescriptionPrice] + [RunnerUpPrice])/2))),
    #"Changed To Percentage" = Table.TransformColumnTypes(#"Added PriceDivergence",{{"PriceDivergence", Percentage.Type}}),
    #"Added DescriptionStatus" = Table.AddColumn(#"Changed To Percentage", "DescriptionStatus", each if [Confidence] < 0.9 then "Manual Review" else "Auto Accept"),
    #"Added PriceVarianceFlag" = Table.AddColumn(#"Added DescriptionStatus", "PriceVarianceFlag", each if[PriceDivergence] = null then false else [PriceDivergence] > 0.5)
in
    #"Added PriceVarianceFlag"