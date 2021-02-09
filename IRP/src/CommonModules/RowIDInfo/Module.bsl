
Procedure Posting_RowID(Source, Cancel, PostingMode) Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|   Table.Ref AS Recorder,
		|   Table.Ref.Date AS Period,
		|	CASE When Table.Basis.Ref IS NULL Then
		|		&Ref
		|	ELSE
		|		Table.Basis
		|	END AS Basis, 
		|	*
		|INTO RowIDMovements
		|FROM
		|	Document." + Source.Metadata().Name + ".RowIDInfo AS Table
		|WHERE
		|	Table.Ref = &Ref
		|
		|;
		|
		|SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	Table.CurrentStep AS Step,
		|	*
		|FROM
		|	RowIDMovements AS Table
		|WHERE
		|	NOT Table.CurrentStep = VALUE(Catalog.MovementRules.EmptyRef)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(AccumulationRecordType.Receipt),
		|	Table.NextStep AS Step,
		|	*
		|FROM
		|	RowIDMovements AS Table
		|WHERE
		|	NOT Table.NextStep = VALUE(Catalog.MovementRules.EmptyRef)";

	Query.SetParameter("Ref", Source.Ref);
	
	QueryResult = Query.Execute().Unload();
	Source.RegisterRecords.T10000B_RowIDMovements.Load(QueryResult);
	
EndProcedure

Procedure BeforeWrite_RowID(Source, Cancel, WriteMode, PostingMode) Export
	
	If TypeOf(Source) = Type("DocumentObject.SalesOrder") Then
		SalesOrder_FillRowID(Source);	
	EndIf;	

EndProcedure

// Description
// 	Fill Row ID List
// Parameters:
// 	Source - DocumentObject.SalesOrder
Procedure SalesOrder_FillRowID(Source)
	Source.RowIDInfo.Clear();
	For Each Row In Source.ItemList Do
		
		If Row.Cancel Then
			Continue;
		EndIf;
		
		NewRow = Source.RowIDInfo.Add();
		NewRow.Key = Row.Key;
		NewRow.RowID = Row.Key;
		NewRow.Quantity = Row.QuantityInBaseUnit;
		
		NextStep = Catalogs.MovementRules.EmptyRef();
		
		If Row.ProcurementMethod = Enums.ProcurementMethods.Purchase Then
			NextStep = Catalogs.MovementRules.FromSalesOrderToPurchaseOrder;
		Else
			If Source.ShipmentConfirmationsBeforeSalesInvoice Then
				NextStep = Catalogs.MovementRules.FromSalesOrderToShipmentConfirmation;
			Else
				NextStep = Catalogs.MovementRules.FromSalesOrderToSalesInvoice;
			EndIf;
		EndIf;
		
		NewRow.NextStep = NextStep;
	EndDo;
EndProcedure

#Region FillBaseOnDocuments

#Region SalesInvoice
Procedure FillSalesInvoiceFromSalesOrders(SalesOrderList, Object, Form) Export

	Settings = New Structure();
	Settings.Insert("Rows", New Array());
	Settings.Insert("CalculateSettings", New Structure());
	Settings.CalculateSettings = CalculationStringsClientServer.GetCalculationSettings(Settings.CalculateSettings);
		
	For Each ResultRow In SalesOrderList Do
		RowsByKey = Object.ItemList.FindRows(New Structure("Key", ResultRow.Key));
		If RowsByKey.Count() Then
			RowByKey = RowsByKey[0];
			ItemKeyUnit = CatItemsServer.GetItemKeyUnit(ResultRow.ItemKey);
			UnitFactorFrom = Catalogs.Units.GetUnitFactor(RowByKey.Unit, ItemKeyUnit);
			UnitFactorTo = Catalogs.Units.GetUnitFactor(ResultRow.Unit, ItemKeyUnit);
			FillPropertyValues(RowByKey, ResultRow, , "Quantity");
			RowByKey.Quantity = ?(UnitFactorTo = 0,	0,
					RowByKey.Quantity * UnitFactorFrom / UnitFactorTo) + ResultRow.Quantity;
			RowByKey.PriceType = ResultRow.PriceType;
			RowByKey.Price = ResultRow.Price;
			Settings.Rows.Add(RowByKey);
		Else
			NewRow = Object.ItemList.Add();
			FillPropertyValues(NewRow, ResultRow);
			NewRow.PriceType = ResultRow.PriceType;
			NewRow.Price = ResultRow.Price;
			Settings.Rows.Add(NewRow);
		EndIf;
	EndDo;
	
	TaxInfo = Undefined;
	SavedData = TaxesClientServer.GetSavedData(Form, TaxesServer.GetAttributeNames().CacheName);
	If SavedData.Property("ArrayOfColumnsInfo") Then
		TaxInfo = SavedData.ArrayOfColumnsInfo;
	EndIf;
	CalculationStringsClientServer.CalculateItemsRows(Object,
		Form,
		Settings.Rows,
		Settings.CalculateSettings,
		TaxInfo);
