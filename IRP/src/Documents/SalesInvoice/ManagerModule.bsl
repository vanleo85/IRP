#Region Posting

Function PostingGetDocumentDataTables(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	
	Tables = New Structure();
	
	QueryArray = GetQueryTextsSecondaryTables();
	Parameters.Insert("QueryParameters", GetAdditionalQueryParamenters(Ref));
	PostingServer.ExecuteQuery(Ref, QueryArray, Parameters);
	
	Tables.Insert("CustomersTransactions", 
	PostingServer.GetQueryTableByName("CustomersTransactions", Parameters));	
		
	Return Tables;
EndFunction

Function PostingGetLockDataSource(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	Tables = Parameters.DocumentDataTables;
	DataMapWithLockFields = New Map();
	
	PostingServer.SetLockDataSource(DataMapWithLockFields, 
		AccumulationRegisters.R2020B_AdvancesFromCustomers, 
		Tables.CustomersTransactions);
	
	Return DataMapWithLockFields;
EndFunction

Procedure PostingCheckBeforeWrite(Ref, Cancel, PostingMode, Parameters, AddInfo = Undefined) Export
	
	Tables = Parameters.DocumentDataTables;
	
	OffsetOfPartnersServer.Customers_OnTransaction(Parameters);
	
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
	
	If Not Cancel And Ref.Agreement.UseCreditLimit Then
		CheckCreditLimits(Ref, Cancel, Parameters, AddInfo);
	EndIf;
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
	AccReg = AccumulationRegisters;
	
	Parameters.Insert("RecordType", AccumulationRecordType.Expense);
	PostingServer.CheckBalance_AfterWrite(Ref, Cancel, Parameters, "Document.SalesInvoice.ItemList", AddInfo);
		
	LineNumberAndRowKeyFromItemList = PostingServer.GetLineNumberAndRowKeyFromItemList(Ref, "Document.SalesInvoice.ItemList");
EndProcedure

Procedure CheckCreditLimits(Ref, Cancel, Parameters, AddInfo)
	Query = New Query();
	Query.TempTablesManager = New TempTablesManager();
	Query.Text = 
	"SELECT
	|	PartnerArTransactions.Company,
	|	PartnerArTransactions.Partner,
	|	PartnerArTransactions.Agreement,
	|	&CurrencyMovementType AS CurrencyMovementType
	|INTO PartnerArTransactions
	|FROM
	|	&PartnerArTransactions AS PartnerArTransactions
	|;
	|
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccRegPartnerArTransactions.Company,
	|	AccRegPartnerArTransactions.Partner,
	|	AccRegPartnerArTransactions.Agreement,
	|	AccRegPartnerArTransactions.CurrencyMovementType,
	|	AccRegPartnerArTransactions.Amount
	|INTO AccRegAccRegPartnerArTransactions
	|FROM
	|	AccumulationRegister.PartnerArTransactions AS AccRegPartnerArTransactions
	|		INNER JOIN PartnerArTransactions AS PartnerArTransactions
	|		ON AccRegPartnerArTransactions.Company = PartnerArTransactions.Company
	|		AND AccRegPartnerArTransactions.Partner = PartnerArTransactions.Partner
	|		AND AccRegPartnerArTransactions.Agreement = PartnerArTransactions.Agreement
	|		AND AccRegPartnerArTransactions.CurrencyMovementType = PartnerArTransactions.CurrencyMovementType
	|		AND AccRegPartnerArTransactions.Recorder = &Ref
	|		AND AccRegPartnerArTransactions.RecordType = VALUE(AccumulationRecordType.Receipt)
	|;
	|
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PartnerArTransactionsBalance.Company AS Company,
	|	PartnerArTransactionsBalance.Partner AS Partner,
	|	PartnerArTransactionsBalance.Agreement AS Agreement,
	|	PartnerArTransactionsBalance.CurrencyMovementType AS CurrencyMovementType,
	|	PartnerArTransactionsBalance.Currency AS Currency,
	|	PartnerArTransactionsBalance.AmountBalance AS AmountBalance,
	|	PartnerArTransactionsBalance.Agreement.CreditLimitAmount AS CreditLimitAmount,
	|	AccRegAccRegPartnerArTransactions.Amount AS TransactionAmount
	|FROM
	|	AccumulationRegister.PartnerArTransactions.Balance(&BoundaryIncluding, (Company, Partner, Agreement,
	|		CurrencyMovementType) IN
	|		(SELECT
	|			PartnerArTransactions.Company,
	|			PartnerArTransactions.Partner,
	|			PartnerArTransactions.Agreement,
	|			&CurrencyMovementType
	|		FROM
	|			PartnerArTransactions AS PartnerArTransactions)) AS PartnerArTransactionsBalance
	|		LEFT JOIN PartnerArTransactions AS PartnerArTransactions
	|		ON PartnerArTransactionsBalance.Company = PartnerArTransactions.Company
	|		AND PartnerArTransactionsBalance.Partner = PartnerArTransactions.Partner
	|		AND PartnerArTransactionsBalance.Agreement = PartnerArTransactions.Agreement
	|		AND PartnerArTransactionsBalance.CurrencyMovementType = PartnerArTransactions.CurrencyMovementType
	|		LEFT JOIN AccRegAccRegPartnerArTransactions AS AccRegAccRegPartnerArTransactions
	|		ON PartnerArTransactionsBalance.Company = AccRegAccRegPartnerArTransactions.Company
	|		AND PartnerArTransactionsBalance.Partner = AccRegAccRegPartnerArTransactions.Partner
	|		AND PartnerArTransactionsBalance.Agreement = AccRegAccRegPartnerArTransactions.Agreement
	|		AND PartnerArTransactionsBalance.CurrencyMovementType = AccRegAccRegPartnerArTransactions.CurrencyMovementType
	|WHERE
	|	PartnerArTransactionsBalance.AmountBalance > PartnerArTransactionsBalance.Agreement.CreditLimitAmount";
	Query.SetParameter("BoundaryIncluding"     , New Boundary(Parameters.PointInTime, BoundaryType.Including));
	Query.SetParameter("CurrencyMovementType"  , Ref.Agreement.CurrencyMovementType);
	Query.SetParameter("PartnerArTransactions" , Parameters.DocumentDataTables.PartnerArTransactions);
	Query.SetParameter("Ref"                   , Ref);
	QueryResult = Query.Execute();
	QuerySelection = QueryResult.Select();
	While QuerySelection.Next() Do
		Cancel = True;
		CommonFunctionsClientServer.ShowUsersMessage(
		StrTemplate(R().Error_085, 
		Format(QuerySelection.CreditLimitAmount, "NFD=2;"), 
		Format(QuerySelection.CreditLimitAmount - QuerySelection.AmountBalance + QuerySelection.TransactionAmount, "NFD=2;"), 
		Format(QuerySelection.TransactionAmount, "NFD=2;"), 
		Format(QuerySelection.AmountBalance - QuerySelection.CreditLimitAmount, "NFD=2;"),
		QuerySelection.Currency));
	EndDo;
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
	StrParams.Insert("BalancePeriod", New Boundary(Ref.PointInTime(), BoundaryType.Excluding));
	Return StrParams;
EndFunction

Function GetQueryTextsSecondaryTables()
	QueryArray = New Array;
	QueryArray.Add(ItemList());
	QueryArray.Add(OffersInfo());
	QueryArray.Add(ShipmentConfirmationsInfo());
	QueryArray.Add(Taxes());
	QueryArray.Add(CustomersTransactions());
	QueryArray.Add(Aging());
	QueryArray.Add(SerialLotNumbers());
	Return QueryArray;
EndFunction

Function GetQueryTextsMasterTables()
	QueryArray = New Array;
	QueryArray.Add(R2001T_Sales());	
	QueryArray.Add(R2005T_SalesSpecialOffers());
	QueryArray.Add(R2011B_SalesOrdersShipment());
	QueryArray.Add(R2012B_SalesOrdersInvoiceClosing());
	QueryArray.Add(R2013T_SalesOrdersProcurement());
	QueryArray.Add(R2031B_ShipmentInvoicing());
	QueryArray.Add(R2040B_TaxesIncoming());
	QueryArray.Add(R4010B_ActualStocks());
	QueryArray.Add(R4011B_FreeStocks());
	QueryArray.Add(R4012B_StockReservation());
	QueryArray.Add(R4014B_SerialLotNumber());
	QueryArray.Add(R4034B_GoodsShipmentSchedule());
	QueryArray.Add(R4050B_StockInventory());
	QueryArray.Add(R2021B_CustomersTransactions());
	QueryArray.Add(R2020B_AdvancesFromCustomers());
	QueryArray.Add(R5011B_PartnersAging());
	QueryArray.Add(R5010B_ReconciliationStatement());
	Return QueryArray;
EndFunction

Function ItemList()
	Return
		"SELECT
		|	ShipmentConfirmations.Key AS Key
		|INTO ShipmentConfirmations
		|FROM
		|	Document.SalesInvoice.ShipmentConfirmations AS ShipmentConfirmations
		|WHERE
		|	ShipmentConfirmations.Ref = &Ref
		|GROUP BY
		|	ShipmentConfirmations.Key
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesInvoiceItemList.Ref.Company AS Company,
		|	SalesInvoiceItemList.Store AS Store,
		|	NOT ShipmentConfirmations.Key IS NULL AS ShipmentConfirmationExists,
		|	SalesInvoiceItemList.Ref AS Invoice,
		|	SalesInvoiceItemList.ItemKey AS ItemKey,
		|	SalesInvoiceItemList.Quantity AS UnitQuantity,
		|	SalesInvoiceItemList.QuantityInBaseUnit AS Quantity,
		|	SalesInvoiceItemList.TotalAmount AS Amount,
		|	SalesInvoiceItemList.Ref.Partner AS Partner,
		|	SalesInvoiceItemList.Ref.LegalName AS LegalName,
		|	CASE
		|		WHEN SalesInvoiceItemList.Ref.Agreement.Kind = VALUE(Enum.AgreementKinds.Regular)
		|		AND SalesInvoiceItemList.Ref.Agreement.ApArPostingDetail = VALUE(Enum.ApArPostingDetail.ByStandardAgreement)
		|			THEN SalesInvoiceItemList.Ref.Agreement.StandardAgreement
		|		ELSE SalesInvoiceItemList.Ref.Agreement
		|	END AS Agreement,
		|	SalesInvoiceItemList.Ref.Currency AS Currency,
		|	SalesInvoiceItemList.Unit AS Unit,
		|	SalesInvoiceItemList.Ref.Date AS Period,
		|	SalesInvoiceItemList.SalesOrder AS SalesOrder,
		|	NOT SalesInvoiceItemList.SalesOrder.Ref IS NULL AS SalesOrderExists,
		|	SalesInvoiceItemList.Key AS RowKey,
		|	SalesInvoiceItemList.DeliveryDate AS DeliveryDate,
		|	SalesInvoiceItemList.ItemKey.Item.ItemType.Type = VALUE(Enum.ItemTypes.Service) AS IsService,
		|	SalesInvoiceItemList.BusinessUnit AS BusinessUnit,
		|	SalesInvoiceItemList.RevenueType AS RevenueType,
		|	SalesInvoiceItemList.AdditionalAnalytic AS AdditionalAnalytic,
		|	CASE
		|		WHEN SalesInvoiceItemList.Ref.Agreement.ApArPostingDetail = VALUE(Enum.ApArPostingDetail.ByDocuments)
		|			THEN SalesInvoiceItemList.Ref
		|		ELSE UNDEFINED
		|	END AS BasisDocument,
		|	SalesInvoiceItemList.NetAmount AS NetAmount,
		|	SalesInvoiceItemList.OffersAmount AS OffersAmount,
		|	SalesInvoiceItemList.UseShipmentConfirmation AS UseShipmentConfirmation
		|INTO ItemList
		|FROM
		|	Document.SalesInvoice.ItemList AS SalesInvoiceItemList
		|		LEFT JOIN ShipmentConfirmations AS ShipmentConfirmations
		|		ON SalesInvoiceItemList.Key = ShipmentConfirmations.Key
		|WHERE
		|	SalesInvoiceItemList.Ref = &Ref";
EndFunction

Function OffersInfo()
	Return
		"SELECT
		|	SalesInvoiceItemList.Ref.Date AS Period,
		|	SalesInvoiceItemList.Ref AS Invoice,
		|	SalesInvoiceItemList.Key AS RowKey,
		|	SalesInvoiceItemList.ItemKey,
		|	SalesInvoiceItemList.Ref.Company AS Company,
		|	SalesInvoiceItemList.Ref.Currency,
		|	SalesInvoiceSpecialOffers.Offer AS SpecialOffer,
		|	SalesInvoiceSpecialOffers.Amount AS OffersAmount,
		|	SalesInvoiceItemList.TotalAmount AS SalesAmount,
		|	SalesInvoiceItemList.NetAmount
		|INTO OffersInfo
		|FROM
		|	Document.SalesInvoice.ItemList AS SalesInvoiceItemList
		|		INNER JOIN Document.SalesInvoice.SpecialOffers AS SalesInvoiceSpecialOffers
		|		ON SalesInvoiceItemList.Key = SalesInvoiceSpecialOffers.Key
		|		AND SalesInvoiceItemList.Ref = &Ref
		|		AND SalesInvoiceSpecialOffers.Ref = &Ref";
EndFunction

Function ShipmentConfirmationsInfo()
	Return
		"SELECT
		|	SalesInvoiceShipmentConfirmations.Key,
		|	SalesInvoiceShipmentConfirmations.ShipmentConfirmation,
		|	SalesInvoiceShipmentConfirmations.Quantity,
		|	SalesInvoiceShipmentConfirmations.QuantityInShipmentConfirmation
		|INTO ShipmentConfirmationsInfo
		|FROM
		|	Document.SalesInvoice.ShipmentConfirmations AS SalesInvoiceShipmentConfirmations
		|WHERE
		|	SalesInvoiceShipmentConfirmations.Ref = &Ref";
EndFunction

Function Taxes()
	Return
		"SELECT
		|	SalesInvoiceTaxList.Ref.Date AS Period,
		|	SalesInvoiceTaxList.Ref.Company AS Company,
		|	SalesInvoiceTaxList.Tax AS Tax,
		|	SalesInvoiceTaxList.TaxRate AS TaxRate,
		|	CASE
		|		WHEN SalesInvoiceTaxList.ManualAmount = 0
		|			THEN SalesInvoiceTaxList.Amount
		|		ELSE SalesInvoiceTaxList.ManualAmount
		|	END AS TaxAmount,
		|	SalesInvoiceItemList.NetAmount AS TaxableAmount
		|INTO Taxes
		|FROM
		|	Document.SalesInvoice.ItemList AS SalesInvoiceItemList
		|		INNER JOIN Document.SalesInvoice.TaxList AS SalesInvoiceTaxList
		|		ON SalesInvoiceItemList.Key = SalesInvoiceTaxList.Key
		|		AND SalesInvoiceItemList.Ref = &Ref
		|		AND SalesInvoiceTaxList.Ref = &Ref";
EndFunction

Function CustomersTransactions()
	Return
		"SELECT
		|	ItemList.Period,
		|	ItemList.Company,
		|	ItemList.Currency,
		|	ItemList.LegalName,
		|	ItemList.Partner,
		|	ItemList.BasisDocument AS TransactionDocument,
		|	ItemList.Agreement,
		|	SUM(ItemList.Amount) AS DocumentAmount
		|INTO CustomersTransactions
		|FROM
		|	ItemList AS ItemList
		|GROUP BY
		|	ItemList.Period,
		|	ItemList.Company,
		|	ItemList.LegalName,
		|	ItemList.Partner,
		|	ItemList.BasisDocument,
		|	ItemList.Agreement,
		|	ItemList.Currency";
EndFunction

Function Aging()
	Return
		"SELECT
		|	SalesInvoicePaymentTerms.Date AS PaymentDate,
		|	SalesInvoicePaymentTerms.Ref.Date AS Period,
		|	SUM(SalesInvoicePaymentTerms.Amount) AS Amount,
		|	SalesInvoicePaymentTerms.Ref.Company AS Company,
		|	SalesInvoicePaymentTerms.Ref.Partner AS Partner,
		|	SalesInvoicePaymentTerms.Ref.Agreement AS Agreement,
		|	SalesInvoicePaymentTerms.Ref.Currency AS Currency,
		|	SalesInvoicePaymentTerms.Ref AS Invoice
		|INTO Aging
		|FROM
		|	Document.SalesInvoice.PaymentTerms AS SalesInvoicePaymentTerms
		|WHERE
		|	SalesInvoicePaymentTerms.Ref = &Ref
		|GROUP BY
		|	SalesInvoicePaymentTerms.Date,
		|	SalesInvoicePaymentTerms.Ref.Company,
		|	SalesInvoicePaymentTerms.Ref.Partner,
		|	SalesInvoicePaymentTerms.Ref.Agreement,
		|	SalesInvoicePaymentTerms.Ref.Currency,
		|	SalesInvoicePaymentTerms.Ref.Date,
		|	SalesInvoicePaymentTerms.Ref";	
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
		|	Document.SalesInvoice.SerialLotNumbers AS SerialLotNumbers
		|		LEFT JOIN Document.SalesInvoice.ItemList AS ItemList
		|		ON SerialLotNumbers.Key = ItemList.Key
		|WHERE
		|	SerialLotNumbers.Ref = &Ref";	
EndFunction	

Function R2001T_Sales()
	Return
		"SELECT *
		|INTO R2001T_Sales
		|FROM
		|	ItemList AS ItemList
		|WHERE TRUE";

EndFunction

Function R2005T_SalesSpecialOffers()
	Return
		"SELECT *
		|INTO R2005T_SalesSpecialOffers
		|FROM
		|	OffersInfo AS OffersInfo
		|WHERE TRUE";

EndFunction

Function R2011B_SalesOrdersShipment()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.SalesOrder AS Order,
		|	*
		|INTO R2011B_SalesOrdersShipment
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService
		|	AND NOT ItemList.UseShipmentConfirmation
		|	AND ItemList.SalesOrderExists";

EndFunction

Function R2012B_SalesOrdersInvoiceClosing()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.SalesOrder AS Order,
		|	*
		|INTO R2012B_SalesOrdersInvoiceClosing
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	ItemList.SalesOrderExists";

EndFunction

Function R2013T_SalesOrdersProcurement()
	Return
		"SELECT
		|	ItemList.Quantity AS SalesQuantity,
		|	ItemList.SalesOrder AS Order,
		|	*
		|INTO R2013T_SalesOrdersProcurement
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService
		|	AND ItemList.SalesOrderExists";

EndFunction

Function R2031B_ShipmentInvoicing()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	ItemList.Invoice AS Basis,
		|	ItemList.Quantity AS Quantity,
		|	ItemList.Company,
		|	ItemList.Period,
		|	ItemList.ItemKey,
		|	ItemList.Store
		|INTO R2031B_ShipmentInvoicing
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	ItemList.UseShipmentConfirmation
		|	AND NOT ItemList.ShipmentConfirmationExists
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(AccumulationRecordType.Expense),
		|	ShipmentConfirmations.ShipmentConfirmation,
		|	ShipmentConfirmations.Quantity,
		|	ItemList.Company,
		|	ItemList.Period,
		|	ItemList.ItemKey,
		|	ItemList.Store
		|FROM
		|	ItemList AS ItemList
		|		INNER JOIN ShipmentConfirmationsInfo AS ShipmentConfirmations
		|		ON ItemList.RowKey = ShipmentConfirmations.Key
		|WHERE
		|	TRUE";

EndFunction

Function R2040B_TaxesIncoming()
	Return
		"SELECT 
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|*
		|INTO R2040B_TaxesIncoming
		|FROM
		|	Taxes AS Taxes
		|WHERE TRUE";

EndFunction

Function R4010B_ActualStocks()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.Period,
		|	ItemList.Store,
		|	ItemList.ItemKey,
		|	ItemList.Quantity
		|INTO R4010B_ActualStocks
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService
		|	AND NOT ItemList.UseShipmentConfirmation";
EndFunction

Function R4011B_FreeStocks()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.Period,
		|	ItemList.Store,
		|	ItemList.ItemKey,
		|	ItemList.Quantity - ISNULL(StockReservation.QuantityBalance, 0) AS Quantity
		|INTO R4011B_FreeStocks
		|FROM
		|	ItemList AS ItemList
		|		LEFT JOIN AccumulationRegister.R4012B_StockReservation.Balance(&BalancePeriod, (Store, ItemKey, Order) IN
		|			(SELECT
		|				ItemList.Store,
		|				ItemList.ItemKey,
		|				ItemList.SalesOrder
		|			FROM
		|				ItemList AS ItemList)) AS StockReservation
		|		ON ItemList.SalesOrder = StockReservation.Order
		|		AND ItemList.ItemKey = StockReservation.ItemKey
		|		AND ItemList.Store = StockReservation.Store
		|WHERE
		|	NOT ItemList.IsService
		|	AND (ItemList.Quantity - ISNULL(StockReservation.QuantityBalance, 0)) <> 0";
EndFunction

Function R4012B_StockReservation()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.Period AS Period,
		|	ItemList.SalesOrder AS Order,
		|	ItemList.ItemKey AS ItemKey,
		|	ItemList.Store AS Store,
		|	CASE
		|		WHEN StockReservation.QuantityBalance > ItemList.Quantity
		|			THEN ItemList.Quantity
		|		ELSE StockReservation.QuantityBalance
		|	END AS Quantity
		|INTO R4012B_StockReservation
		|FROM
		|	ItemList AS ItemList
		|		INNER JOIN AccumulationRegister.R4012B_StockReservation.Balance(&BalancePeriod, (Store, ItemKey, Order) IN
		|			(SELECT
		|				ItemList.Store,
		|				ItemList.ItemKey,
		|				ItemList.SalesOrder
		|			FROM
		|				ItemList AS ItemList)) AS StockReservation
		|		ON ItemList.SalesOrder = StockReservation.Order
		|		AND ItemList.ItemKey = StockReservation.ItemKey
		|		AND ItemList.Store = StockReservation.Store";
EndFunction

Function R4014B_SerialLotNumber()
	Return
		"SELECT 
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|*
		|INTO R4014B_SerialLotNumber
		|FROM
		|	SerialLotNumbers AS SerialLotNumbers
		|WHERE 
		|	TRUE";

EndFunction

Function R4034B_GoodsShipmentSchedule()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	ItemList.SalesOrder AS Basis,
		|	*
		|INTO R4034B_GoodsShipmentSchedule
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService
		|	AND NOT ItemList.UseShipmentConfirmation
		|	AND ItemList.SalesOrderExists
		|	AND ItemList.SalesOrder.UseItemsShipmentScheduling";

EndFunction

Function R4050B_StockInventory()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	*
		|INTO R4050B_StockInventory
		|FROM
		|	ItemList AS ItemList
		|WHERE
		|	NOT ItemList.IsService";

EndFunction

Function R2020B_AdvancesFromCustomers()
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
		|INTO R2020B_AdvancesFromCustomers
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

Function R2021B_CustomersTransactions()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	CustomersTransactions.Period,
		|	CustomersTransactions.Company,
		|	CustomersTransactions.Currency,
		|	CustomersTransactions.LegalName,
		|	CustomersTransactions.Partner,
		|	CustomersTransactions.Agreement,
		|	CustomersTransactions.TransactionDocument AS Basis,
		|	SUM(CustomersTransactions.DocumentAmount) AS Amount
		|INTO R2021B_CustomersTransactions
		|FROM
		|	CustomersTransactions AS CustomersTransactions
		|GROUP BY
		|	CustomersTransactions.Period,
		|	CustomersTransactions.Company,
		|	CustomersTransactions.Currency,
		|	CustomersTransactions.LegalName,
		|	CustomersTransactions.Partner,
		|	CustomersTransactions.Agreement,
		|	CustomersTransactions.TransactionDocument,
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

Function R5011B_PartnersAging()
	Return 
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	Aging.Period,
		|	Aging.Company,
		|	Aging.Currency,
		|	Aging.Agreement,
		|	Aging.Partner,
		|	Aging.Invoice,
		|	Aging.PaymentDate,
		|	Aging.Amount
		|INTO R5011B_PartnersAging
		|FROM
		|	Aging AS Aging
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(AccumulationRecordType.Expense),
		|	OffsetOfAging.Period,
		|	OffsetOfAging.Company,
		|	OffsetOfAging.Currency,
		|	OffsetOfAging.Agreement,
		|	OffsetOfAging.Partner,
		|	OffsetOfAging.Invoice,
		|	OffsetOfAging.PaymentDate,
		|	OffsetOfAging.Amount
		|FROM
		|	OffsetOfAging AS OffsetOfAging";
EndFunction

Function R5010B_ReconciliationStatement()
	Return
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	ItemList.Company,
		|	ItemList.LegalName,
		|	ItemList.Currency,
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

#EndRegion