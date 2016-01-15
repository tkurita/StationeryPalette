#import "FileTreeDataController.h"
#import "ImageAndTextCell.h"
#import "NSIndexPath_Extensions.h"
#import "PathExtra.h"
#import "NewFileTreeNode.h"
#import "SmartActivate.h"

#include <Carbon/Carbon.h>

#define useLog 0

@implementation FileTreeDataController

@synthesize	rootNode;
@synthesize rootDirectory;
@synthesize nodeEnumerator;
@synthesize afterSheetInvocation;
@synthesize destinationIndexPath;
@synthesize destinationNode;
@synthesize destinationPath;
@synthesize processedNodes;
@synthesize nodesToDelete;
@synthesize conflictMessageTemplate;

static NSString *MovedNodesType = @"MOVED_Nodes_TYPE";


static BOOL isOptionKeyDown()
{
	UInt32 mod_key_status = GetCurrentKeyModifiers();
	return ((mod_key_status & optionKey) != 0);
}

- (void)dealloc
{
	[rootNode release];
	[rootDirectory release];
	[afterSheetInvocation release];
	[nodeEnumerator release];
	[destinationIndexPath release];
	[destinationPath release];
	[processedNodes release];
	[nodesToDelete release];
	[conflictMessageTemplate release];
	[super dealloc];
}

- (void)doubleAction:(id)sender
{
	if (doubleActionTarget) {
		[doubleActionTarget doubleAction:sender];
	} else {
		[self openSelection:self];
	}
}

- (void)awakeFromNib
{
#if useLog
	NSLog(@"start awakeFromNib in FireTreeDataController");
#endif
	NSTableColumn *table_column = [outlineView tableColumnWithIdentifier:@"displayName"];
	ImageAndTextCell *image_text_cell = [[ImageAndTextCell new] autorelease];
	[image_text_cell setFont:[[table_column dataCell] font]];
	[table_column setDataCell:image_text_cell];
	[outlineView setDoubleAction:@selector(doubleAction:)];
	[outlineView setTarget:self];
	[outlineView registerForDraggedTypes:
		[NSArray arrayWithObjects:MovedNodesType, NSFilenamesPboardType, nil]];
	self.conflictMessageTemplate = [conflictMessage stringValue];
	id pre_responder = [outlineView window];
	[self setNextResponder: [pre_responder nextResponder]];
	[pre_responder setNextResponder:self];
}

#pragma mark methods for outside objects
- (void)setRootDirPath:(NSString *)rootDirPath
{
	self.rootDirectory = [FileDatum fileDatumWithPath:rootDirPath];
	self.rootNode = [rootDirectory treeNode];
	[rootDirectory loadChildren];
}

- (NSArray *)selectedPaths
{
	return [[treeController selectedObjects] valueForKeyPath:@"representedObject.path"];
}

- (void)insertCopyingPath:(NSString *)sourcePath withName:(NSString *)newname
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSIndexPath *index_path = [treeController selectionIndexPath];
	NSString *destination_path = nil;
	FileDatum *destination_fd = nil;
	if (index_path) {
		if ([index_path length]) {
			NSTreeNode *a_node = [rootNode descendantNodeAtIndexPath:index_path];
			destination_fd = [[a_node parentNode] representedObject];
			destination_path = [destination_fd path];
			index_path = [index_path indexPathByIncrementLastIndex:1];
		} else {
			destination_fd = rootDirectory;
			destination_path = [rootDirectory path];
			index_path = [NSIndexPath indexPathWithIndex:[[rootNode childNodes] count]];
		}
	} else {
		destination_fd = rootDirectory;
		destination_path = [rootDirectory path];
		index_path = [NSIndexPath indexPathWithIndex:[[rootNode childNodes] count]];
	}
	
	NSString *target_path = [destination_path stringByAppendingPathComponent:newname];
	target_path = [target_path uniqueName];
	[fm copyPath:sourcePath toPath:target_path handler:nil];
	NewFileTreeNode *newnode = [[FileDatum fileDatumWithPath:target_path] treeNode];
	[[[destination_fd treeNode] mutableChildNodes] 
							insertObject:newnode atIndex:[index_path lastIndex]];
	[destination_fd saveOrder];
}

- (IBAction)updateRoot:(id)sender
{
	[rootDirectory update];
}

- (IBAction)openRootDirectory:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[rootDirectory path]];
	[SmartActivate activateAppOfIdentifier:@"com.apple.finder"];
}

#pragma mark utilities


