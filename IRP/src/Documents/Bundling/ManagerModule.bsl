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
	Return;
EndProcedure

#EndRegion

#Region Specifications

Function FindOrCreateSpecificationByProperties(Ref, AddInfo = Undefined) Export
	Query = New Query();
	Query.Text =
		"SELECT
		|	BundlingItemList.Key,
		|	BundlingItemList.ItemKey.Item AS Item,
		|	ItemKeysAddAttributes.Property AS Attribute,
		|	ItemKeysAddAttributes.Value
		|FROM
		|	Catalog.ItemKeys.AddAttributes AS ItemKeysAddAttributes
		|		INNER JOIN Document.Bundling.ItemList AS BundlingItemList
		|		ON BundlingItemList.ItemKey = ItemKeysAddAttributes.Ref
		|		AND BundlingItemList.Ref = &Ref
		|GROUP BY
		|	BundlingItemList.ItemKey.Item,
		|	ItemKeysAddAttributes.Property,
		|	ItemKeysAddAttributes.Value,
		|	BundlingItemList.Key
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BundlingItemList.Key,
		|	BundlingItemList.ItemKey.Item AS Item,
		|	SUM(BundlingItemList.Quantity) AS Quantity
		|FROM
		|	Document.Bundling.ItemList AS BundlingItemList
		|WHERE
		|	BundlingItemList.Ref = &Ref
		|GROUP BY
		|	BundlingItemList.ItemKey.Item,
		|	BundlingItemList.Key";
	Query.SetParameter("Ref", Ref);
	ArrayOfQueryResults = Query.ExecuteBatch();
	
	ArrayOfSpecifications = Catalogs.Specifications.FindOrCreateRefByProperties(ArrayOfQueryResults[0].Unload()
			, ArrayOfQueryResults[1].Unload()
			, Ref.ItemBundle
			, AddInfo);
	If ArrayOfSpecifications.Count() Then
		Return ArrayOfSpecifications[0];
	Else
		Return Catalogs.Specifications.EmptyRef();
	EndIf;
EndFunction

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

	Return QueryArray;
EndFunction

Function GetQueryTextsMasterTables()
	QueryArray = New Array;

	Return QueryArray;
EndFunction

#EndRegion
