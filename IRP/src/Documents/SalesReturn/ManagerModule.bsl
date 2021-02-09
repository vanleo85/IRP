#Region Posting

Function PostingGetDocumentDataTables(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	Tables = New Structure();
	QueryArray = GetQueryTextsSecondaryTables();
	PostingServer.ExecuteQuery(Ref, QueryArray, Parameters);
	Return Tables;
EndFunction

Function PostingGetLockDataSource(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	DataMapWithLockFields = New Map();
	Return DataMapWithLockFields;
EndFunction

Procedure PostingCheckBeforeWrite(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	Tables = Parameters.DocumentDataTables;	
	QueryArray = GetQueryTextsMasterTables();
	PostingServer.SetRegisters(Tables, Ref);
	PostingServer.FillPostingTables(Tables, Ref, QueryArray, Parameters);
EndProcedure

Function PostingGetPostingDataTables(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	PostingDataTables = New Map();
	PostingServer.SetPostingDataTables(PostingDataTables, Parameters);
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
	PostingServer.CheckBalance_AfterWrite(Ref, Cancel, Parameters, "Document.SalesReturn.ItemList", AddInfo);
EndProcedure

#EndRegion

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
	QueryArray.Add(ItemList());
	QueryArray.Add(SerialLotNumbers());
	Return QueryArray;
EndFunction

Function GetQueryTextsMasterTables()
	QueryArray = New Array;
	QueryArray.Add(R4014B_SerialLotNumber());
	QueryArray.Add(R1031B_ReceiptInvoicing());	
	Return QueryArray;
EndFunction

Function ItemList()
	Return	
		"SELECT
		|	GoodsReceipts.Key,
		|	GoodsReceipts.GoodsReceipt,
		|	SUM(GoodsReceipts.Quantity) AS Quantity
		|INTO GoodsReceipts
		|FROM
		|	Document.SalesReturn.GoodsReceipts AS GoodsReceipts
		|WHERE
		|	GoodsReceipts.Ref = &Ref
		|GROUP BY
		|	GoodsReceipts.Key,
		|	GoodsReceipts.GoodsReceipt
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesReturnItemList.Ref.Company AS Company,
		|	SalesReturnItemList.Store AS Store,
		|	SalesReturnItemList.Store.UseGoodsReceipt AS UseGoodsReceipt,
		|	SalesReturnItemList.ItemKey AS ItemKey,
		|	SalesReturnItemList.SalesReturnOrder AS SalesReturnOrder,
		|	SalesReturnItemList.Ref AS SalesReturn,
		|	CASE
		|		WHEN SalesReturnItemList.Ref.Agreement.ApArPostingDetail = VALUE(Enum.ApArPostingDetail.ByDocuments)
		|			THEN SalesReturnItemList.Ref
		|		ELSE UNDEFINED
		|	END AS BasisDocument,
		|	SalesReturnItemList.QuantityInBaseUnit AS Quantity,
		|	SalesReturnItemList.TotalAmount AS TotalAmount,
		|	SalesReturnItemList.Ref.Partner AS Partner,
		|	SalesReturnItemList.Ref.LegalName AS LegalName,
		|	CASE
		|		WHEN SalesReturnItemList.Ref.Agreement.Kind = VALUE(Enum.AgreementKinds.Regular)
		|		AND SalesReturnItemList.Ref.Agreement.ApArPostingDetail = VALUE(Enum.ApArPostingDetail.ByStandardAgreement)
		|			THEN SalesReturnItemList.Ref.Agreement.StandardAgreement
		|		ELSE SalesReturnItemList.Ref.Agreement
		|	END AS Agreement,
		|	ISNULL(SalesReturnItemList.Ref.Currency, VALUE(Catalog.Currencies.EmptyRef)) AS Currency,
		|	SalesReturnItemList.Ref.Date AS Period,
		|	CASE
		|		WHEN SalesReturnItemList.SalesInvoice.Ref IS NULL
		|		OR VALUETYPE(SalesReturnItemList.SalesInvoice) <> TYPE(Document.SalesInvoice)
		|			THEN SalesReturnItemList.Ref
		|		ELSE SalesReturnItemList.SalesInvoice
		|	END AS SalesInvoice,
		|	SalesReturnItemList.SalesInvoice AS AgingSalesInvoice,
		|	SalesReturnItemList.Key,
		|	SalesReturnItemList.ItemKey.Item.ItemType.Type = VALUE(Enum.ItemTypes.Service) AS IsService
		|INTO ItemLIst
		|FROM
		|	Document.SalesReturn.ItemList AS SalesReturnItemList
		|WHERE
		|	SalesReturnItemList.Ref = &Ref";
EndFunction

Function SerialLotNumbers()
	Return
		"SELECT
		|	SerialLotNumbers.Ref.Date AS Period,
		|	SerialLotNumbers.Ref.Company AS Company,
		|	SerialLotNumbers.Key,
		|	SerialLotNumbers.SerialLotNumber,
		|	SerialLotNumbers.Quantity,
		|	ItemList.ItemKey AS ItemKey
		|INTO SerialLotNumbers
		|FROM
		|	Document.SalesReturn.SerialLotNumbers AS SerialLotNumbers
		|		LEFT JOIN Document.SalesReturn.ItemList AS ItemList
		|		ON SerialLotNumbers.Key = ItemList.Key
		|WHERE
		|	SerialLotNumbers.Ref = &Ref";	
EndFunction	

Function R4014B_SerialLotNumber()
	Return
		"SELECT 
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	*
		|INTO R4014B_SerialLotNumber
		|FROM
		|	SerialLotNumbers AS QueryTable
		|WHERE 
		|	TRUE";

EndFunction

Function R1031B_ReceiptInvoicing()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	GoodsReceipts.GoodsReceipt AS Basis,
		|	GoodsReceipts.Quantity,
		|	ItemList.Company,
		|	ItemList.Period,
		|	ItemList.ItemKey,
		|	ItemList.Store
		|INTO R1031B_ReceiptInvoicing
		|FROM
		|	ItemList AS ItemList
		|		INNER JOIN GoodsReceipts AS GoodsReceipts
		|		ON ItemList.Key = GoodsReceipts.Key
		|WHERE
		|	TRUE";
EndFunction

#EndRegion