- (void)setDestinationWithNode:(NSTreeNode *)aNode atIndexPath:anIndexPath
{
	self.destinationNode = aNode;
	self.destinationPath = [[aNode representedObject] path];
	self.destinationIndexPath = anIndexPath;
}

#pragma mark delegate methods

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
#if useLog
	NSLog(@"start outlineViewItemDidExpand");
#endif	
	NSTreeNode *controller_node = [[notification userInfo] objectForKey:@"NSObject"];
	NewFileTreeNode *file_tree_node = [controller_node representedObject];
	file_tree_node.isExpanded = YES;
#if useLog
	NSLog(@"expanned node name %@:", [[file_tree_node representedObject] name]);
#endif	
	[(FileDatum *)[[file_tree_node parentNode] representedObject] saveOrder];
#if useLog
	NSLog(@"end outlineViewItemDidExpand");
#endif		
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	NSTreeNode *controller_node = [[notification userInfo] objectForKey:@"NSObject"];
	NewFileTreeNode *file_tree_node = [controller_node representedObject];
	file_tree_node.isExpanded = NO;
	[(FileDatum *)[[file_tree_node parentNode] representedObject] saveOrder];
}

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell 
	 forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NewFileTreeNode *file_tree_node = [item representedObject];
	FileDatum *a_file_data = [file_tree_node representedObject];
	if ([[tableColumn identifier] isEqualToString:@"displayName"]) {
		if ([cell isKindOfClass:[ImageAndTextCell class]]) {
			[(ImageAndTextCell*)cell setImage:[a_file_data iconImage]];
		}
	}
	
	if ([a_file_data shouldExpand]) {
		[olv expandItem:item];
		[a_file_data setShouldExpand:NO];
	}
}

#pragma mark methods for conflict Error Window

#define kPerformReplacing 1
#define kStopAll 0
#define kCancelForItem -1

- (IBAction)conflictErrorAction:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
}

- (void)setupConflictMessage:fileName forOperationName:operationName
{
	NSString *localized_operation = NSLocalizedString(operationName, @"");
	[conflictMessage setStringValue:
	 [NSString stringWithFormat:conflictMessageTemplate, fileName, localized_operation]];
}

- (void)didEndAskReplaceSheet:(NSWindow *)sheet
				   returnCode:(int)returnCode contextInfo:(void *)info
{
    applyAllFlag = ([applyAllSwitch state] == NSOnState);
	[sheet orderOut:self];
	
	BOOL replaceFlag;
	switch (returnCode) {
		case kPerformReplacing:
			replaceFlag = YES;
			[afterSheetInvocation setArgument:&replaceFlag atIndex:3];
			[afterSheetInvocation invoke];
			break;
		case kStopAll:
			[afterSheetInvocation setArgument:[NSNull null] atIndex:2];
			[afterSheetInvocation invoke];
			break;
		case kCancelForItem:
			replaceFlag = NO;
			[afterSheetInvocation setArgument:&replaceFlag atIndex:3];
			[afterSheetInvocation invoke];
			break;
	}
	
}

#pragma mark subcontract of drag and drop
- (NSInvocation *)setupAfterSheetInvocation:(SEL)aSelector
{
	self.afterSheetInvocation  = [NSInvocation invocationWithMethodSignature:
									[self methodSignatureForSelector:aSelector]];
	[afterSheetInvocation setSelector:aSelector];
	[afterSheetInvocation retainArguments];
	[afterSheetInvocation setTarget:self];
	
	return afterSheetInvocation;
}