EndProcedure

Function GetSalesOrdersInfoForSalesInvoice(FilterValues) Export
	StepArray = New Array;
	StepArray.Add(Catalogs.MovementRules.FromSalesOrderToSalesInvoice);
	
	Query = New Query;
	Query.SetParameter("StepArray", StepArray);	
	Query.SetParameter("Company", FilterValues.Company);
	Query.SetParameter("Partner", FilterValues.Partner);
	Query.SetParameter("LegalName", FilterValues.LegalName);
	Query.SetParameter("Agreement", FilterValues.Agreement);
	Query.SetParameter("Currency", FilterValues.Currency);
	Query.SetParameter("Ref", FilterValues.Ref);
	Query.Text =
		"SELECT
		|	RowInfo.RowID,
		|	RowInfo.Step,
		|	RowInfo.Basis,
		|	RowInfo.QuantityBalance AS Quantity
		|INTO tmpQueryTable
		|FROM
		|	AccumulationRegister.T10000B_RowIDMovements.Balance(, Step IN (&StepArray)
		|	AND Basis.Company = &Company
		|	AND Basis.Partner = &Partner
		|	AND Basis.LegalName = &LegalName
		|	AND Basis.Agreement = &Agreement
		|	AND Basis.Currency = &Currency) AS RowInfo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	Doc.ItemKey AS ItemKey,
		|	Doc.ItemKey.Item AS Item,
		|	Doc.Store AS Store,
		|	Doc.Ref AS SalesOrder,
		|	Doc.Key,
		|	Doc.ItemKey.Item.Unit AS QuantityUnit,
		|	tmpQueryTable.Quantity AS Quantity,
		|	ISNULL(Doc.Price, 0) AS Price,
		|	ISNULL(Doc.PriceType, VALUE(Catalog.PriceTypes.EmptyRef)) AS PriceType,
		|	ISNULL(Doc.Unit, VALUE(Catalog.Units.EmptyRef)) AS Unit,
		|	ISNULL(Doc.DeliveryDate, DATETIME(1, 1, 1)) AS DeliveryDate
		|FROM
		|	Document.SalesOrder.ItemList AS Doc
		|		INNER JOIN tmpQueryTable AS tmpQueryTable
		|		ON tmpQueryTable.RowID = Doc.Key
		|		AND tmpQueryTable.Basis = Doc.Ref";

	Return Query.Execute().Unload();
EndFunction

#EndRegion

#EndRegion

#Region Service
Function GetRowInfo(RowIDList, StepArray)
	Query = New Query;
	Query.Text =
		"SELECT
		|	RowInfo.RowID,
		|	RowInfo.Step,
		|	RowInfo.Basis,
		|	RowInfo.QuantityBalance
		|FROM
		|	AccumulationRegister.T10000B_RowIDMovements.Balance(, Step IN (&StepArray)
		|	AND RowID IN (&RowIDList)) AS RowInfo";
	
	Query.SetParameter("RowIDList", RowIDList);
	Query.SetParameter("StepArray", StepArray);
	
	Return Query.Execute().Unload();
EndFunction
#EndRegion
