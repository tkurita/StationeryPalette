#import "FileTreeWindowController.h"
#import "FileTreeDataSource.h"
#import "FileTreeNode.h"
#import "KeyedUnarchiveFromDataTransformer.h"
#import "NSOutlineView_Extensions.h"
#import "PathExtra.h"
#import "Sparkle/SUUpdater.h"

#define useLog 0

void showScriptError(NSDictionary *errorDict)
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:
		[NSString stringWithFormat:@"AppleScript Error : %@",
			[errorDict objectForKey:NSAppleScriptErrorNumber]]
	];
	[alert setInformativeText:[errorDict objectForKey:NSAppleScriptErrorMessage]];
	[alert setAlertStyle:NSWarningAlertStyle];
//	if ([alert runModal] == NSAlertFirstButtonReturn) {
//	} 
	[alert release];
}

static void addToolbarItem(NSMutableDictionary *theDict, NSString *identifier, NSString *label, NSString *paletteLabel, NSString *toolTip,
		id target,SEL settingSelector, id itemContent,SEL action, NSMenu * menu)
{
    NSMenuItem *mItem;
    // here we create the NSToolbarItem and setup its attributes in line with the parameters
    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
    [item setLabel:label];
    [item setPaletteLabel:paletteLabel];
    [item setToolTip:toolTip];
    [item setTarget:target];
    // the settingSelector parameter can either be @selector(setView:) or @selector(setImage:).  Pass in the right
    // one depending upon whether your NSToolbarItem will have a custom view or an image, respectively
    // (in the itemContent parameter).  Then this next line will do the right thing automatically.
    [item performSelector:settingSelector withObject:itemContent];
    [item setAction:action];
    // If this NSToolbarItem is supposed to have a menu "form representation" associated with it (for text-only mode),
    // we set it up here.  Actually, you have to hand an NSMenuItem (not a complete NSMenu) to the toolbar item,
    // so we create a dummy NSMenuItem that has our real menu as a submenu.
    if (menu!=NULL)
    {
	// we actually need an NSMenuItem here, so we construct one
	mItem=[[[NSMenuItem alloc] init] autorelease];
	[mItem setSubmenu: menu];
	[mItem setTitle: [menu title]];
	[item setMenuFormRepresentation:mItem];
    }
    // Now that we've setup all the settings for this new toolbar item, we add it to the dictionary.
    // The dictionary retains the toolbar item for us, which is why we could autorelease it when we created
    // it (above).
    [theDict setObject:item forKey:identifier];
}

@implementation FileTreeWindowController

//+ (void)initialize
//{	
//	NSValueTransformer *transformer = [[[KeyedUnarchiveFromDataTransformer alloc] init] autorelease];
//	[NSValueTransformer setValueTransformer:transformer forName:@"KeyedUnarchiveFromData"];
//}

- (void) dealloc {
	[toolbarItems release];
	[insertionLocationScript release];
	[untitledName release];
	[super dealloc];
}

- (void)addToNameHistory:(NSString *)newName
{
	if (newName == nil) return;
	
	NSString *base_name = [newName stringByDeletingPathExtension];
	if ([base_name isEqualToString:untitledName]) return;
	if (![base_name length]) return;
	
	NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *name_history = [user_defaults objectForKey:@"NameHistory"];
	if (name_history == nil) {
		name_history = [NSMutableArray array];
	}
	else {
		name_history = [name_history mutableCopy];
	}
		
	if ([name_history containsObject:newName]) return;

	[name_history insertObject:newName atIndex:0];
	unsigned int history_max = [[user_defaults objectForKey:@"HistoryMax"] unsignedIntValue];

	if ([name_history count] > history_max) {
		[name_history removeLastObject];
	}
	[user_defaults setObject:name_history forKey:@"NameHistory"];
}

#pragma mark accessors
- (void)setPreviousSelectionName:(NSString *)name
{
	[name retain];
	[previousSelectionName release];
	previousSelectionName = name;
}

- (void)setInsertionLocation:(NSString *)path
{
	[insertionLocation release];
	insertionLocation = [[NDAlias aliasWithPath:path] retain];;
}

