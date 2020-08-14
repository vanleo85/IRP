
Function RestoreFillingData(Val FillingData) Export
	If Not ValueIsFilled(FillingData) Then
		Return Undefined;
	EndIf;
	Return CommonFunctionsServer.DeserializeXMLUseXDTO(FillingData);
EndFunction

Function QuerySearchInputByString(Settings) Export
	QueryText = 
		"SELECT ALLOWED TOP 10
		|	Table.Ref AS Ref,
		|	Table.Presentation AS Presentation,
		|	0 AS Sort
		|INTO TempVT
		|FROM
		|	%1 AS Table
		|WHERE
		|	Table.Description_en LIKE &SearchString + ""%%""
		| %2
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 10
		|	Table.Ref AS Ref,
		|	Table.Presentation AS Presentation,
		|	1 AS Sort
		|INTO TempVTSecond
		|FROM
		|	%1 AS Table
		|WHERE
		|	Table.Description_en LIKE ""%%"" + &SearchString + ""%%""
		|	AND NOT Table.Ref IN
		|				(SELECT
		|					T.Ref
		|				FROM
		|					TempVT AS T)
		| %2
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 10
		|	TempVT.Ref AS Ref,
		|	TempVT.Presentation AS Presentation,
		|	TempVT.Sort AS Sort
		|FROM
		|	TempVT AS TempVT
		|
		|UNION
		|
		|SELECT TOP 10
		|	TempVTSecond.Ref,
		|	TempVTSecond.Presentation,
		|	TempVTSecond.Sort
		|FROM
		|	TempVTSecond AS TempVTSecond
		|
		|ORDER BY
		|	Sort,
		|	Presentation";
	
	Text = StrTemplate(QueryText, Settings.Name, Settings.Filter);
	
	Return LocalizationEvents.ReplaceDescriptionLocalizationPrefix(Text);;	
EndFunction