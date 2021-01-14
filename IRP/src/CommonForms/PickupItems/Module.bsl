
#Region Variables

#EndRegion

#Region FormEventHandlers
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ThisObject.ItemList.QueryText = LocalizationEvents.ReplaceDescriptionLocalizationPrefix(ThisObject.ItemList.QueryText);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	HideFiltersGroup();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

#EndRegion

#Region FormTableItemsEventHandlers

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure HideFilters(Command)
	Items.ItemListHideFilters.Check = Not Items.ItemListHideFilters.Check;
	HideFiltersGroup();
EndProcedure

#EndRegion

#Region Initialize

#EndRegion

#Region Private

&AtClient
Procedure HideFiltersGroup()
	Items.GroupFilters.Visible = Items.ItemListHideFilters.Check;
	
EndProcedure



#EndRegion