#pragma mark actions
void cleanupFolderContents(NSString *path)
{
	NSFileManager *file_manager = [NSFileManager defaultManager];
	[file_manager removeFileAtPath:[path stringByAppendingPathComponent:ORDER_CHACHE_NAME] handler:nil];
	
	NSDirectoryEnumerator *enumerator = [file_manager enumeratorAtPath:path];
	NSString *file_name;
	NSString *file_path;
	NSString *file_type;
	while (file_name = [enumerator nextObject]) {
		file_path = [path stringByAppendingPathComponent:file_name];
		file_type = [[file_manager fileAttributesAtPath:file_path traverseLink:NO] objectForKey:NSFileType];
		if ([file_type isEqualToString:NSFileTypeDirectory]) {
			cleanupFolderContents(file_path);
		}
		else {
			[file_path setStationeryFlag:NO];
		}
		//NSLog(file);
	}
}

- (void)performOperationAfterCopy:(NSString *)targetPath sourceNode:(FileTreeNode *)node
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSFileManager *file_manager = [NSFileManager defaultManager];

	NSMutableDictionary *file_info = [[file_manager fileAttributesAtPath:targetPath traverseLink:NO] mutableCopy];
	[file_info setObject:[NSDate date] forKey:NSFileModificationDate];
	[file_info setObject:[NSDate date] forKey:NSFileCreationDate];
	if (![file_manager changeFileAttributes:file_info atPath:targetPath])
		NSLog(@"Fail to change attribute of %@", targetPath);

	[workspace noteFileSystemChanged:targetPath];

	if (shouldOpenFile) {
		[workspace openFile:targetPath];
	}
	[self addToNameHistory:[targetPath lastPathComponent]];
	
	if ([[[node nodeData] fileType] isEqualToString:NSFileTypeRegular] ) {
		[targetPath setStationeryFlag:NO];
	}
	else {
		if ([[node nodeData] isContainer])
			cleanupFolderContents(targetPath);
	}

	[self close];
}

- (void)operationAfterCopyWithNotification:(NSNotification *)notification
{
	NSDictionary *info = [notification userInfo];
	[self performOperationAfterCopy:[info objectForKey:@"destination"]
						 sourceNode:[info objectForKey:@"sourceNode"]];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode  contextInfo:(FileTreeNode *)source_node
{
	[source_node autorelease];
	NSString *source_path = [[source_node nodeData] originalPath];
	if (returnCode == NSCancelButton) return;
	
	NSString *target_path = [sheet filename];
	NSFileManager *file_manager = [NSFileManager defaultManager];
	if ([file_manager fileExistsAtPath:target_path]) {
		[file_manager removeFileAtPath:target_path handler:nil];
	}
		
	[file_manager copyPath:source_path toPath:target_path handler:nil];
	[self performOperationAfterCopy:target_path sourceNode:source_node];
}

- (void)makeFileWithSelectedStationery
{
	NSFileManager *file_manager = [NSFileManager defaultManager];

	FileTreeNode *source_node = (FileTreeNode *)[fileTreeView selectedItem];
	NSString *source_path = [[source_node nodeData] originalPath];	
	NSString *source_suffix = [source_path pathExtension];
	NSString *file_name = [fileNameField stringValue];
	NSString *current_suffix = [file_name pathExtension];
	
	if (([current_suffix length] < 1) && ([source_suffix length] > 0)) {
		file_name = [file_name stringByAppendingPathExtension:source_suffix];
	}
	
	NSString *destination_path = [insertionLocation path];
	NSString *target_path = [destination_path stringByAppendingPathComponent:file_name];
	
	if (![file_manager copyPath:source_path toPath:target_path handler:nil] ) {
		NSSavePanel *panel = [NSSavePanel savePanel];
		[panel beginSheetForDirectory:destination_path file:file_name modalForWindow:[self window]
			modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
			contextInfo:[source_node retain]];
		return;
	}
	
	[self performOperationAfterCopy:target_path sourceNode:source_node];
}

- (IBAction)newFileFromStationery:(id)sender
{
	shouldOpenFile = YES;
	[self makeFileWithSelectedStationery];
}

- (IBAction)cancelAction:(id)sender
{
	[self close];
}

- (IBAction)copyStationery:(id)sender
{
	shouldOpenFile = NO;
	[self makeFileWithSelectedStationery];
}

#pragma mark DropBox
- (BOOL)dropBox:(NSView *)dbv acceptDrop:(id <NSDraggingInfo>)info item:(id)item
{
	[self setInsertionLocation:item];
	[saveLocationField setStringValue:item];
	return YES;
}

#pragma mark medhods for toolbar
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	if (returnCode == NSCancelButton) return;
	[panel close];
	FileTreeNode *selected_item = (FileTreeNode *)[fileTreeView selectedItem];
	[fileTreeDataSource fileTreeView:fileTreeView addNodesWithPathes:[panel filenames] afterNode:selected_item];
}

