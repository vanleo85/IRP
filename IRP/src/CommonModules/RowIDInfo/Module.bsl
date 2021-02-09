
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
