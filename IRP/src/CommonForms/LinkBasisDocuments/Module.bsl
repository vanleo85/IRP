
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ThisObject.Filter = Parameters.Filter;
	
	For Each Row In Parameters.ExistingRows Do
		NewRow = ThisObject.ExistingRows.Add();
		FillPropertyValues(NewRow, Row);
		NewRow.Picture = 3;
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
		TopLevelNewRow.PictureLevel1 = 0;
		
		SecondLevelRows = BasisesTable.FindRows(New Structure("Basis", TopLevelNewRow.Basis));
		
		For Each SecondLevelRow In SecondLevelRows Do
			SecondLevelNewRow = TopLevelNewRow.GetItems().Add();
			FillPropertyValues(SecondLevelNewRow, SecondLevelRow);
			
			SecondLevelNewRow.Level   = 2;
			SecondLevelNewRow.PictureLevel2 = 3;
			
			If SelectedRow <> Undefined Then
				UnitFactorFrom = Catalogs.Units.GetUnitFactor(SecondLevelRow.BasisUnit, SecondLevelRow.Quantity);
				UnitFactorTo = Catalogs.Units.GetUnitFactor(SelectedRow.Unit, SelectedRow.Quantity);
				SecondLevelNewRow.Quantity = ?(UnitFactorTo = 0, 0, SecondLevelRow.Quantity * UnitFactorFrom / UnitFactorTo);
				SecondLevelNewRow.Unit = SelectedRow.Unit;
			Else
				SecondLevelNewRow.Quantity = SecondLevelRow.Quantity;
				SecondLevelNewRow.Unit = SecondLevelRow.BasisUnit;
			EndIf;
		EndDo;
	EndDo;
EndProcedure
