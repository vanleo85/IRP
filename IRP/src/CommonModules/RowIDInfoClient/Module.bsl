
Function GetSelectedRowInfo(CurrentData) Export
	Result = New Structure("SelectedRow, FilterBySelectedRow", Undefined, Undefined);
	If CurrentData = Undefined Then
		Return Result;
	EndIf;
	
	Result.SelectedRow = New Structure();
	Result.SelectedRow.Insert("Item   "  , CurrentData.Item);
	Result.SelectedRow.Insert("ItemKey"  , CurrentData.ItemKey);
	Result.SelectedRow.Insert("Store"    , CurrentData.Store);
	Result.SelectedRow.Insert("Unit"     , CurrentData.Unit);
	Result.SelectedRow.Insert("Quantity" , CurrentData.Quantity);
		
	Result.FilterBySelectedRow = New Structure();
	Result.FilterBySelectedRow.Insert("ItemKey"  , CurrentData.ItemKey);
	Result.FilterBySelectedRow.Insert("Store"    , CurrentData.Store);		
	Return Result;
EndFunction

Function GetExistingRowsInfo(ItemList) Export
	ExistingRows = New Array();
	For Each Row In ItemList Do
		NewRow = New Structure();
		NewRow.Insert("Key"      , Row.Key);
		NewRow.Insert("Item"     , Row.Item); 
		NewRow.Insert("ItemKey"  , Row.ItemKey); 
		NewRow.Insert("Unit"     , Row.Unit);
		NewRow.Insert("Store"    , Row.Store);
		NewRow.Insert("Quantity" , Row.Quantity);
		ExistingRows.Add(NewRow);
	EndDo;	
	Return ExistingRows;
EndFunction

Function FindRowInTree(Filter, Tree) Export
	RowID = Undefined;
	FindRowInTreeRecursive(Filter, Tree.GetItems(), RowID);
	Return RowID;
EndFunction

Procedure FindRowInTreeRecursive(Filter, TreeRows, RowID)
	For Each Row In TreeRows Do
		If RowID <> Undefined Then
			Return;
		EndIf;
		Founded = True;
		For Each ItemOfFilter In Filter Do
			If Row[ItemOfFilter.Key] <> Filter[ItemOfFilter.Key] Then
				Founded = False;
				Break;
			EndIf;
		EndDo;
		If Founded Then
			RowID = Row.GetID();
		EndIf;
		If RowID = Undefined Then
			FindRowInTreeRecursive(Filter, Row.GetItems(), RowID);
		EndIf;
	EndDo;
EndProcedure

Procedure ExpandTree(Tree, TreeRows) Export
	For Each ItemTreeRows In TreeRows Do
		Tree.Expand(ItemTreeRows.GetID());
	EndDo;
EndProcedure