- (IBAction)addItem:(id)sender
{
	[[NSOpenPanel openPanel] beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] 
		modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)setupToolbar
{
	NSToolbar *toolbar=[[[NSToolbar alloc] initWithIdentifier:@"myToolbar"] autorelease];
	toolbarItems=[[NSMutableDictionary dictionary] retain];
	NSString *label;
	NSString *tool_tip;
	
	label = NSLocalizedString(@"Add Template", @"Toolbar's label for AddItem");
	tool_tip = NSLocalizedString(@"Add a new template with choosing a file.", @"Toolbar's tool tip for AddItem");
	addToolbarItem(toolbarItems, @"AddItem", label, label, tool_tip,
		self,@selector(setImage:),[NSImage imageNamed:@"AddItem.png"],@selector(addItem:),NULL);

	label = NSLocalizedString(@"Delete", @"Toolbar's label for RemoveItem");
	tool_tip = NSLocalizedString(@"Move selected items into trash.", @"Toolbar's tool tip for RemoveItem");	
	addToolbarItem(toolbarItems, @"RemoveItem", label, label, tool_tip,
		fileTreeView, @selector(setImage:),[NSImage imageNamed:@"ToolbarDeleteIcon.icns"],@selector(deleteSelection:),NULL);

	label = NSLocalizedString(@"New Folder", @"Toolbar's label for NewFolder");
	tool_tip = NSLocalizedString(@"Make a new folder.", @"Toolbar's tool tip for NewFolder");		
	addToolbarItem(toolbarItems, @"NewFolder", label, label, tool_tip,
		fileTreeView, @selector(setImage:),[NSImage imageNamed:@"MakeFolder.png"],@selector(makeFolder:),NULL);
	
	label = NSLocalizedString(@"Rename", @"Toolbar's label for RenameItem");
	tool_tip = NSLocalizedString(@"Rename selected item.", @"Toolbar's tool tip for RenameItem");
	addToolbarItem(toolbarItems, @"RenameItem", label, label, tool_tip,
		fileTreeView, @selector(setImage:),[NSImage imageNamed:@"rename.png"],@selector(renameSelection:),NULL);

	label = NSLocalizedString(@"Reveal in Finder", @"Toolbar's label for RevealInFinder");
	tool_tip = NSLocalizedString(@"Reveal selected items in Finder.", @"Toolbar's tool tip for RevealInFinder");	
	addToolbarItem(toolbarItems, @"RevealInFinder", label, label, tool_tip,
		fileTreeView, @selector(setImage:),[NSImage imageNamed:@"Reveal.tiff"],@selector(revealSelection:),NULL);

	label = NSLocalizedString(@"Reload", @"Toolbar's label for Reload");
	tool_tip = NSLocalizedString(@"Reload templates.", @"Toolbar's tool tip for Reload");		
	addToolbarItem(toolbarItems, @"Reload", label, label, tool_tip,
		fileTreeDataSource, @selector(setImage:),[NSImage imageNamed:@"DarkBlueReload.png"], 
		@selector(reloadFileTreeNodes:), NULL);

	label = NSLocalizedString(@"Check for Updates", @"Toolbar's label for CheckForUpdates");
	tool_tip = NSLocalizedString(@"Check for Updates of newest StationeryPalette.", @"Toolbar's tool tip for CheckForUpdates");			
	addToolbarItem(toolbarItems,@"CheckForUpdates", label, label, tool_tip,
				   [SUUpdater sharedUpdater] , @selector(setImage:),[NSImage imageNamed:@"CheckForUpdates.png"], 
				   @selector(checkForUpdates:), NULL);	
	
	label = NSLocalizedString(@"Help", @"Toolbar's label for Help");
	tool_tip = NSLocalizedString(@"Show StationaryPalette Help.", @"Toolbar's tool tip for Help");			
	addToolbarItem(toolbarItems,@"Help", label, label, tool_tip,
		self,@selector(setView:), helpButtonView, NULL, NULL);
	
	
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration: YES];
	[toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
	[[self window] setToolbar:toolbar];
}

