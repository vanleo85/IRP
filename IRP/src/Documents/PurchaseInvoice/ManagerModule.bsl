#Region Posting

Function PostingGetDocumentDataTables(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	Tables = New Structure();
	QueryArray = GetQueryTextsSecondaryTables();
	PostingServer.ExecuteQuery(Ref, QueryArray, Parameters);
	Tables.Insert("VendorsTransactions", PostingServer.GetQueryTableByName("VendorsTransactions", Parameters));	
	
	Return Tables;
EndFunction

Function PostingGetLockDataSource(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	DocumentDataTables = Parameters.DocumentDataTables;
	DataMapWithLockFields = New Map();
	
	PostingServer.SetLockDataSource(DataMapWithLockFields, 
		AccumulationRegisters.R1020B_AdvancesToVendors, 
		DocumentDataTables.VendorsTransactions);

	Return DataMapWithLockFields;
EndFunction

Procedure PostingCheckBeforeWrite(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	
	Tables = Parameters.DocumentDataTables;
	
	OffsetOfPartnersServer.Vendors_OnTransaction(Parameters);
	
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
	Unposting = ?(Parameters.Property("Unposting"), Parameters.Unposting, False);
	
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
	QueryArray.Add(VendorsTransactions());
	QueryArray.Add(SerialLotNumbers());
	Return QueryArray;
EndFunction

Function GetQueryTextsMasterTables()
	QueryArray = New Array;
	QueryArray.Add(R1001T_Purchases());
	QueryArray.Add(R1005T_PurchaseSpecialOffers());
	QueryArray.Add(R1011B_PurchaseOrdersReceipt());
	QueryArray.Add(R1012B_PurchaseOrdersInvoiceClosing());
	QueryArray.Add(R1020B_AdvancesToVendors());
	QueryArray.Add(R1021B_VendorsTransactions());
	QueryArray.Add(R1031B_ReceiptInvoicing());
	QueryArray.Add(R1040B_TaxesOutgoing());
	QueryArray.Add(R2013T_SalesOrdersProcurement());
	QueryArray.Add(R4010B_ActualStocks());
	QueryArray.Add(R4011B_FreeStocks());
	QueryArray.Add(R4014B_SerialLotNumber());
	QueryArray.Add(R4017B_InternalSupplyRequestProcurement());
	QueryArray.Add(R4033B_GoodsReceiptSchedule());
	QueryArray.Add(R4050B_StockInventory());
	QueryArray.Add(R5010B_ReconciliationStatement());
//	QueryArray.Add(R4035B_IncomingStocks());
//	QueryArray.Add(R4036B_IncomingStocksRequested());
//	QueryArray.Add(R4012B_StockReservation());
	Return QueryArray;
EndFunction

Function ItemList()
	Return
		"SELECT
		|	GoodsReceipts.Key
		|INTO GoodsReceipts
		|FROM
		|	Document.PurchaseInvoice.GoodsReceipts AS GoodsReceipts
		|WHERE
		|	GoodsReceipts.Ref = &Ref
		|GROUP BY
		|	GoodsReceipts.Key
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PurchaseInvoiceItemList.Ref.Date AS Period,
		|	PurchaseInvoiceItemList.Ref AS Invoice,
		|	PurchaseInvoiceItemList.Key AS RowKey,
		|	PurchaseInvoiceItemList.ItemKey,
		|	PurchaseInvoiceItemList.Ref.Company AS Company,
		|	PurchaseInvoiceItemList.Ref.Currency,
		|	PurchaseInvoiceSpecialOffers.Offer AS SpecialOffer,
		|	PurchaseInvoiceSpecialOffers.Amount AS OffersAmount
		|INTO OffersInfo
		|FROM
		|	Document.PurchaseInvoice.ItemList AS PurchaseInvoiceItemList
		|		INNER JOIN Document.PurchaseInvoice.SpecialOffers AS PurchaseInvoiceSpecialOffers
		|		ON PurchaseInvoiceItemList.Key = PurchaseInvoiceSpecialOffers.Key
		|WHERE
		|	PurchaseInvoiceItemList.Ref = &Ref
		|	AND PurchaseInvoiceSpecialOffers.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PurchaseInvoiceItemList.Ref.Company AS Company,
		|	PurchaseInvoiceItemList.Store AS Store,
		|	PurchaseInvoiceItemList.UseGoodsReceipt AS UseGoodsReceipt,
		|	NOT PurchaseInvoiceItemList.PurchaseOrder = VALUE(Document.PurchaseOrder.EmptyRef) AS PurchaseOrderExists,
		|	NOT PurchaseInvoiceItemList.SalesOrder = VALUE(Document.SalesOrder.EmptyRef) AS SalesOrderExists,
		|	NOT PurchaseInvoiceItemList.InternalSupplyRequest = VALUE(Document.InternalSupplyRequest.EmptyRef) AS
		|		InternalSupplyRequestExists,
		|	NOT GoodsReceipts.Key IS NULL AS GoodsReceiptExists,
		|	PurchaseInvoiceItemList.ItemKey AS ItemKey,
		|	PurchaseInvoiceItemList.PurchaseOrder AS PurchaseOrder,
		|	PurchaseInvoiceItemList.SalesOrder AS SalesOrder,
		|	PurchaseInvoiceItemList.InternalSupplyRequest,
		|	PurchaseInvoiceItemList.Ref AS Invoice,
		|	PurchaseInvoiceItemList.Quantity AS UnitQuantity,
		|	PurchaseInvoiceItemList.QuantityInBaseUnit AS Quantity,
		|	PurchaseInvoiceItemList.TotalAmount AS Amount,
		|	PurchaseInvoiceItemList.Ref.Partner AS Partner,
		|	PurchaseInvoiceItemList.Ref.LegalName AS LegalName,
		|	CASE
		|		WHEN PurchaseInvoiceItemList.Ref.Agreement.Kind = VALUE(Enum.AgreementKinds.Regular)
		|		AND PurchaseInvoiceItemList.Ref.Agreement.ApArPostingDetail = VALUE(Enum.ApArPostingDetail.ByStandardAgreement)
		|			THEN PurchaseInvoiceItemList.Ref.Agreement.StandardAgreement
		|		ELSE PurchaseInvoiceItemList.Ref.Agreement
		|	END AS Agreement,
		|	CASE
		|		WHEN PurchaseInvoiceItemList.Ref.Agreement.ApArPostingDetail = VALUE(Enum.ApArPostingDetail.ByDocuments)
		|			THEN PurchaseInvoiceItemList.Ref
		|		ELSE UNDEFINED
		|	END AS BasisDocument,
		|	ISNULL(PurchaseInvoiceItemList.Ref.Currency, VALUE(Catalog.Currencies.EmptyRef)) AS Currency,
		|	PurchaseInvoiceItemList.Unit AS Unit,
		|	PurchaseInvoiceItemList.ItemKey.Item AS Item,
		|	PurchaseInvoiceItemList.Ref.Date AS Period,
		|	PurchaseInvoiceItemList.Key AS RowKey,
		|	PurchaseInvoiceItemList.AdditionalAnalytic AS AdditionalAnalytic,
		|	PurchaseInvoiceItemList.BusinessUnit AS BusinessUnit,
		|	PurchaseInvoiceItemList.ExpenseType AS ExpenseType,
		|	PurchaseInvoiceItemList.ItemKey.Item.ItemType.Type = VALUE(Enum.ItemTypes.Service) AS IsService,
		|	PurchaseInvoiceItemList.DeliveryDate AS DeliveryDate,
		|	PurchaseInvoiceItemList.NetAmount AS NetAmount
		|INTO ItemList
		|FROM
		|	Document.PurchaseInvoice.ItemList AS PurchaseInvoiceItemList
		|		LEFT JOIN GoodsReceipts AS GoodsReceipts
		|		ON PurchaseInvoiceItemList.Key = GoodsReceipts.Key
		|WHERE
		|	PurchaseInvoiceItemList.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PurchaseInvoiceGoodsReceipts.Key,
		|	PurchaseInvoiceGoodsReceipts.GoodsReceipt,
		|	PurchaseInvoiceGoodsReceipts.Quantity
		|INTO GoodReceiptInfo
		|FROM
		|	Document.PurchaseInvoice.GoodsReceipts AS PurchaseInvoiceGoodsReceipts
		|WHERE
		|	PurchaseInvoiceGoodsReceipts.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PurchaseInvoiceTaxList.Ref.Date AS Period,
		|	PurchaseInvoiceTaxList.Ref.Company AS Company,
		|	PurchaseInvoiceTaxList.Tax AS Tax,
		|	PurchaseInvoiceTaxList.TaxRate AS TaxRate,
		|	CASE
		|		WHEN PurchaseInvoiceTaxList.ManualAmount = 0
		|			THEN PurchaseInvoiceTaxList.Amount
		|		ELSE PurchaseInvoiceTaxList.ManualAmount
		|	END AS TaxAmount,
		|	PurchaseInvoiceItemList.NetAmount AS TaxableAmount
		|INTO Taxes
		|FROM
		|	Document.PurchaseInvoice.ItemList AS PurchaseInvoiceItemList
		|		LEFT JOIN Document.PurchaseInvoice.TaxList AS PurchaseInvoiceTaxList
		|		ON PurchaseInvoiceItemList.Key = PurchaseInvoiceTaxList.Key
		|WHERE
		|	PurchaseInvoiceItemList.Ref = &Ref
		|	AND PurchaseInvoiceTaxList.Ref = &Ref";
EndFunction

Function VendorsTransactions()
	Return
		"SELECT
		|	ItemList.Period,
		|	ItemList.Company AS Company,
		|	ItemList.Currency AS Currency,
		|	ItemList.LegalName AS LegalName,
		|	ItemList.Partner AS Partner,
		|	ItemList.BasisDocument TransactionDocument,
		|	ItemList.Agreement AS Agreement,
		|	SUM(ItemList.Amount) AS DocumentAmount
		|INTO VendorsTransactions
		|FROM
		|	ItemList AS ItemList
		|GROUP BY
		|	ItemList.Company,
		|	ItemList.BasisDocument,
		|	ItemList.Partner,
		|	ItemList.LegalName,
		|	ItemList.Agreement,
		|	ItemList.Currency,
		|	ItemList.Period";
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
		|	Document.PurchaseInvoice.SerialLotNumbers AS SerialLotNumbers
		|		LEFT JOIN Document.PurchaseInvoice.ItemList AS ItemList
		|		ON SerialLotNumbers.Key = ItemList.Key
		|WHERE
		|	SerialLotNumbers.Ref = &Ref";	
EndFunction	

Function R1001T_Purchases()
	Return
		"SELECT *
		|INTO R1001T_Purchases
		|FROM
		|	ItemList AS ItemList
		|WHERE TRUE";

EndFunction

Function R1005T_PurchaseSpecialOffers()
	Return
		"SELECT *
		|INTO R1005T_PurchaseSpecialOffers
		|FROM
		|	OffersInfo AS OffersInfo
		|WHERE TRUE";

EndFunction

Function R1011B_PurchaseOrdersReceipt()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.PurchaseOrder AS Order,
		|	*
		|INTO R1011B_PurchaseOrdersReceipt
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.UseGoodsReceipt
		|	AND ItemList.PurchaseOrderExists
		|	AND NOT ItemList.IsService";

EndFunction

Function R1012B_PurchaseOrdersInvoiceClosing()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.PurchaseOrder AS Order,
		|	*
		|INTO R1012B_PurchaseOrdersInvoiceClosing
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	ItemList.PurchaseOrderExists";

EndFunction

Function R1020B_AdvancesToVendors()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	OffsetOfAdvance.Period,
		|	OffsetOfAdvance.Company,
		|	OffsetOfAdvance.Currency,
		|	OffsetOfAdvance.LegalName,
		|	OffsetOfAdvance.Partner,
		|	OffsetOfAdvance.AdvancesDocument AS Basis,
		|	SUM(OffsetOfAdvance.Amount)
		|INTO R1020B_AdvancesToVendors
		|FROM
		|	OffsetOfAdvance AS OffsetOfAdvance
		|GROUP BY
		|	OffsetOfAdvance.Period,
		|	OffsetOfAdvance.Company,
		|	OffsetOfAdvance.Currency,
		|	OffsetOfAdvance.LegalName,
		|	OffsetOfAdvance.Partner,
		|	OffsetOfAdvance.AdvancesDocument,
		|	VALUE(AccumulationRecordType.Expense)";
EndFunction

Function R1021B_VendorsTransactions()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	VendorsTransactions.Period,
		|	VendorsTransactions.Company,
		|	VendorsTransactions.Currency,
		|	VendorsTransactions.LegalName,
		|	VendorsTransactions.Partner,
		|	VendorsTransactions.Agreement,
		|	VendorsTransactions.TransactionDocument AS Basis,
		|	SUM(VendorsTransactions.DocumentAmount) AS Amount
		|INTO R1021B_VendorsTransactions
		|FROM
		|	VendorsTransactions AS VendorsTransactions
		|GROUP BY
		|	VendorsTransactions.Period,
		|	VendorsTransactions.Company,
		|	VendorsTransactions.Currency,
		|	VendorsTransactions.LegalName,
		|	VendorsTransactions.Partner,
		|	VendorsTransactions.Agreement,
		|	VendorsTransactions.TransactionDocument,
		|	VALUE(AccumulationRecordType.Receipt)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(AccumulationRecordType.Expense),
		|	OffsetOfAdvance.Period,
		|	OffsetOfAdvance.Company,
		|	OffsetOfAdvance.Currency,
		|	OffsetOfAdvance.LegalName,
		|	OffsetOfAdvance.Partner,
		|	OffsetOfAdvance.Agreement,
		|	OffsetOfAdvance.TransactionDocument,
		|	SUM(OffsetOfAdvance.Amount)
		|FROM
		|	OffsetOfAdvance AS OffsetOfAdvance
		|GROUP BY
		|	OffsetOfAdvance.Period,
		|	OffsetOfAdvance.Company,
		|	OffsetOfAdvance.Currency,
		|	OffsetOfAdvance.LegalName,
		|	OffsetOfAdvance.Partner,
		|	OffsetOfAdvance.Agreement,
		|	OffsetOfAdvance.TransactionDocument,
		|	VALUE(AccumulationRecordType.Expense)";
EndFunction

Function R1031B_ReceiptInvoicing()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	ItemList.Invoice AS Basis,
		|	ItemList.Quantity AS Quantity,
		|	ItemList.Company,
		|	ItemList.Period,
		|	ItemList.ItemKey,
		|	ItemList.Store
		|INTO R1031B_ReceiptInvoicing
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	ItemList.UseGoodsReceipt
		|	AND NOT ItemList.GoodsReceiptExists
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(AccumulationRecordType.Expense),
		|	GoodsReceipts.GoodsReceipt,
		|	GoodsReceipts.Quantity,
		|	ItemList.Company,
		|	ItemList.Period,
		|	ItemList.ItemKey,
		|	ItemList.Store
		|FROM
		|	ItemList AS ItemList
		|		INNER JOIN GoodReceiptInfo AS GoodsReceipts
		|		ON ItemList.RowKey = GoodsReceipts.Key
		|WHERE
		|	TRUE";

EndFunction

Function R1040B_TaxesOutgoing()
	Return
		"SELECT 
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	*
		|INTO R1040B_TaxesOutgoing
		|FROM
		|	Taxes AS Taxes
		|WHERE TRUE";

EndFunction

Function R2013T_SalesOrdersProcurement()
	Return
		"SELECT
		|	ItemList.Quantity AS PurchaseQuantity,
		|	ItemList.SalesOrder AS Order,
		|	*
		|INTO R2013T_SalesOrdersProcurement
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService
		|	AND ItemList.SalesOrderExists";

EndFunction

Function R4010B_ActualStocks()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	*
		|INTO R4010B_ActualStocks
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService
		|	AND NOT ItemList.UseGoodsReceipt
		|	AND NOT ItemList.GoodsReceiptExists";

EndFunction

Function R4011B_FreeStocks()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	ItemList.Period AS Period,
		|	ItemList.Store AS Store,
		|	ItemList.ItemKey AS ItemKey,
		|	ItemList.Quantity AS Quantity
		|INTO R4011B_FreeStocks
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService
		|	AND NOT ItemList.UseGoodsReceipt
		|	AND NOT ItemList.GoodsReceiptExists";

EndFunction

Function R4014B_SerialLotNumber()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	*
		|INTO R4014B_SerialLotNumber
		|FROM
		|	SerialLotNumbers AS SerialLotNumbers
		|WHERE
		|	TRUE";

EndFunction

Function R4017B_InternalSupplyRequestProcurement()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	*
		|INTO R4017B_InternalSupplyRequestProcurement
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService
		|	AND ItemList.InternalSupplyRequestExists
		|	AND NOT ItemList.UseGoodsReceipt";

EndFunction

Function R4033B_GoodsReceiptSchedule()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.PurchaseOrder AS Basis,
		|	*
		|INTO R4033B_GoodsReceiptSchedule
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService
		|	AND NOT ItemList.UseGoodsReceipt
		|	AND ItemList.PurchaseOrderExists
		|	AND ItemList.PurchaseOrder.UseItemsReceiptScheduling";

EndFunction

Function R4050B_StockInventory()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	*
		|INTO R4050B_StockInventory
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService";

EndFunction

Function R5010B_ReconciliationStatement()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.Company AS Company,
		|	ItemList.LegalName AS LegalName,
		|	ItemList.Currency AS Currency,
		|	SUM(ItemList.Amount) AS Amount,
		|	ItemList.Period
		|INTO R5010B_ReconciliationStatement
		|FROM
		|	ItemList AS ItemList
		|GROUP BY
		|	ItemList.Company,
		|	ItemList.LegalName,
		|	ItemList.Currency,
		|	ItemList.Period";
EndFunction

Function R4035B_IncomingStocks()
	Return
		"SELECT *
		|INTO R4035B_IncomingStocks
		|FROM 
		|	IncomingStocks AS IncomingStocks";
EndFunction

Function R4036B_IncomingStocksRequested()
	Return
		"SELECT *
		|INTO R4036B_IncomingStocksRequested
		|FROM
		|	IncomingStocksRequested AS IncomingStocksRequested";
EndFunction	

Function R4012B_StockReservation()
	Return
		"SELECT 
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	IncomingStocksRequested.IncomingStore AS Store,
		|	IncomingStocksRequested.Requester AS Order,
		|*
		|INTO R4012B_StockReservation
		|FROM 
		|	IncomingStocksRequested AS IncomingStocksRequested";	
EndFunction
	
#EndRegion
