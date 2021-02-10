&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SelectShipmentBasisMode = Parameters.SelectShipmentBasisMode;
	If Parameters.Property("FilterValues") Then
		FillDocumentsTree(Parameters.FilterValues, Parameters.ExistingRows, Parameters.Ref);
	Else
		Cancel = True;
	EndIf;
	SetConditionalAppearance();
	SetVisibility();
EndProcedure

&AtServer
Procedure SetVisibility()
	Items.FormSelectAll.Visible = Not SelectShipmentBasisMode;
	Items.FormUnselectAll.Visible = Not SelectShipmentBasisMode;
	Items.DocumentsTreeUse.Visible = Not SelectShipmentBasisMode;
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	ConditionalAppearance.Items.Clear();
	
	AppearanceElement = ConditionalAppearance.Items.Add();
	
	FieldElement = AppearanceElement.Fields.Items.Add();
	FieldElement.Field = New DataCompositionField(Items.DocumentsTreeShipmentBasis.Name);
	FieldElement = AppearanceElement.Fields.Items.Add();
	FieldElement.Field = New DataCompositionField(Items.DocumentsTreeCurrency.Name);
	
	FilterElement = AppearanceElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("DocumentsTree.ItemKey");
	FilterElement.ComparisonType = DataCompositionComparisonType.Filled;
	
	AppearanceElement.Appearance.SetParameterValue("Text", "");
EndProcedure

&AtServer
Procedure FillDocumentsTree(FilterValues, ExistingRows, Ref)
	ThisObject.DocumentsTree.GetItems().Clear();


	
	FilterTable = QueryTable.Copy( , "ShipmentBasis");
	FilterTable.GroupBy("ShipmentBasis");
	
	For Each Row_Basis In FilterTable Do
		
		NewRow_Basis = ThisObject.DocumentsTree.GetItems().Add();
		NewRow_Basis.ShipmentBasis = Row_Basis.ShipmentBasis;
		
		BasisItemsArray = QueryTable.FindRows(New Structure("ShipmentBasis", Row_Basis.ShipmentBasis));
		For Each Row_Item In BasisItemsArray Do
			
			// exclude quantity from existing rows
			ExistingQuantity = 0;
			For i = 0 To ExistingRows.UBound() Do
				If i > ExistingRows.UBound() Then
					Break;
				EndIf;
				
				ExistingRow = ExistingRows[i];
				If ExistingRow.Key = Row_Item.Key Then
					UnitFactor = Catalogs.Units.GetUnitFactor(ExistingRow.Unit, Row_Item.Unit);
					ExistingQuantity = Min(ExistingQuantity + ExistingRow.Quantity / UnitFactor, Row_Item.Quantity);
					ExistingRows.Delete(i);
					i = i - 1;
				EndIf;
			EndDo;
			
			If ExistingQuantity < Row_Item.Quantity Then
				NewRow_Item = NewRow_Basis.GetItems().Add();
				FillPropertyValues(NewRow_Item, Row_Item);
				NewRow_Item.Quantity = NewRow_Item.Quantity - ExistingQuantity;
			EndIf;
		EndDo;
		If Not NewRow_Basis.GetItems().Count() Then
			DocumentsTree.GetItems().Delete(NewRow_Basis);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure DocumentsTreeUseOnChange(Item)
	CurrentRow = DocumentsTree.FindByID(Items.DocumentsTree.CurrentRow);
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	For Each Row In CurrentRow.GetItems() Do
		Row.Use = CurrentRow.Use;
		For Each Row_ In Row.GetItems() Do
			Row_.Use = CurrentRow.Use;
		EndDo;
	EndDo;
EndProcedure

&AtClient
Procedure DocumentsTreeBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure DocumentsTreeBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure Command_Ok(Command)
	If SelectShipmentBasisMode Then
		If Items.DocumentsTree.CurrentRow = Undefined Then
			If Not DocumentsTree.GetItems().Count() Then
				Close(Undefined);
			EndIf;
			Return;
		EndIf;
		Row_Item = DocumentsTree.FindByID(Items.DocumentsTree.CurrentRow);
		If Row_Item = Undefined Then
			Close(Undefined);
			Return;
		EndIf;
		If Not ValueIsFilled(Row_Item.ShipmentBasis) Then
			Return;
		EndIf;
		
		Result = New Array();
		RowStructure = New Structure("ShipmentBasis, Store, Item, ItemKey, Key, Unit, Quantity");
		FillPropertyValues(RowStructure, Row_Item);
		Result.Add(RowStructure);
		Close(Result);
	Else
		Close(GetSelectedData());
	EndIf;
EndProcedure

&AtClient
Procedure DocumentsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	Command_Ok(Undefined);
EndProcedure

&AtServer
Function GetSelectedData()
	Result = New Array();
	
	For Each Row_Currency In ThisObject.DocumentsTree.GetItems() Do
		For Each Row_Order In Row_Currency.GetItems() Do
			For Each Row_Item In Row_Order.GetItems() Do
				If Row_Item.Use Then
					RowStructure = New Structure("ShipmentBasis, Store, Item, ItemKey, Key, Unit, Quantity");
					FillPropertyValues(RowStructure, Row_Item);
					Result.Add(RowStructure);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	Return Result;
EndFunction

&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

&AtClient
Procedure SelectAll(Command)
	SetUseValue(True);
EndProcedure

&AtClient
Procedure UnselectAll(Command)
	SetUseValue(False);
EndProcedure

&AtClient
Procedure SetUseValue(UseValue)
	For Each Row_Currency In DocumentsTree.GetItems() Do
		Row_Currency.Use = UseValue;
		For Each Row_Basis In Row_Currency.GetItems() Do
			Row_Basis.Use = UseValue;
			For Each Row_Item In Row_Basis.GetItems() Do
				Row_Item.Use = UseValue;
			EndDo;
		EndDo;
	EndDo;
EndProcedure

