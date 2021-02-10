
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ThisObject.Filter = Parameters.Filter;
	
	For Each Row In Parameters.ExistingRows Do
		FillPropertyValues(ThisObject.ExistingRows.Add(), Row);
	EndDo;
		
	FillDocumentsTree(Parameters.SelectedRow, Parameters.FilterBySelectedRow);
EndProcedure

&AtClient
Procedure ExistingRowsOnActivateRow(Item)
	SelectedRowInfo = RowIDInfoClient.GetSelectedRowInfo(Items.ExistingRows.CurrentData);
	FillDocumentsTree(SelectedRowInfo.SelectedRow, SelectedRowInfo.FilterBySelectedRow);
EndProcedure

&AtServer
Procedure FillDocumentsTree(SelectedRow, FilterBySelectedRow);
	FullFilter = New Structure();
	For Each KeyValue In ThisObject.Filter Do
		FullFilter.Insert(KeyValue.Key, KeyValue.Value);
	EndDo;
	
	If FilterBySelectedRow <> Undefined Then
		For Each KeyValue In FilterBySelectedRow Do
			FullFilter.Insert(KeyValue.Key, KeyValue.Value);
		EndDo;
	EndIf;
	
	BasisesTable = RowIDInfo.GetBasisesForSalesInvoice(FullFilter);
	
	TopLevelTable = BasisesTable.Copy(,"Basis");
	TopLevelTable.GroupBy("Basis");
	
	ThisObject.DocumentsTree.GetItems().Clear();
	
	For Each TopLevelRow In TopLevelTable Do
		TopLevelNewRow = ThisObject.DocumentsTree.GetItems().Add();
		TopLevelNewRow.Basis = TopLevelRow.Basis;
		TopLevelNewRow.Level = 1;
		
		SecondLevelRows = BasisesTable.FindRows(New Structure("Basis", TopLevelNewRow.Basis));
		
		For Each SecondLevelRow In SecondLevelRows Do
			SecondLevelNewRow = TopLevelNewRow.GetItems().Add();
			SecondLevelNewRow.Item = SecondLevelRow.Item;
			SecondLevelNewRow.ItemKey = SecondLevelRow.ItemKey;
			SecondLevelNewRow.Key = SecondLevelRow.Key;
			SecondLevelNewRow.Level = 2;
			
			If SelectedRow <> Undefined Then
				UnitFactorFrom = Catalogs.Units.GetUnitFactor(SecondLevelRow.BasisUnit, SecondLevelRow.Quantity);
				UnitFactorTo = Catalogs.Units.GetUnitFactor(SelectedRow.Unit, SelectedRow.Quantity);
				SecondLevelNewRow.Quantity = ?(UnitFactorTo = 0, 0, SecondLevelRow.Quantity * UnitFactorFrom / UnitFactorTo);
				SecondLevelNewRow.Unit = SelectedRow.Unit;
			Else
				SecondLevelNewRow.Quantity = SecondLevelRow.Qauntity;
				SecondLevelNewRow.Unit = SecondLevelRow.BasisUnit;
			EndIf;
		EndDo;
	EndDo;
EndProcedure