- (void)moveFileTreeNode:(NSTreeNode *)targetNode withReplacing:(BOOL)replaceFlag
{
	if (targetNode && (![targetNode isEqual: [NSNull null]])) {
		FileDatum *file_datum = [[targetNode representedObject] representedObject];
		NSString *target_path = [file_datum path];
		if ([destinationPath isEqualToString:[target_path stringByDeletingLastPathComponent]]) {
			[processedNodes addObject:targetNode];
		
		} else {
			NSFileManager *fm = [NSFileManager defaultManager];
			NSString *target_name = [target_path lastPathComponent];
			NSString *new_path = [destinationPath stringByAppendingPathComponent:
													  target_name];
			if (![fm movePath:target_path toPath:new_path handler:nil]) {
				if (![fm fileExistsAtPath:new_path]) {
					NSLog(@"destination path : %@ does not exist. Bail faild to move.", new_path);
					goto skip;
				}
				
				if (replaceFlag) {
					NSPredicate *name_predicate = [NSPredicate predicateWithFormat:
													 @"representedObject.name like %@", target_name];
					NSArray *conflict_nodes = [[destinationNode childNodes] 
											   filteredArrayUsingPredicate:name_predicate];
					if ([fm removeFileAtPath:new_path handler:nil]) {
						[fm movePath:target_path toPath:new_path handler:nil];
					} else {
						NSLog(@"Failed to remove :%@.", new_path);
						goto skip;
					}
					[nodesToDelete addObjectsFromArray:conflict_nodes];
				} else {
					BOOL is_single = (restItemsCount <= 1);
					[applyAllSwitch setHidden:is_single];
					[cancelForItemButton setHidden:is_single];
					[afterSheetInvocation setArgument:&targetNode atIndex:2];
					[self setupConflictMessage:[file_datum name] forOperationName:@"moving"];
					[iconInConflictErrorWindow setImage:
						[[NSWorkspace sharedWorkspace] iconForFile:target_path]];
					[NSApp beginSheet: conflictErrorWindow
					   modalForWindow: [outlineView window]
						modalDelegate: self
					   didEndSelector: @selector(didEndAskReplaceSheet:returnCode:contextInfo:)
						  contextInfo: nil];
					return;
				}
			} 
			[processedNodes addObject:targetNode];
		}
skip:
		restItemsCount--;
		if (!applyAllFlag) replaceFlag = NO;
		[self moveFileTreeNode:[nodeEnumerator nextObject] withReplacing:replaceFlag];
	}
	else {
		NSMutableSet *updated_file_data = [NSMutableSet setWithCapacity:[processedNodes count]];
		for (NSTreeNode *controller_node in processedNodes) {
			[updated_file_data addObject:[[controller_node representedObject] representedObject]];
		}
		[treeController moveNodes:processedNodes toIndexPath:destinationIndexPath];
		[treeController removeObjectsAtArrangedObjectIndexPaths:
										 [nodesToDelete valueForKeyPath:@"indexPath"]];
		[updated_file_data makeObjectsPerformSelector:@selector(saveOrder)];
		[[destinationNode representedObject] saveOrder];
	}
}

- (void)insertChildrenCopyingPaths:(NSArray *)sourcePaths
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *child_nodes = [destinationNode mutableChildNodes];
	NSUInteger index_len = [destinationIndexPath length];
	NSUInteger indexes[index_len];
	[destinationIndexPath getIndexes:indexes];
	for (NSString *a_source in sourcePaths) {
		NSString *target_path = [destinationPath stringByAppendingPathComponent:
										   [a_source lastPathComponent]];
		target_path = [target_path uniqueName];
		[fm copyPath:a_source toPath:target_path handler:nil];
		NewFileTreeNode *newnode = [[FileDatum fileDatumWithPath:target_path] treeNode];
		[child_nodes insertObject:newnode atIndex:indexes[index_len-1]++];
	}
}

#pragma mark drag and drop
/*
 Beginning the drag from the outline view.
 */
- (BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray *)items 
												toPasteboard:(NSPasteboard *)pboard {
    // Tell the pasteboard what kind of data we'll be placing on it
    [pboard declareTypes:[NSArray arrayWithObjects:MovedNodesType, NSFilesPromisePboardType, nil] 
										owner:self];
    // Query the NSTreeNode (not the underlying Core Data object) for its index path 
	// under the tree controller.
    //NSIndexPath *pathToDraggedNode = [[items objectAtIndex:0] indexPath];
	NSArray *index_pathes = [items valueForKeyPath:@"indexPath"];
    // Place the index path on the pasteboard.
	 NSData *indexPathData = [NSKeyedArchiver archivedDataWithRootObject:index_pathes];
    [pboard setData:indexPathData forType:MovedNodesType];
    // Return YES so that the drag actually begins...
	[pboard setPropertyList:[items valueForKeyPath:@"representedObject.representedObject.typeForPboard"] 
					forType:NSFilesPromisePboardType];

    return YES;
}

/*
 Validating a drop in the outline view. This method is called to determine whether or not to permit a drop operation. There are two cases in which this application will not permit a drop to occur:
 • A node cannot be dropped onto one of its descendents
 • A node cannot be dropped "between" two other nodes. That would imply some kind of ordering, which is not provided for in the data model.
 */
