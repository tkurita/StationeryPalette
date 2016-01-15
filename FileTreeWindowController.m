#import "FileTreeWindowController.h"
#import "PathExtra.h"
#import "Sparkle/SUUpdater.h"
#import "NSRunningApplication+SmartActivate.h"
#import "FileDatum.h"
#import "FileTreeNode.h"
#import "NSString+StationeryFlag.h"
#import "FileTreeDataController.h"

#define useLog 0

void showScriptError(NSDictionary *errorDict)
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:
		[NSString stringWithFormat:@"AppleScript Error : %@",
			errorDict[NSAppleScriptErrorNumber]]
	];
	[alert setInformativeText:errorDict[NSAppleScriptErrorMessage]];
	[alert setAlertStyle:NSWarningAlertStyle];
//	if ([alert runModal] == NSAlertFirstButtonReturn) {
//	} 
}

@implementation FileTreeWindowController


- (void)addToNameHistory:(NSString *)newName
{
	if (newName == nil) return;
	
	NSString *base_name = [newName stringByDeletingPathExtension];
	if ([base_name isEqualToString:_untitledName]) return;
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

- (FileDatum *)selectedFileDatum
{
    NSArray  *selection = [treeController selectedObjects];
    return [[selection lastObject] representedObject];
}

#pragma mark actions
void cleanupFolderContents(NSString *path)
{
	NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    [fm removeItemAtPath:[path stringByAppendingPathComponent:ORDER_CHACHE_NAME]
                   error:&err];
    
	NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
	NSString *file_name;
	NSString *file_path;
    while (file_name = [enumerator nextObject]) {
		file_path = [path stringByAppendingPathComponent:file_name];
        if ([file_path isFolder]) {
			cleanupFolderContents(file_path);
		} else {
			[file_path setStationeryFlag:NO];
		}
	}
}

- (void)performOperationAfterCopy:(NSString *)targetPath
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSMutableDictionary *attr = [[fm attributesOfItemAtPath:targetPath
                                                     error:&err] mutableCopy];
    attr[NSFileCreationDate] = [NSDate date];
    attr[NSFileModificationDate] = [NSDate date];

    if (![fm setAttributes:attr ofItemAtPath:targetPath error:&err])
            NSLog(@"Fail to change attribute of %@", targetPath);

	[workspace noteFileSystemChanged:targetPath];

	if (shouldOpenFile) {
		[workspace openFile:targetPath];
	}
	[self addToNameHistory:[targetPath lastPathComponent]];
	
    if ([targetPath isFolder]) {
        cleanupFolderContents(targetPath);
    } else {
        [targetPath setStationeryFlag:NO];
    }

	[self close];
}

- (void)makeFileWithSelectedStationery
{
    FileDatum *fd = [self selectedFileDatum];
    
    NSURL *src_url = [fd fileURL];
	NSString *source_suffix = [src_url pathExtension];
	NSString *file_name = [fileNameField stringValue];
	NSString *current_suffix = [file_name pathExtension];
	
	if (([current_suffix length] < 1) && ([source_suffix length] > 0)) {
		file_name = [file_name stringByAppendingPathExtension:source_suffix];
	}
	NSURL *dir_url = [self insertionLocation];
	NSURL *dst_url = [dir_url URLByAppendingPathComponent:file_name];
	NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    if (![fm copyItemAtURL:src_url toURL:dst_url error:&err]) {
		NSSavePanel *panel = [NSSavePanel savePanel];
        [panel setDirectoryURL:dir_url];
        
        [panel beginSheetModalForWindow:[self window]
                      completionHandler:^(NSInteger result) {
                          if (result == NSCancelButton) return;
                          NSURL *dst_url = [panel URL];
                          NSError *err = nil;
                          if ([fm fileExistsAtPath:[dst_url path]]) {
                              [fm removeItemAtURL:dst_url error:&err];
                          }
                          [fm copyItemAtURL:src_url toURL:dst_url error:&err];
                          [self performOperationAfterCopy:[dst_url path]];
        }];
		return;
	}
	[self performOperationAfterCopy:[dst_url path]];
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
- (IBAction)addItem:(id)sender
{
    NSOpenPanel * op = [NSOpenPanel openPanel];
    [op setCanChooseDirectories:YES];
    [op beginSheetModalForWindow:[self window]
                                    completionHandler:^(NSInteger result)
     {
         if (result == NSOKButton) {
             [fileTreeDataController insertCopyingURLs:[op URLs]];
         }
     }];
}

- (IBAction)checkForUpdates:(id)sender
{
    [[SUUpdater sharedUpdater] checkForUpdates:sender];
}
#pragma mark delegate of NSWindow
- (void)windowWillClose:(NSNotification *)aNotification
{
	NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
	NSArray *index_pathes = [[treeController selectedNodes] valueForKey:@"indexPath"];
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
	NSAppleEventDescriptor *scriptResult = [_insertionLocationScript executeAndReturnError:&error_dict];
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
    
	if (isFirstOpen) {
        [fileTreeDataController restoreSelectionWithKey:@"FileTreeViewSelection"];
		isFirstOpen = NO;
	}
    
    NSArray  *selected_items = [treeController selectedObjects];
	if ((!selected_items) || is_already_visible) return;
	
	if ([selected_items count] > 1) {
		[fileNameField setStringValue:_untitledName];
		return;
	}
   
	NSString *path_extension = [[[[selected_items lastObject] representedObject] name]
                                    pathExtension];
	NSString *untitled_name = _untitledName;
	if ([path_extension length] > 0) {
		untitled_name = [_untitledName stringByAppendingPathExtension:path_extension];
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
    NSString *node_name = [[self selectedFileDatum] name];
	if (_previousSelectionName) {
		NSString *pre_suffix = [_previousSelectionName pathExtension];
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
	self.insertionLocationScript = [[NSAppleScript alloc] initWithContentsOfURL:scriptURL
                                                                          error:&error_dict];
	if (error_dict != nil) {
		#if useLog
		NSLog(@"%@", [error_dict description]);
		#endif
		showScriptError(error_dict);
	}
	
	[saveToBox setAcceptFileInfo:@[@{@"FileType": NSFileTypeDirectory}]];
	
	isFirstOpen = YES;
	self.untitledName = [fileNameField stringValue];
	self.previousSelectionName = nil;
	[[NSNotificationCenter defaultCenter] addObserver:self 
		selector:@selector(selectionDidChange:) 
		name:NSOutlineViewSelectionDidChangeNotification object:fileTreeView];

    [fileTreeDataController setRootDirPath:
     [[NSUserDefaults standardUserDefaults] stringForKey:@"FileTreeRoot"]];
}

@end
