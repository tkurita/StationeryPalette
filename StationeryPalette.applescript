property FileSorter : load("FileSorter") of application "StationaryPaletteLib"
property GetInsertionContainer : load("Get InsertionContainer") of application "StationaryPaletteLib"
property FileUtil : load("FileUtility") of application "StationaryPaletteLib"

property StationeryList : {}
property nameHistoryObj : missing value
property ComboBoxHistory : missing value

property saveLocation : missing value
property isRebuilded : false
property newDocName : missing value
property StationeryNum : 0
property StationeryName : missing value
property sourceItem : missing value
property dQ : ASCII character 34
property openFileFlag : missing value
property mainWindow : missing value

property preferenceVersion : 1.0

script StationerySorter
	property parent : FileSorter
	
	on getTargetItems()
		set nameList to list folder my targetContainer without invisibles
		set containerPath to my targetContainer as Unicode text
		set theList to {}
		repeat with ith from 1 to length of nameList
			set end of theList to (containerPath & (item ith of nameList)) as alias
		end repeat
		return {theList, nameList}
	end getTargetItems
	
	on buildIndexArray()
		set {itemList, nameList} to getTargetItems()
		set indexList to {}
		set kindList to {}
		repeat with ith from 1 to length of itemList
			set end of indexList to extractInfo(item ith of itemList)
			set end of kindList to extractKind(item ith of itemList)
		end repeat
		return {itemList, nameList, kindList, indexList}
	end buildIndexArray
	
	on getContainer()
		set thePath to (path to application support from user domain as Unicode text) & "Stationery:"
		try
			set theAlias to thePath as alias
		on error number -43
			set resourcePath to resource path of main bundle
			set StationeryZip to quoted form of (resourcePath & "/Stationery.zip")
			set appSupportPath to quoted form of POSIX path of (path to application support from user domain)
			do shell script "ditto --sequesterRsrc -x -k " & StationeryZip & space & appSupportPath
			set theAlias to thePath as alias
			tell application "Finder"
				set arrangement of icon view options of container window of theAlias to snap to grid
			end tell
			--error number -128
		end try
		return theAlias
	end getContainer
	
	on sortDirectionOfIconView()
		return "column direction"
	end sortDirectionOfIconView
end script

on rebuild()
	set {itemList, nameList, kindList, indexList} to sortByView() of StationerySorter
	set StationeryList to {}
	repeat with ith from 1 to length of nameList
		set theItem to item ith of itemList
		if alias of (info for theItem) then
			try
				tell application "Finder"
					set item ith of kindList to kind of original item of theItem
				end tell
			on error number -1728 -- no original alias file
				set item ith of kindList to "No original alias file"
			end try
		end if
		set end of StationeryList to {|name|:item ith of nameList, |kind|:item ith of kindList}
	end repeat
end rebuild

on readDefaultValue(entryName, defaultValue)
	tell user defaults
		if exists default entry entryName then
			return contents of default entry entryName
		else
			make new default entry at end of default entries with properties {name:entryName, contents:defaultValue}
			return defaultValue
		end if
	end tell
end readDefaultValue

on writeStationeryListDefaults()
	set contents of default entry "StationeryList" of user defaults to StationeryList
	set contents of default entry "lastRebuildDate" of user defaults to current date
end writeStationeryListDefaults

on makeStationeryListDefaults()
	make new default entry at end of default entries of user defaults with properties {name:"StationeryList", contents:StationeryList}
	make new default entry at end of default entries of user defaults with properties {name:"lastRebuildDate", contents:current date}
	set StationeryNum to 0
	make new default entry at end of default entries of user defaults with properties {name:"StationeryNum", contents:StationeryNum}
end makeStationeryListDefaults

on readStationeryListDefaults()
	if exists default entry "lastRebuildDate" of user defaults then
		set lastRebuildDate to contents of default entry "lastRebuildDate" of user defaults
		set StationeryFolder to getContainer() of StationerySorter
		tell application "Finder"
			set currentModDate to modification date of StationeryFolder
		end tell
		--display dialog (lastRebuildDate as string) & return & (currentModDate as string)
		if lastRebuildDate > currentModDate then
			set StationeryList to readDefaultValue("StationeryList", StationeryList)
			set StationeryNum to readDefaultValue("StationeryNum", StationeryNum)
		else
			rebuild()
			writeStationeryListDefaults()
		end if
		
	else
		rebuild()
		makeStationeryListDefaults()
	end if
end readStationeryListDefaults

on readPaletteDefaults()
	set theVersion to readDefaultValue("preferenceVersion", preferenceVersion)
	if preferenceVersion > theVersion then
		set contents of default entry "preferenceVersion" of user defaults to preferenceVersion
		set mainWindowBounds to {}
	else
		set mainWindowBounds to readDefaultValue("mainWindowBounds", {})
	end if
	return mainWindowBounds
end readPaletteDefaults

on setSaveLocation(targetWindow)
	set saveLocation to do() of GetInsertionContainer
	set contents of text field "SaveLocationPath" of box "SaveToBox" of targetWindow to saveLocation as Unicode text
end setSaveLocation

on importScript(scriptName)
	tell main bundle
		set scriptPath to path for script scriptName extension "scpt"
	end tell
	return load script POSIX file scriptPath
end importScript