- (NSDragOperation)outlineView:(NSOutlineView *)olv 
				  validateDrop:(id <NSDraggingInfo>)info 
				  proposedItem:(id)proposed_node proposedChildIndex:(NSInteger)index {
#if useLog
    NSLog(@"start validateDrop");
#endif	
    NSDragOperation result = NSDragOperationNone;
	BOOL is_valid_target_node = YES;
	// The index indicates whether the drop would take place directly on an item or between two items. 
    // Between items implies that sibling ordering is supported (it's not in this application),
    // so we only indicate a valid operation if the drop is directly over (index == -1) an item.
	if (index == NSOutlineViewDropOnItemIndex) {
		is_valid_target_node = [[[proposed_node representedObject] representedObject] isContainer];
	}
	
    // Retrieve the index path from the pasteboard.
    NSArray *dropped_index_pathes = nil;
	if (is_valid_target_node) {
		if ([info draggingSource] == olv) {
			NSData *pboard_data = [[info draggingPasteboard] dataForType:MovedNodesType];
			if (pboard_data) {
				dropped_index_pathes = [NSKeyedUnarchiver unarchiveObjectWithData:pboard_data];
			} else {
				result = NSDragOperationNone;
				goto bail; 
			}
			NSIndexPath *proposed_index_path = [proposed_node indexPath];
			if ([proposed_index_path isDescendantOfIndexPathInArray:dropped_index_pathes]) {
				result = NSDragOperationNone;
				goto bail; 
			}			
		// } else {
			// drop from finder
		}
	} else {
		result = NSDragOperationNone;
		goto bail; 
	}

	if (isOptionKeyDown()) {
		result = NSDragOperationCopy;
	}
	else {
		result = NSDragOperationMove;
	}
	
bail:	
	return result;
}

/*
 Performing a drop in the outline view. This allows the user to manipulate the structure of the tree by moving subtrees under new parent nodes.
 */
- (BOOL)outlineView:(NSOutlineView *)olv acceptDrop:(id <NSDraggingInfo>)info 
			   item:(id)proposed_node childIndex:(NSInteger)index {
	
	index = (index==NSOutlineViewDropOnItemIndex ? 0:index);
	NSTreeNode *root_node = [treeController arrangedObjects]; //instance variable rootNode does not work.
	if (proposed_node) {
		[self setDestinationWithNode:[proposed_node representedObject] 
						 atIndexPath:[[proposed_node indexPath] indexPathByAddingIndex:index]];
	} else {
		[self setDestinationWithNode:rootNode
						 atIndexPath:[NSIndexPath indexPathWithIndex:index]];
	}
	
	NSPasteboard *pboard = [info draggingPasteboard];
    // Do the appropriate thing depending on wether the data is 
	//          DragDropSimplePboardType or NSStringPboardType.
    if ([pboard availableTypeFromArray: [NSArray arrayWithObjects:MovedNodesType, nil]]) {
		NSArray *dragged_index_pathes = [NSKeyedUnarchiver unarchiveObjectWithData:
										 [pboard dataForType:MovedNodesType]];
		NSArray *uniq_dragged_idxp = [NSIndexPath minimumIndexPathesCoverFromIndexPathesArray:
													dragged_index_pathes];
		restItemsCount = [uniq_dragged_idxp count];
		NSMutableArray *uniq_dragged_nodes = [NSMutableArray arrayWithCapacity:restItemsCount];
		for (NSIndexPath *idxp in uniq_dragged_idxp) {
			[uniq_dragged_nodes addObject:[root_node descendantNodeAtIndexPath:idxp]];
		}
		
		if (isOptionKeyDown()) {
			NSArray *source_paths = [uniq_dragged_nodes valueForKeyPath:
										@"representedObject.representedObject.path"];
			[self insertChildrenCopyingPaths:source_paths];
			[treeController setSelectionIndexPaths:
							 [uniq_dragged_nodes valueForKeyPath:@"indexPath"]];
			[[destinationNode representedObject] saveOrder];
		}
		else {
			self.nodeEnumerator = [uniq_dragged_nodes objectEnumerator];

			applyAllFlag = NO;
			self.processedNodes = [NSMutableArray arrayWithCapacity:restItemsCount];
			self.nodesToDelete = [NSMutableArray array];
			[self setupAfterSheetInvocation:
									@selector(moveFileTreeNode:withReplacing:)];
			id next_item = [nodeEnumerator nextObject];
			[afterSheetInvocation setArgument:&next_item atIndex:2];
			BOOL replace_flag = NO;
			[afterSheetInvocation setArgument:&replace_flag atIndex:3];
			[afterSheetInvocation invoke];
		}
	} 
	else if ([pboard availableTypeFromArray:
			  [NSArray arrayWithObjects:NSFilenamesPboardType, nil]] != nil) {
		NSArray *path_array = [pboard propertyListForType:NSFilenamesPboardType];
		[self insertChildrenCopyingPaths:path_array];
	}	
	
    return YES;
}

