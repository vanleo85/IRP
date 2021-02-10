
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ThisObject.Filter = Parameters.Filter;
	
	For Each Row In Parameters.ExistingRows Do
		NewRow = ThisObject.ExistingRows.Add();
		NewRow.Item     = Row.ItemKey.Item;
		NewRow.ItemKey  = Row.ItemKey;
		NewRow.Unit     = Row.Unit;
		NewRow.Quantity = Row.Quantity;
	EndDo;
		
	FillDocumentsTree(Parameters.FilterBySelectedRow);
EndProcedure


&AtServer
Procedure FillDocumentsTree(FilterBySelectedRow);

	FullFilter = New Structure();
	For Each KeyValue In ThisObject.Filter Do
		FullFilter.Insert(KeyValue)
	EndDo;
//
//QueryTable = RowIDInfo.GetSalesOrdersInfoForSalesInvoice(FilterValues);
//	
//	OrdersTable = QueryTable.Copy( , "SalesOrder");
//	OrdersTable.GroupBy("SalesOrder");
//	
//	For Each Row_Order In OrdersTable Do
//		
//		NewRow_Order = ThisObject.DocumentsTree.GetItems().Add();
//		NewRow_Order.SalesOrder = Row_Order.SalesOrder;
//		
//		OrdersItemsArray = QueryTable.FindRows(New Structure("SalesOrder", Row_Order.SalesOrder));
//		For Each Row_Item In OrdersItemsArray Do
//			
//			// exclude quantity from existing rows
//			ExistingQuantity = 0;
//			For i = 0 To ExistingRows.UBound() Do
//				If i > ExistingRows.UBound() Then
//					Break;
//				EndIf;
//				
//				ExistingRow = ExistingRows[i];
//				If ExistingRow.Key = Row_Item.Key Then
//					UnitFactorFrom = Catalogs.Units.GetUnitFactor(ExistingRow.Unit, Row_Item.QuantityUnit);
//					UnitFactorTo = Catalogs.Units.GetUnitFactor(Row_Item.Unit, Row_Item.QuantityUnit);
//					PreviousExistingQuantity = ExistingQuantity;
//					ExistingQuantity = Min(ExistingQuantity + ?(UnitFactorTo = 0, 
//																0, 
//																ExistingRow.Quantity * UnitFactorFrom / UnitFactorTo),
//										 Row_Item.Quantity);
//					ExistingRow.Quantity = ExistingRow.Quantity 
//							- ?(UnitFactorFrom = 0, 
//								0, 
//								(PreviousExistingQuantity - ExistingQuantity) / UnitFactorFrom * UnitFactorTo);
//					If ExistingRow.Quantity <= 0 Then
//						ExistingRows.Delete(i);
//						i = i - 1;
//					EndIf;
//				EndIf;
//			EndDo;
//			
//			If ExistingQuantity < Row_Item.Quantity Then
//				NewRow_Item = NewRow_Order.GetItems().Add();
//				FillPropertyValues(NewRow_Item, Row_Item);
//				NewRow_Item.Quantity = NewRow_Item.Quantity - ExistingQuantity;
//			EndIf;
//		EndDo;
//		
//		If Not NewRow_Order.GetItems().Count() Then
//			DocumentsTree.GetItems().Delete(NewRow_Order);
//		EndIf;
//	EndDo;

EndProcedure