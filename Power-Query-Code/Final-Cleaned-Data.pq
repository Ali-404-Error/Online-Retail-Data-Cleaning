let
    Source = Table1,
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"StockCode", type text}, {"Description", type text}, {"InvoiceDate", type datetime}}),
    #"Uppercased Text" = Table.TransformColumns(#"Changed Type",{{"StockCode", Text.Upper, type text}}),
    #"Trimmed Text" = Table.TransformColumns(#"Uppercased Text",{{"StockCode", Text.Trim, type text}}),
    #"Uppercased Text1" = Table.TransformColumns(#"Trimmed Text",{{"Description", Text.Upper, type text}}),
    #"Trimmed Text1" = Table.TransformColumns(#"Uppercased Text1",{{"Description", Text.Trim, type text}}),
    #"Added HasBlankDescription" = Table.AddColumn(#"Trimmed Text1", "HasBlankDescription", each if [Description] = null then true else false),
    #"Added IsOperationalNote" = Table.AddColumn(#"Added HasBlankDescription", "IsOperationalNote", each let
    exactWords = {"CHECK"},
    containsWords = {"?", "AMAZON", "FOUND", "ADJUSTMENT", "WRONGLY", "DAMAGED", "RETURNED", "TEST", "MAILOUT", "PUT", "MARKED", "CODED"},
    hasExactMatch = if [Description] = null then false else List.AnyTrue(List.Transform(exactWords, (w) => [Description] = w)),
    hasContainsMatch = if [Description] = null then false else List.AnyTrue(List.Transform(containsWords, (w) => Text.Contains([Description], w)))
in
    ([CustomerID] = null and [UnitPrice] = 0 and [Quantity] < 0) or hasExactMatch or hasContainsMatch),
    #"Merged Queries" = Table.NestedJoin(#"Added IsOperationalNote", {"StockCode"}, #"Table1 - Modified", {"StockCode"}, "Table1 - Modified", JoinKind.LeftOuter),
    #"Expanded Table1 - Modified" = Table.ExpandTableColumn(#"Merged Queries", "Table1 - Modified", {"TopDescription", "DescriptionStatus", "PriceVarianceFlag"}, {"Table1 - Modified.TopDescription", "Table1 - Modified.DescriptionStatus", "Table1 - Modified.PriceVarianceFlag"}),
    #"Added IsDescriptionUnrecoverable" = Table.AddColumn(#"Expanded Table1 - Modified", "IsDescriptionUnrecoverable", each if [#"Table1 - Modified.DescriptionStatus"] = null then true else false),
    #"Merged Queries1" = Table.NestedJoin(#"Added IsDescriptionUnrecoverable", {"StockCode"}, ManualOverrides, {"StockCode"}, "ManualOverrides", JoinKind.LeftOuter),
    #"Expanded ManualOverrides" = Table.ExpandTableColumn(#"Merged Queries1", "ManualOverrides", {"OverrideDescription"}, {"ManualOverrides.OverrideDescription"}),
    #"Added Description_New" = Table.AddColumn(#"Expanded ManualOverrides", "Custom", each if [IsOperationalNote] = true then [Description] else if [ManualOverrides.OverrideDescription] <> null then [ManualOverrides.OverrideDescription] else if [#"Table1 - Modified.DescriptionStatus"] = "Auto Accept" then [#"Table1 - Modified.TopDescription"] else [Description]),
    #"Removed Description_Old" = Table.RemoveColumns(#"Added Description_New",{"Description"}),
    #"Reordered Columns" = Table.ReorderColumns(#"Removed Description_Old",{"InvoiceNo", "StockCode", "Custom", "Quantity", "InvoiceDate", "UnitPrice", "CustomerID", "Country", "HasBlankDescription", "IsOperationalNote", "Table1 - Modified.TopDescription", "Table1 - Modified.DescriptionStatus", "Table1 - Modified.PriceVarianceFlag", "IsDescriptionUnrecoverable", "ManualOverrides.OverrideDescription"}),
    #"Renamed Columns" = Table.RenameColumns(#"Reordered Columns",{{"Custom", "Description"}}),
    #"Merged Queries2" = Table.NestedJoin(#"Renamed Columns", {"StockCode"}, SuspectedVariantCodes, {"StockCode"}, "SuspectedVariantCodes", JoinKind.LeftOuter),
    #"Expanded SuspectedVariantCodes" = Table.ExpandTableColumn(#"Merged Queries2", "SuspectedVariantCodes", {"StockCode"}, {"SuspectedVariantCodes.StockCode"}),
    #"Added isMultiVariantCode" = Table.AddColumn(#"Expanded SuspectedVariantCodes", "IsMultiVariantCode", each if[SuspectedVariantCodes.StockCode] <> null then true else false),
    #"Removed Columns" = Table.RemoveColumns(#"Added isMultiVariantCode",{"SuspectedVariantCodes.StockCode"})
in
    #"Removed Columns"