#pragma mark actions 
- (BOOL)respondsToSelector:(SEL)aSelector
{
	NSInteger clicked_row = [outlineView clickedRow];
	BOOL has_clicked_row = (clicked_row != -1);
	BOOL has_selection = ([[treeController selectedNodes] count] > 0);

	if (aSelector == @selector(dupulicateSelection:)) 
		return (has_clicked_row || has_selection);
	
	if (aSelector == @selector(renameSelection:))
		return (has_clicked_row);
	
	if (aSelector == @selector(deleteSelection:)) {
#if useLog		
		NSLog(@"Respond to deleteSelection : %d", (has_clicked_row || has_selection));
#endif		
		return (has_clicked_row || has_selection);
	}
	
	if (aSelector == @selector(revealSelection:))
		return (has_clicked_row || has_selection);
	
	if (aSelector == @selector(openSelection:))
		return (has_clicked_row || has_selection);

	if (aSelector == @selector(updateSelection:))
		return (has_clicked_row || has_selection);

	return [[self class] instancesRespondToSelector:aSelector];
}

- (IBAction)deleteSelection:(id)sender
{
	NSMutableArray *src_nodes = [[treeController selectedNodes] mutableCopy];
	NSInteger clicked_row = [outlineView clickedRow];
	NSTreeNode *clicked_node = nil;
	if ((clicked_row != -1) && ![outlineView isRowSelected:clicked_row]) {
		clicked_node = [outlineView itemAtRow:clicked_row];
		[src_nodes addObject:clicked_node];
	}
	
	NSArray *min_index_pathes = [NSIndexPath minimumIndexPathesCoverFromIndexPathesArray:
								 [src_nodes valueForKeyPath:@"indexPath"]];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSMutableSet *updated_nodes = [NSMutableSet set];
	
	for (NSIndexPath *an_indexpath in min_index_pathes) {
		NSTreeNode *controller_node = [[treeController arrangedObjects] descendantNodeAtIndexPath:an_indexpath];
		NSTreeNode *file_tree_node = [controller_node representedObject];
		NSString *a_path = [[file_tree_node representedObject] path];
		NSString *dir_path = [a_path stringByDeletingLastPathComponent];
		NSString *a_name = [a_path lastPathComponent];
		[workspace performFileOperation:NSWorkspaceRecycleOperation 
								 source:dir_path destination:nil 
								  files:[NSArray arrayWithObject:a_name] tag:nil];
		[updated_nodes addObject:[file_tree_node parentNode]];
	}
	
	[treeController remove:self];
	if (clicked_node) {
		[treeController removeObjectAtArrangedObjectIndexPath:[clicked_node indexPath]];
	}
	
	for (NewFileTreeNode *a_node in updated_nodes) {
		[(FileDatum *)[a_node representedObject] saveOrder];
	}
}

- (IBAction)renameSelection:(id)sender
{
	NSString *column_id = @"displayName";
	NSUInteger clicked_row = [outlineView clickedRow];
	NSTableColumn *column = [outlineView tableColumnWithIdentifier:column_id];
	[column setEditable:YES];
	[outlineView editColumn:[outlineView columnWithIdentifier:column_id] 
								row:clicked_row withEvent:nil select:YES];
}