on will open theObject
	set untitledName to localized string "Untitled"
	set mainWindow to theObject
	setSaveLocation(theObject)
	readStationeryListDefaults()
	
	set mainWindowBounds to readPaletteDefaults()
	if mainWindowBounds is not {} then
		set bounds of theObject to mainWindowBounds
	else
		center theObject
	end if
	
	set ComboBoxHistory to importScript("ComboBoxHistory")
	set nameHistoryObj to makeObj("nameHistory", {}) of ComboBoxHistory
	set ignoringValue of nameHistoryObj to untitledName
	setComboBox(combo box "newFileName" of theObject) of nameHistoryObj
	set contents of combo box "newFileName" of theObject to untitledName
	
	set StationeryTable to table view "StationeryList" of scroll view "StationeryList" of theObject
	set StationeryDataSource to data source of StationeryTable
	
	tell StationeryDataSource
		make new data column at the end of the data columns with properties {name:"name"}
		make new data column at the end of the data columns with properties {name:"kind"}
	end tell
	
	append StationeryDataSource with StationeryList
	--display dialog StationeryNum
	if StationeryNum is not 0 then
		set selected row of StationeryTable to StationeryNum
	end if
end will open

on isExist(filePath)
	try
		filePath as alias
		return true
	on error
		return false
	end try
end isExist

on copyItem()
	hide mainWindow
	set theItem to copyItem of FileUtil from sourceItem into saveLocation given name:newDocName, mode:1
	tell application "Finder"
		if (theItem as Unicode text) does not end with ":" then
			set stationery of theItem to false
		end if
		if openFileFlag then
			open theItem
		end if
	end tell
	return true
end copyItem

on panel ended theObject with result withResult
	if withResult is 1 then
		set newFileSpec to path name of theObject
		set pathRecord to analyzePath(POSIX file newFileSpec) of FileUtil
		set saveLocation to folderReference of pathRecord
		set newDocName to name of pathRecord
		if copyItem() then
			quitWithSaving()
		end if
	end if
end panel ended

on makeNewDoc()
	set theFolder to (getContainer() of StationerySorter) as Unicode text
	set sourceItem to (theFolder & StationeryName) as alias
	if alias of (info for sourceItem) then
		try
			tell application "Finder"
				set sourceItem to original item of sourceItem
			end tell
		on error number -1728 -- no original alias file
			set sourceItem to missing value
			display dialog "No original Item for the alias file." attached to window "Main" buttons {"OK"} default button "OK" with icon 0
			return false
		end try
	end if
	
	set targetFilePath to (saveLocation as Unicode text) & newDocName
	if isExist(targetFilePath) then
		tell save panel
			set prompt to "Save"
			set treat packages as directories to false
		end tell
		
		display save panel attached to window "Main" in directory (POSIX path of saveLocation) with file name newDocName
		return false
	else
		return copyItem()
	end if
end makeNewDoc

on writePaletteDefaults()
	tell user defaults
		set contents of default entry "StationeryNum" to StationeryNum
		set contents of default entry "mainWindowBounds" to (bounds of mainWindow as list)
	end tell
end writePaletteDefaults

on clicked theObject
	set mainWindow to window of theObject
	set StationeryTable to table view "StationeryList" of scroll view "StationeryList" of mainWindow
	
	set objName to name of theObject
	if objName is "OK" then
		set StationeryNum to selected row of StationeryTable
		if StationeryNum is 0 then
			display dialog "No Stationery is selected." attached to mainWindow buttons {"OK"} default button "OK" with icon 0
			return
		end if
		
		set selectedDataRow to selected data row of StationeryTable
		set StationeryName to contents of data cell "Name" of selectedDataRow
		set newDocName to contents of combo box "newFileName" of mainWindow
		set openFileFlag to (state of button "OpenSwitch" of mainWindow is 1)
		if makeNewDoc() then
			quitWithSaving()
		end if
	else if objName is "Cancel" then
		quit
	end if
	
end clicked

on drop theObject drag info dragInfo
	set preferred type of pasteboard of dragInfo to "file names"
	set theFiles to contents of pasteboard of dragInfo
	log theObject
	set pathRecord to analyzePath(POSIX file (item 1 of theFiles)) of FileUtil
	if isFolder of pathRecord then
		set saveLocation to (POSIX file (item 1 of theFiles)) as alias
	else
		set saveLocation to (folderReference of pathRecord) as alias
	end if
	set contents of text field of theObject to saveLocation as Unicode text
end drop

on awake from nib theObject
	set theName to name of theObject
	if theName is "SaveToBox" then
		tell theObject to register drag types {"file names"}
	end if
end awake from nib

on choose menu item theObject
	set theName to name of theObject
	if theName is "quit" then
		quit
	else if theName is "Rebuild" then
		rebuild()
		writeStationeryListDefaults()
		set StationeryTable to table view "StationeryList" of scroll view "StationeryList" of window "Main"
		set StationeryDataSource to data source of StationeryTable
		delete (every data row of StationeryDataSource)
		append StationeryDataSource with StationeryList
	else if theName is "OpenStationeryFolder" then
		set StationeryFolder to getContainer() of StationerySorter
		tell application "Finder"
			activate
			open StationeryFolder
		end tell
	else if theName is "UpdateSaveLocation" then
		setSaveLocation(window "Main")
	end if
end choose menu item

on double clicked theObject
	set StationeryNum to selected row of theObject
	set selectedDataRow to selected data row of theObject
	set StationeryName to contents of data cell "Name" of selectedDataRow
	set theFolder to (getContainer() of StationerySorter) as Unicode text
	set sourceItem to (theFolder & StationeryName) as alias
	tell application "Finder"
		open sourceItem
	end tell
end double clicked

on resigned active theObject
	if not visible of window "Main" then
		show window "Main"
	end if
end resigned active

on should close theObject
	hide theObject
	return false
end should close

on quit
	writePaletteDefaults()
	continue quit
end quit

on quitWithSaving()
	addValue(newDocName) of nameHistoryObj
	writeDefaults() of nameHistoryObj
	quit
end quitWithSaving
