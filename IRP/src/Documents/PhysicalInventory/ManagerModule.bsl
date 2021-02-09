#Region Posting

Function PostingGetDocumentDataTables(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	Tables = New Structure();
	QueryArray = GetQueryTextsSecondaryTables();
	PostingServer.ExecuteQuery(Ref, QueryArray, Parameters);
	Return Tables;
EndFunction
	
Function PostingGetLockDataSource(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	DocumentDataTables = Parameters.DocumentDataTables;
	DataMapWithLockFields = New Map();
		
	Return DataMapWithLockFields;
EndFunction

Procedure PostingCheckBeforeWrite(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	Return;
EndProcedure

Function PostingGetPostingDataTables(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	PostingDataTables = New Map();
	
	Return PostingDataTables;
EndFunction

Procedure PostingCheckAfterWrite(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	CheckAfterWrite(Ref, Cancel, Parameters, AddInfo);
EndProcedure

#EndRegion

#Region Undoposting

Function UndopostingGetDocumentDataTables(Ref, Cancel, Parameters, AddInfo = Undefined) Export
	Return PostingGetDocumentDataTables(Ref, Cancel, Undefined, Parameters, AddInfo);
EndFunction

Function UndopostingGetLockDataSource(Ref, Cancel, Parameters, AddInfo = Undefined) Export
	DocumentDataTables = Parameters.DocumentDataTables;
	DataMapWithLockFields = New Map();
	
	Return DataMapWithLockFields;
EndFunction

Procedure UndopostingCheckBeforeWrite(Ref, Cancel, Parameters, AddInfo = Undefined) Export
	Return;
EndProcedure

Procedure UndopostingCheckAfterWrite(Ref, Cancel, Parameters, AddInfo = Undefined) Export
	Parameters.Insert("Unposting", True);
	CheckAfterWrite(Ref, Cancel, Parameters, AddInfo);
EndProcedure

#EndRegion

#Region CheckAfterWrite

Procedure CheckAfterWrite(Ref, Cancel, Parameters, AddInfo = Undefined)
	StatusInfo = ObjectStatusesServer.GetLastStatusInfo(Ref);
	If StatusInfo.Posting Then
		CommonFunctionsClientServer.PutToAddInfo(AddInfo, "BalancePeriod", 
			New Boundary(New PointInTime(StatusInfo.Period, Ref), BoundaryType.Including));
	EndIf;
	If Not (Parameters.Property("Unposting") And Parameters.Unposting) Then
		Parameters.Insert("RecordType", AccumulationRecordType.Expense);
	EndIf;
EndProcedure

#EndRegion

Function GetItemListWithFillingPhysCount(Ref) Export
	Query = New Query();
	Query.Text = GetQueryTextFillPhysCount_ByItemList();
	
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.Execute();
	QueryTable = QueryResult.Unload();
	Return QueryTable;
EndFunction

Function GetQueryTextFillPhysCount_ByItemList()
	Return
	"SELECT
	|	NestedSelect.ItemKey.Item AS Item,
	|	NestedSelect.ItemKey AS ItemKey,
	|	NestedSelect.Unit AS Unit,
	|	SUM(NestedSelect.ExpCount) AS ExpCount,
	|	SUM(NestedSelect.PhysCount) AS PhysCount,
	|	SUM(NestedSelect.PhysCount) - SUM(NestedSelect.ExpCount) AS Difference
	|FROM
	|	(SELECT
	|		PhysicalInventoryItemList.ItemKey AS ItemKey,
	|		PhysicalInventoryItemList.Unit AS Unit,
	|		SUM(PhysicalInventoryItemList.ExpCount) AS ExpCount,
	|		0 AS PhysCount
	|	FROM
	|		Document.PhysicalInventory.ItemList AS PhysicalInventoryItemList
	|	WHERE
	|		PhysicalInventoryItemList.Ref = &Ref
	|	
	|	GROUP BY
	|		PhysicalInventoryItemList.ItemKey,
	|		PhysicalInventoryItemList.Unit
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PhysicalCountByLocationItemList.ItemKey,
	|		PhysicalCountByLocationItemList.Unit,
	|		0,
	|		SUM(PhysicalCountByLocationItemList.PhysCount)
	|	FROM
	|		Document.PhysicalCountByLocation.ItemList AS PhysicalCountByLocationItemList
	|	WHERE
	|		PhysicalCountByLocationItemList.Ref.PhysicalInventory = &Ref
	|		AND NOT PhysicalCountByLocationItemList.Ref.DeletionMark
	|	
	|	GROUP BY
	|		PhysicalCountByLocationItemList.ItemKey,
	|		PhysicalCountByLocationItemList.Unit) AS NestedSelect
	|
	|GROUP BY
	|	NestedSelect.ItemKey.Item,
	|	NestedSelect.ItemKey,
	|	NestedSelect.Unit";
EndFunction

Function GetItemListWithFillingExpCount(Ref, Store, ItemList = Undefined) Export
	Query = New Query();
	 
	If ItemList = Undefined Then
		Query.Text = GetQueryTextFillExpCount();
	Else
		Query.Text = GetQueryTextFillExpCount_ByItemList();
		
		AccReg = Metadata.AccumulationRegisters.StockBalance;
		
		ItemListTyped = New ValueTable();
		ItemListTyped.Columns.Add("Key", New TypeDescription(Metadata.DefinedTypes.typeRowID.Type));
		ItemListTyped.Columns.Add("LineNumber", New TypeDescription("Number"));
		ItemListTyped.Columns.Add("Store", AccReg.Dimensions.Store.Type);
		ItemListTyped.Columns.Add("ItemKey", AccReg.Dimensions.ItemKey.Type);
		ItemListTyped.Columns.Add("Unit", New TypeDescription("CatalogRef.Units"));
		ItemListTyped.Columns.Add("PhysCount", New TypeDescription(Metadata.DefinedTypes.typeQuantity.Type));
		ItemListTyped.Columns.Add("ResponsiblePerson", New TypeDescription("CatalogRef.Partners"));
		For Each Row In ItemList Do
			FillPropertyValues(ItemListTyped.Add(), Row);
		EndDo;
		
		Query.SetParameter("ItemList", ItemListTyped);
	EndIf;
	
	If ValueIsFilled(Ref) Then
		Query.SetParameter("Period", New Boundary(Ref.PointInTime(), BoundaryType.Excluding));
	Else
		Query.SetParameter("Period", Undefined);
	EndIf;
	
	Query.SetParameter("Store", Store);
	
	QueryResult = Query.Execute();
	QueryTable = QueryResult.Unload();
	
	If QueryTable.Columns.Find("Key") = Undefined Then
		QueryTable.Columns.Add("Key", New TypeDescription(Metadata.DefinedTypes.typeRowID.Type));
	EndIf;
	
	If QueryTable.Columns.Find("LineNumber") <> Undefined Then
		QueryTable.Columns.Delete("LineNumber");
	EndIf;
	
	For Each Row In QueryTable Do
		If Not ValueIsFilled(Row.Key) Then
			Row.Key = New UUID();
		EndIf;
	EndDo;
	Return QueryTable;
EndFunction

Function GetQueryTextFillExpCount()
	Return 
	"SELECT
	|	StockBalanceBalance.Store,
	|	StockBalanceBalance.ItemKey.Item AS Item,
	|	StockBalanceBalance.ItemKey,
	|	CASE
	|		WHEN StockBalanceBalance.ItemKey.Unit <> VALUE(Catalog.Units.EmptyRef)
	|			THEN StockBalanceBalance.ItemKey.Unit
	|		ELSE StockBalanceBalance.ItemKey.Item.Unit
	|	END AS Unit,
	|	StockBalanceBalance.QuantityBalance AS ExpCount,
	|	0 AS PhysCount
	|FROM
	|	AccumulationRegister.StockBalance.Balance(&Period, Store = &Store) AS StockBalanceBalance";
EndFunction

Function GetQueryTextFillExpCount_ByItemList()
	Return
	"SELECT
	|	tmp.Key AS Key,
	|	tmp.LineNumber AS LineNumber,
	|	tmp.Store AS Store,
	|	tmp.ItemKey AS ItemKey,
	|	tmp.Unit AS Unit,
	|	tmp.PhysCount AS PhysCount,
	|	tmp.ResponsiblePerson AS ResponsiblePerson
	|INTO ItemList
	|FROM
	|	&ItemList AS tmp
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	StockBalanceBalance.Store,
	|	StockBalanceBalance.ItemKey,
	|	CASE
	|		WHEN StockBalanceBalance.ItemKey.Unit <> VALUE(Catalog.Units.EmptyRef)
	|			THEN StockBalanceBalance.ItemKey.Unit
	|		ELSE StockBalanceBalance.ItemKey.Item.Unit
	|	END AS Unit,
	|	StockBalanceBalance.QuantityBalance AS ExpCount
	|INTO StockBalance
	|FROM
	|	AccumulationRegister.StockBalance.Balance(&Period, (Store) IN
	|		(SELECT
	|			ItemList.Store
	|		FROM
	|			ItemList AS ItemList)) AS StockBalanceBalance
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ItemList.Key,
	|	ISNULL(ItemList.Store, StockBalance.Store) AS Store,
	|	ISNULL(ItemList.ItemKey, StockBalance.ItemKey) AS ItemKey,
	|	ISNULL(ItemList.ItemKey.Item, StockBalance.ItemKey.Item) AS Item,
	|	ISNULL(ItemList.Unit, StockBalance.Unit) AS Unit,
	|	ISNULL(ItemList.PhysCount, 0) AS PhysCount,
	|	ISNULL(StockBalance.ExpCount, 0) AS ExpCount,
	|	ISNULL(ItemList.LineNumber, -1) AS LineNumber,
	|	ISNULL(ItemList.ResponsiblePerson, Value(Catalog.Partners.EmptyRef)) AS ResponsiblePerson
	|FROM
	|	ItemList AS ItemList
	|		FULL JOIN StockBalance AS StockBalance
	|		ON ItemList.Store = StockBalance.Store
	|		AND ItemList.ItemKey = StockBalance.ItemKey
	|ORDER BY
	|	LineNumber";
EndFunction

#Region NewRegistersPosting

Function GetInformationAboutMovements(Ref) Export
	Str = New Structure;
	Str.Insert("QueryParamenters", GetAdditionalQueryParamenters(Ref));
	Str.Insert("QueryTextsMasterTables", GetQueryTextsMasterTables());
	Str.Insert("QueryTextsSecondaryTables", GetQueryTextsSecondaryTables());
	Return Str;
EndFunction

Function GetAdditionalQueryParamenters(Ref)
	StrParams = New Structure();
	StrParams.Insert("Ref", Ref);
	Return StrParams;
EndFunction

Function GetQueryTextsSecondaryTables()
	QueryArray = New Array;
	QueryArray.Add(Tmp());
	Return QueryArray;
EndFunction

Function GetQueryTextsMasterTables()
	QueryArray = New Array;
	QueryArray.Add(Tmp());
	Return QueryArray;
EndFunction

Function Tmp()
	Return
		"SELECT NULL";
EndFunction
#EndRegion