#pragma mark delegate of NSWindow
- (void)windowWillClose:(NSNotification *)aNotification
{
	NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
	NSArray *selected_items = [fileTreeView allSelectedItems];
	NSArray *index_pathes = [selected_items valueForKey:@"indexPath"];
	NSData *archived_index_pathes = [NSKeyedArchiver archivedDataWithRootObject:index_pathes];
	[user_defaults setObject:archived_index_pathes forKey:@"FileTreeViewSelection"];
	[NSApp hide:self];	
}

#pragma mark override NSWindowController
- (void)showWindowWithFinderSelection:(id)sender
{
	[self showWindow:sender];
	NSDictionary *error_dict = nil;
	NSAppleEventDescriptor *scriptResult = [insertionLocationScript executeAndReturnError:&error_dict];
	if (error_dict != nil) {
		#if useLog
		NSLog([error_dict description]);
		#endif
		showScriptError(error_dict);
	}
	NSString *path = [scriptResult stringValue];
	[self setInsertionLocation:path];
	[saveLocationField setStringValue:path];

}

- (void)showWindowWithDirectory:(NSString *)folderPath
{
	[self showWindow:self];
	[self setInsertionLocation:folderPath];
	[saveLocationField setStringValue:folderPath];	
}

- (IBAction)showWindow:(id)sender
{
#if useLog
	NSLog(@"start showWindow");
#endif	
	BOOL is_already_visible = [[self window] isVisible];
	[super showWindow:sender];
#if useLog
	NSLog(@"after super showWindow");
#endif	
	
	NSArray *selected_items = nil;
	if (isFirstOpen) {
		NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
		NSData *data = [user_defaults objectForKey:@"FileTreeViewSelection"];
		
		if (data) {
			NSArray *index_pathes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			NSIndexPath *index_path = [index_pathes lastObject];
			
			FileTreeNode *node = [fileTreeDataSource nodeWithIndexPath:index_path];
			if (node) {
				int row_index = [fileTreeView rowForItem:node];
				[fileTreeView selectRow:row_index byExtendingSelection:YES];
				[fileTreeView scrollRowToVisible:row_index];
				selected_items = [NSArray arrayWithObject:node];
			}
			
		}
		isFirstOpen = NO;
	}
	else {
		selected_items = [fileTreeView allSelectedItems];
	}
	
	if ((selected_items == nil) || is_already_visible) return;
	
	if ([selected_items count] > 1) {
		[fileNameField setStringValue:untitledName];
		return;
	}
	
	NSString *node_name = [(FileTreeNodeData *)[[selected_items lastObject] nodeData] name];
	NSString *path_extension = [node_name pathExtension];
	NSString *untitled_name = untitledName;
	if ([path_extension length] > 0) {
		untitled_name = [untitledName stringByAppendingPathExtension:path_extension];
	}
	[fileNameField setStringValue:untitled_name];
	//[fileNameField selectText:self]; //make initial first responder to be fileTreeView
	[[self window] makeFirstResponder:fileTreeView];
}

