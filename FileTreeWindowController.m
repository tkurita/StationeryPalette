#import "FileTreeWindowController.h"
#import "FileTreeDataSource.h"
#import "FileTreeNode.h"
#import "KeyedUnarchiveFromDataTransformer.h"
#import "NSOutlineView_Extensions.h"
#import "PathExtra.h"
#import "Sparkle/SUUpdater.h"
#import "NSRunningApplication+SmartActivate.h"

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

@implementation FileTreeWindowController

//+ (void)initialize
//{	
//	NSValueTransformer *transformer = [[[KeyedUnarchiveFromDataTransformer alloc] init] autorelease];
//	[NSValueTransformer setValueTransformer:transformer forName:@"KeyedUnarchiveFromData"];
//}

- (void) dealloc {
	[insertionLocationScript release];
	[untitledName release];
    self.insertionLocationBookmark = nil;
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
    NSError *error = nil;
    self.insertionLocationBookmark = [[NSURL fileURLWithPath:path]
                                             bookmarkDataWithOptions:0
                                      includingResourceValuesForKeys:nil
                                                        relativeToURL:0
                                                            error:&error];
    if (error) {
        [NSApp presentError:error];
    }
}

- (NSURL *)insertionLocation
{
    BOOL is_stale = NO;
    NSError *error = nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:_insertionLocationBookmark
                                           options:0
                                     relativeToURL:NULL
                               bookmarkDataIsStale:&is_stale
                                             error:&error];
    if (error) {
       [NSApp presentError:error];
    }
    return url;
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
	
	NSString *destination_path = [[self insertionLocation] path];
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

- (IBAction)checkForUpdates:(id)sender
{
    [[SUUpdater sharedUpdater] checkForUpdates:sender];
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
    /* for 10.8's Finder's insertion location bug */
    [NSApp activateIgnoringOtherApps:YES];
    [NSRunningApplication activateAppOfIdentifier:@"com.apple.finder"];
    [NSApp activateIgnoringOtherApps:YES];
    /* end for 10.8 */
	NSAppleEventDescriptor *scriptResult = [insertionLocationScript executeAndReturnError:&error_dict];
	if (error_dict != nil) {
		#if useLog
		NSLog(@"%@", [error_dict description]);
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
	NSArray *selected_items = nil;
	if (isFirstOpen) {
		NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
		NSData *data = [user_defaults objectForKey:@"FileTreeViewSelection"];
		
		if (data) {
			NSArray *index_pathes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			NSIndexPath *index_path = [index_pathes lastObject];
			FileTreeNode *node = [fileTreeDataSource nodeWithIndexPath:index_path];
			if (node) {
				NSInteger row_index = [fileTreeView rowForItem:node];
				[fileTreeView selectRowIndexes:[NSIndexSet indexSetWithIndex:row_index] 
														byExtendingSelection:YES];
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
#if useLog
	NSLog(@"end of showWindow");
#endif
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
    [helpToolBarItem setView:helpButtonView];
    
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
		NSLog(@"%@", [error_dict description]);
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

@end
