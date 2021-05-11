
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ThisObject.List.QueryText = LocalizationEvents.ReplaceDescriptionLocalizationPrefix(ThisObject.List.QueryText);
	
	If Parameters.Filter.Property("Item") Then
		If TypeOf(Parameters.Filter.Item) = Type("CatalogRef.ItemKeys") Then
			Parameters.Filter.Item = Parameters.Filter.Item.Item;
		EndIf;
	EndIf;
	
EndProcedure
