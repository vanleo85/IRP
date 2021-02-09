&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("FilterValues") Then
		FillDocumentsTree(Parameters.FilterValues, Parameters.ExistingRows);
	Else
		Cancel = True;
	EndIf;
	SetConditionalAppearance();
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	ConditionalAppearance.Items.Clear();
	
	AppearanceElement = ConditionalAppearance.Items.Add();
	
	FieldElement = AppearanceElement.Fields.Items.Add();
	FieldElement.Field = New DataCompositionField(Items.DocumentsTreeSalesOrder.Name);
	
	FilterElement = AppearanceElement.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("DocumentsTree.ItemKey");
	FilterElement.ComparisonType = DataCompositionComparisonType.Filled;
	
	AppearanceElement.Appearance.SetParameterValue("Text", "");
EndProcedure

&AtServer
Procedure FillDocumentsTree(FilterValues, ExistingRows)
	ThisObject.DocumentsTree.GetItems().Clear();
	QueryTable = RowIDInfo.GetSalesOrdersInfoForSalesInvoice(FilterValues);
	
	OrdersTable = QueryTable.Copy( , "SalesOrder");
	OrdersTable.GroupBy("SalesOrder");
	
	For Each Row_Order In OrdersTable Do
		
		NewRow_Order = ThisObject.DocumentsTree.GetItems().Add();
		NewRow_Order.SalesOrder = Row_Order.SalesOrder;
		
		OrdersItemsArray = QueryTable.FindRows(New Structure("SalesOrder", Row_Order.SalesOrder));
		For Each Row_Item In OrdersItemsArray Do
			
			// exclude quantity from existing rows
			ExistingQuantity = 0;
			For i = 0 To ExistingRows.UBound() Do
				If i > ExistingRows.UBound() Then
					Break;
				EndIf;
				
				ExistingRow = ExistingRows[i];
				If ExistingRow.Key = Row_Item.Key Then
					UnitFactorFrom = Catalogs.Units.GetUnitFactor(ExistingRow.Unit, Row_Item.QuantityUnit);
					UnitFactorTo = Catalogs.Units.GetUnitFactor(Row_Item.Unit, Row_Item.QuantityUnit);
					PreviousExistingQuantity = ExistingQuantity;
					ExistingQuantity = Min(ExistingQuantity + ?(UnitFactorTo = 0, 
																0, 
																ExistingRow.Quantity * UnitFactorFrom / UnitFactorTo),
										 Row_Item.Quantity);
					ExistingRow.Quantity = ExistingRow.Quantity 
							- ?(UnitFactorFrom = 0, 
								0, 
								(PreviousExistingQuantity - ExistingQuantity) / UnitFactorFrom * UnitFactorTo);
					If ExistingRow.Quantity <= 0 Then
						ExistingRows.Delete(i);
						i = i - 1;
					EndIf;
				EndIf;
			EndDo;
			
			If ExistingQuantity < Row_Item.Quantity Then
				NewRow_Item = NewRow_Order.GetItems().Add();
				FillPropertyValues(NewRow_Item, Row_Item);
				NewRow_Item.Quantity = NewRow_Item.Quantity - ExistingQuantity;
			EndIf;
		EndDo;
		
		If Not NewRow_Order.GetItems().Count() Then
			DocumentsTree.GetItems().Delete(NewRow_Order);
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
Procedure Ok(Command)
	Close(GetSelectedData());
EndProcedure

&AtServer
Function GetSelectedData()
	Result = New Array();
	For Each Row_Order In ThisObject.DocumentsTree.GetItems() Do
		For Each Row_Item In Row_Order.GetItems() Do
			If Row_Item.Use Then
				RowStructure = New Structure("SalesOrder, 
					|ShipmentConfirmation,
					|Item, 
					|ItemKey, 
					|Key, 
					|Unit, 
					|Quantity,
					|PriceType, 
					|Price,
					|Store, 
					|DeliveryDate");
				FillPropertyValues(RowStructure, Row_Item);
				Result.Add(RowStructure);
			EndIf;
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
	For Each Row_Order In DocumentsTree.GetItems() Do
		Row_Order.Use = UseValue;
		For Each Row_Item In Row_Order.GetItems() Do
			Row_Item.Use = UseValue;
		EndDo;
	EndDo;
EndProcedure