- (void)selectionDidChange:(NSNotification *)notification
{
	//NSLog([notification description]);
	FileTreeView *ftv = [notification object];
	NSArray *selected_items = [ftv allSelectedItems];
	if ([selected_items count] > 1) return;
	
	FileTreeNode *node = [selected_items lastObject];
	NSString *node_name = [[node nodeData] name];
	if (previousSelectionName) {
		NSString *pre_suffix = [previousSelectionName pathExtension];
		NSString *name_in_field = [fileNameField stringValue];
		if ([[name_in_field pathExtension] isEqualToString:pre_suffix]) {
			NSString *new_name = [name_in_field stringByDeletingPathExtension];
			NSString *new_suffix = [node_name pathExtension];
			if ([new_suffix length] > 0) {
				new_name = [new_name stringByAppendingPathExtension:new_suffix];
			}
			[fileNameField setStringValue:new_name];
		}
	}
	[self setPreviousSelectionName:node_name];
}

- (void)windowDidLoad
{
#if useLog
	NSLog(@"start windowDidLoad");
#endif	
	[self setupToolbar];
	[[self window] center];
	[[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	[self setWindowFrameAutosaveName:@"StationaryPaletteMain"];
	
	/*set up AppleScript InsertionLocation*/
	NSBundle *bundle = [NSBundle mainBundle];
	NSString *scriptPath = [bundle pathForResource:@"InsertionLocation" 
									ofType:@"scpt" inDirectory:@"Scripts"];
	NSURL *scriptURL = [NSURL fileURLWithPath:scriptPath];
	NSDictionary *error_dict = nil;
	insertionLocationScript = [[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:&error_dict];
	if (error_dict != nil) {
		#if useLog
		NSLog([error_dict description]);
		#endif
		showScriptError(error_dict);
	}
	
	[fileTreeView setDoubleAction:@selector(openSelection:)];
	
	[saveToBox setAcceptFileInfo:[NSArray arrayWithObject:
		[NSDictionary dictionaryWithObject:NSFileTypeDirectory forKey:@"FileType"]]];
	
	isFirstOpen = YES;
	untitledName = [[fileNameField stringValue] retain];
	previousSelectionName = nil;
	[[NSNotificationCenter defaultCenter] addObserver:self 
		selector:@selector(selectionDidChange:) 
		name:NSOutlineViewSelectionDidChangeNotification object:fileTreeView];

	[[NSNotificationCenter defaultCenter] addObserver:self 
		selector:@selector(operationAfterCopyWithNotification:) 
		name:@"NewFileNotification" object:fileTreeDataSource];

}

#pragma mark delegate of Tool Bar
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    // We create and autorelease a new NSToolbarItem, and then go through the process of setting up its
    // attributes from the master toolbar item matching that identifier in our dictionary of items.
    NSToolbarItem *newItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    NSToolbarItem *item=[toolbarItems objectForKey:itemIdentifier];
    
    [newItem setLabel:[item label]];
    [newItem setPaletteLabel:[item paletteLabel]];
    if ([item view]!=NULL) {
		[newItem setView:[item view]];
    }
    else {
		[newItem setImage:[item image]];
    }
    [newItem setToolTip:[item toolTip]];
    [newItem setTarget:[item target]];
    [newItem setAction:[item action]];
    [newItem setMenuFormRepresentation:[item menuFormRepresentation]];
    // If we have a custom view, we *have* to set the min/max size - otherwise, it'll default to 0,0 and the custom
    // view won't show up at all!  This doesn't affect toolbar items with images, however.
    if ([newItem view]!=NULL) {
		[newItem setMinSize:[[item view] bounds].size];
		[newItem setMaxSize:[[item view] bounds].size];
    }

    return newItem;
}

// This method is required of NSToolbar delegates.  It returns an array holding identifiers for the default
// set of toolbar items.  It can also be called by the customization palette to display the default toolbar.    
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:@"AddItem", @"NewFolder", @"RenameItem", @"RemoveItem",  
				NSToolbarFlexibleSpaceItemIdentifier,@"RevealInFinder", @"Reload", 
				NSToolbarSeparatorItemIdentifier, @"CheckForUpdates", @"Help", nil];
}

// This method is required of NSToolbar delegates.  It returns an array holding identifiers for all allowed
// toolbar items in this toolbar.  Any not listed here will not be available in the customization palette.
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:@"AddItem", @"NewFolder", @"RenameItem", @"RemoveItem",
				@"RevealInFinder", @"Reload",@"CheckForUpdates", @"Help",
				NSToolbarSeparatorItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, nil];
}

@end