- (IBAction)makeFolder:(id)sender
{
#if useLog
	NSLog(@"start makeFolder in FileTreeDataController");
#endif	
	NSUInteger clicked_row = [outlineView clickedRow];
	NSTreeNode *clicked_node = nil;
	if (clicked_row == -1) {
		clicked_node = [[[treeController selectedNodes] lastObject] representedObject];
	} else {
		clicked_node = [[outlineView itemAtRow:clicked_row] representedObject];
	}
	
	if (!clicked_node) {
		clicked_node = rootNode;
	}
		
	FileDatum *node_data = [clicked_node representedObject];
	NSIndexPath *clicked_index_path = [clicked_node indexPath];

	FileDatum *parent_node_data;
	NSString *untitled_folder_name = NSLocalizedString(@"Untitled", @"The name of untitled new folder");
	NSIndexPath *insert_index_path;
	
	if ([node_data isContainer]){
		parent_node_data = node_data;
		insert_index_path = [clicked_index_path indexPathByAddingIndex:0];
	} else {
		NSTreeNode *parent_node = [[node_data treeNode] parentNode];
		parent_node_data = [parent_node representedObject];
		insert_index_path = [clicked_index_path indexPathByIncrementLastIndex:1];
	}
	
	NSString *new_path = [[parent_node_data path] stringByAppendingPathComponent:untitled_folder_name];
	new_path = [new_path uniqueName];
	NSFileManager *file_manager = [NSFileManager defaultManager];
	if (![file_manager createDirectoryAtPath:new_path attributes:nil]) return;
	
	FileDatum *folder_dataum = [FileDatum fileDatumWithPath:new_path];
	[[[parent_node_data treeNode] mutableChildNodes] 
				insertObject:[folder_dataum treeNode] atIndex:[insert_index_path lastIndex]];
	[treeController setSelectionIndexPath:insert_index_path];
	[parent_node_data saveOrder];
}

- (IBAction)dupulicateSelection:(id)sender
{
	NSMutableArray *src_nodes = [[treeController selectedNodes] mutableCopy];
	NSInteger clicked_row = [outlineView clickedRow];
	if (clicked_row != -1) {
		NSTreeNode *clicked_node = [outlineView itemAtRow:clicked_row];
		[src_nodes addObject:clicked_node];
	}
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSUInteger n_src = [src_nodes count];
	NSMutableArray *new_nodes = [NSMutableArray arrayWithCapacity:n_src];
	
	for (NSTreeNode *a_node in src_nodes) {
		NSIndexPath *new_indexpath = [[a_node indexPath] indexPathByIncrementLastIndex:1];
		NSTreeNode *a_src_node = [a_node representedObject];
		NSString *src_path = [[a_src_node representedObject] path];
		NSTreeNode *parent_node = [a_src_node parentNode];
		NSString *target_path = [[[parent_node representedObject] path] stringByAppendingPathComponent: 
												[src_path lastPathComponent]];
		target_path = [target_path uniqueName];							
		[fm copyPath:src_path toPath:target_path handler:nil];
		NSTreeNode *a_new_node = [[FileDatum fileDatumWithPath:target_path] treeNode];
		[[parent_node mutableChildNodes] insertObject:a_new_node atIndex:[new_indexpath lastIndex]];
		[new_nodes addObject:[[treeController arrangedObjects] descendantNodeAtIndexPath:new_indexpath]];
	}	
	[treeController setSelectionIndexPaths:[new_nodes valueForKeyPath:@"indexPath"]];
}

- (IBAction)revealSelection:(id)sender
{
	NSMutableArray *src_nodes = [[treeController selectedNodes] mutableCopy];
	NSInteger clicked_row = [outlineView clickedRow];
	if (clicked_row != -1) {
		NSTreeNode *clicked_node = [outlineView itemAtRow:clicked_row];
		[src_nodes addObject:clicked_node];
	}
	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	for (NSTreeNode *a_node in src_nodes) {
		NSString *a_path = [[[a_node representedObject] representedObject] path];
		[workspace selectFile:a_path inFileViewerRootedAtPath:@""];
	}
	[SmartActivate activateAppOfIdentifier:@"com.apple.finder"];
}


- (IBAction)openSelection:(id)sender
{
	NSMutableArray *src_nodes = [[treeController selectedNodes] mutableCopy];
	NSInteger clicked_row = [outlineView clickedRow];
	if (clicked_row != -1) {
		NSTreeNode *clicked_node = [outlineView itemAtRow:clicked_row];
		[src_nodes addObject:clicked_node];
	}
	
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	for (NSTreeNode *a_node in src_nodes) {
		NSString *a_path = [[[a_node representedObject] representedObject] path];
		[workspace openFile:a_path];
	}
}

- (IBAction)updateSelection:(id)sender
{
	NSMutableArray *src_nodes = [[treeController selectedNodes] mutableCopy];
	NSInteger clicked_row = [outlineView clickedRow];
	if (clicked_row != -1) {
		NSTreeNode *clicked_node = [outlineView itemAtRow:clicked_row];
		[src_nodes addObject:clicked_node];
	}
	
	for (NSTreeNode *controller_node in src_nodes) {
		FileDatum *a_datum = [[controller_node representedObject] representedObject];
		[a_datum update];
	}
}

@end
