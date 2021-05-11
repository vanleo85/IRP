
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ThisObject.List.QueryText = LocalizationEvents.ReplaceDescriptionLocalizationPrefix(ThisObject.List.QueryText);
	
	If Parameters.Filter.Property("Item") Then
		If TypeOf(Parameters.Filter.Item) = Type("CatalogRef.ItemKeys") Then
			Parameters.Filter.Item = Parameters.Filter.Item.Item;
		EndIf;
	EndIf;
	
	If Parameters.Filter.Property("Item") Then
		List.Parameters.SetParameterValue("Item", Parameters.Filter.Item);
		List.Parameters.SetParameterValue("Unit", Parameters.Filter.Item.Unit);
	Else
		List.Parameters.SetParameterValue("Item", Catalogs.Items.EmptyRef());
		List.Parameters.SetParameterValue("Unit", Catalogs.Units.EmptyRef());
	EndIf;
	Parameters.Filter.Delete("Item");
	Parameters.Filter.Delete("BasisUnit");
EndProcedure
