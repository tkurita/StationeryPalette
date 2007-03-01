#import "FileTreeDataSource.h"

#import "FileTreeNode.h"
#import "NSOutlineView_Extensions.h"
#import "FileTreeViewDataSource.h"
#import "ImageAndTextCell.h"
#import "NSArray_Extensions.h"
#include "FileTreeView.h"

#define useLog 1

static NSString *MovedNodesType = @"MOVED_Nodes_TYPE";

BOOL isOptionKeyDown()
{
	UInt32 mod_key_status = GetCurrentKeyModifiers();
	return ((mod_key_status & optionKey) != 0);
}

@implementation FileTreeDataSource

- (FileTreeNode *)getRootInfo
{
	if (!fileTreeRoot) {
		fileTreeRoot = [[FileTreeNode fileTreeNodeWithPath:rootDirectory parent:nil] retain];
	}
	return fileTreeRoot;
}

- (void) dealloc {
	[updatedNodes release];
	[fileTreeRoot release];
	[nodeOperationInvocation release];
	[afterSheetInvocation release];
	[conflictMessageTemplate release];
	[rootDirectory release];
	[super dealloc];
}

- (id)init
{
	self = [super init];
	if (self) {
		isRootUpdated = NO;
		isNeededToScroll = NO;
		updatedNodes = nil;
		itemsToSelect = nil;
		nodeEnumerator = nil;
		nodeOperationInvocation = nil;
		afterSheetInvocation = nil;
		//rootDirectory = @"/Users/tkurita/Dev/Projects/FileTree/Stationery";
		rootDirectory = [[[NSUserDefaults standardUserDefaults] stringForKey:@"FileTreeRoot"] retain];
	}
	
	return self;
}

- (void)awakeFromNib
{
	
	[_outline setAutoresizesOutlineColumn:NO];
	[_outline setSearchColumnIdenteifier:@"displayName"];

	[_outline registerForDraggedTypes: 
		[NSArray arrayWithObjects:MovedNodesType, NSFilenamesPboardType, nil]];
			
	[_outline setDraggingSourceOperationMask:NSDragOperationCopy|NSDragOperationDelete forLocal:NO];
	//[_outline setDraggingSourceOperationMask:NSDragOperationDelete forLocal:NO];
	//[_outline setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	//[_outline setDraggingSourceOperationMask:NSDragOperationNone forLocal:YES];
	//[_outline setDraggingSourceOperationMask:NSDragOperationAll_Obsolete forLocal:NO];
	conflictMessageTemplate = [[conflictMessage stringValue] retain];;
}

- (FileTreeNode *)nodeWithIndexPath:(NSIndexPath *)indexPath
{
	return [fileTreeRoot childWithIndexPath:indexPath currentLevel:0];
}

#pragma mark methods for debug
- (IBAction)reloadFileTreeNodes:(id)sender
{
	[fileTreeRoot reloadChildrenWithView:_outline];
	[_outline reloadData];
}

- (IBAction)reloadData:(id)sender
{
	[_outline reloadData];
}

#pragma mark methods to manage updated node
- (void)reloadUpdatedNodes:(FileTreeView *)ftv
{
	if (updatedNodes == nil) return;
	
	NSEnumerator *enumerator = [updatedNodes objectEnumerator];
	FileTreeNode *item;
	if (isRootUpdated) {
		[ftv reloadData];
		while (item = [enumerator nextObject]) {
			[item saveOrderWithView:ftv];
		}
	} 
	else {
		while (item = [enumerator nextObject]) {
			[ftv reloadItem:item reloadChildren:YES];
			[item saveOrderWithView:ftv];
		}
	}
	
	[updatedNodes release];
	updatedNodes = nil;
	isRootUpdated = NO;
} 

- (void)addUpdatedNode:(FileTreeNode *)aNode
{
	if (updatedNodes == nil) updatedNodes = [[NSMutableSet set] retain];;
	
	[updatedNodes addObject:aNode];
	if (!isRootUpdated) {
		isRootUpdated = ([aNode nodeParent] == nil);
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
			[self cleanupDragMoveOrCopy];
			break;
		case kCancelForItem:
			replaceFlag = NO;
			[afterSheetInvocation setArgument:&replaceFlag atIndex:3];
			[afterSheetInvocation invoke];
			break;
	}
	
}

- (void)setupConflictMessage:fileName
{
	[conflictMessage setStringValue:
		[NSString stringWithFormat:conflictMessageTemplate, fileName, currentOperationName]];
}
#pragma mark methods of subcontract of drag&drop
- (void)setupAfterSheetInvocation:(SEL)aSelector
{
	if (afterSheetInvocation) {
		[afterSheetInvocation release];
	}
	
	afterSheetInvocation  = [[NSInvocation invocationWithMethodSignature:
					[self methodSignatureForSelector:aSelector]] retain];
	[afterSheetInvocation setSelector:aSelector];
	[afterSheetInvocation retainArguments];
	[afterSheetInvocation setTarget:self];
}

- (void)setupNodeOperationInvocation:(SEL)aSelector
{
	if (nodeOperationInvocation) {
		[nodeOperationInvocation release];
	}
	
	nodeOperationInvocation  = [[NSInvocation invocationWithMethodSignature:
					[destinationNode methodSignatureForSelector:aSelector]] retain];
	[nodeOperationInvocation setSelector:aSelector];
	[nodeOperationInvocation retainArguments];
	[nodeOperationInvocation setTarget:destinationNode];
	SEL dummy = nil;
	[nodeOperationInvocation setArgument:&dummy atIndex:4];
}

- (void)askCopyOrMoveDidEnd:(NSAlert *)alert 
				returnCode:(int)returnCode contextInfo:(NSDictionary *)adding_info
{
	if (returnCode == NSAlertThirdButtonReturn) {
		isNeededToScroll = NO;
		[self cleanupDragMoveOrCopy];
		return;
	}
	
	SEL copy_or_move;
	switch (returnCode) {
		case NSAlertFirstButtonReturn :
			copy_or_move = @selector(createChildWithCopyingPath:atIndex:withReplacing:);
			currentOperationName = @"copying";
			break;
		case NSAlertSecondButtonReturn :
			copy_or_move = @selector(createChildWithMovingPath:atIndex:withReplacing:);
			currentOperationName = @"moving";
			break;
	}
	
	[self setupNodeOperationInvocation:copy_or_move];
	[self setupAfterSheetInvocation:@selector(addNodeFromPath:withReplacing:)];
	id next_item = [nodeEnumerator nextObject];
	[afterSheetInvocation setArgument:&next_item atIndex:2];
	BOOL replaceFlag = NO;
	[afterSheetInvocation setArgument:&replaceFlag atIndex:3];
	[afterSheetInvocation performSelectorOnMainThread:@selector(invoke) 
						withObject:nil waitUntilDone:NO];

}

- (void)addNodesWithPaths:(NSArray *)pathArray toNode:(FileTreeNode *)node atIndex:(int)childIndex
{
	nodeEnumerator = [[pathArray objectEnumerator] retain];
	restItemsCount = [pathArray count];
	insertIndex = childIndex;
	destinationNode = node;
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Copy"];
	[alert addButtonWithTitle:@"Move"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setMessageText:
		NSLocalizedString(@"Appending an item into FileTreeView", @"message to choose appending method")];
	[alert setInformativeText:
		NSLocalizedString(@"Choose copy or move", @"infomative text to choose appending method")];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:[_outline window] modalDelegate:self 
			didEndSelector:@selector(askCopyOrMoveDidEnd:returnCode:contextInfo:)
			contextInfo:nil];
}

- (void)cleanupDragMoveOrCopy
{

	[nodeEnumerator release];
	nodeEnumerator = nil;
	[self reloadUpdatedNodes:_outline];
	if (itemsToSelect != nil) {
		[_outline selectItems:itemsToSelect byExtendingSelection: NO];
		[itemsToSelect release];
		itemsToSelect = nil;
	}
	
	if (isNeededToScroll) {
		FileTreeNode *node = nil;
		[nodeOperationInvocation getReturnValue:&node];
		if (node) [_outline scrollRowToVisible:[_outline rowForItem:node]];
		isNeededToScroll = NO;
	}
}

- (void)addNodeFromPath:(NSString *)sourcePath withReplacing:(BOOL)replaceFlag
{
	if (sourcePath != nil) {
		[nodeOperationInvocation setArgument:&sourcePath atIndex:2];
		int *tmp_p = &insertIndex;
		int **tmp_pp = &tmp_p;
		[nodeOperationInvocation setArgument: tmp_pp atIndex:3];
		[nodeOperationInvocation setArgument: &replaceFlag atIndex:4];
		//[nodeOperationInvocation retainArguments];

		@try {
			[nodeOperationInvocation invoke];
			[self addUpdatedNode:destinationNode];
		}
		@catch (NSException *exception) {
			if ([[exception name] isEqualToString:@"FileMoveOrCopyException"]) {
				if (!applyAllFlag) {
					BOOL isSingle = (restItemsCount <= 1);
					[applyAllSwitch setHidden:isSingle];
					[cancelForItemButton setHidden:isSingle];
					[self setupConflictMessage:[sourcePath lastPathComponent]];
					[afterSheetInvocation setArgument:&sourcePath atIndex:2];
					[iconInConflictErrorWindow setImage:
						[[NSWorkspace sharedWorkspace] iconForFile:sourcePath]];
					[NSApp beginSheet: conflictErrorWindow
						modalForWindow: [_outline window]
						modalDelegate: self
						didEndSelector: @selector(didEndAskReplaceSheet:returnCode:contextInfo:)
						contextInfo: nil];
				}
				return;
			}
			else {
				@throw;
			}
		}
		restItemsCount--;
		insertIndex++;
		if (!applyAllFlag) replaceFlag = NO;
		[self addNodeFromPath:[nodeEnumerator nextObject] withReplacing:replaceFlag];
	}
	else {
		[self cleanupDragMoveOrCopy];
	}
}

- (void)moveFileTreeNode:(FileTreeNode *)targetNode withReplacing:(BOOL)replaceFlag
{
	if (targetNode != nil) {
		FileTreeNode *source_parent = (FileTreeNode*)[targetNode nodeParent];
		@try {
			[destinationNode insertChildWithMove:targetNode
						atIndex:&insertIndex withReplacing:replaceFlag];
			[self addUpdatedNode:destinationNode];
		}
		@catch (NSException *exception) {
			if ([[exception name] isEqualToString:@"FileMoveException"]) {
				if (!applyAllFlag) {
					BOOL isSingle = (restItemsCount <= 1);
					[applyAllSwitch setHidden:isSingle];
					[cancelForItemButton setHidden:isSingle];
					[afterSheetInvocation setArgument:&targetNode atIndex:2];
					currentOperationName = @"moving";
					[self setupConflictMessage:[[targetNode nodeData] name]];
					[NSApp beginSheet: conflictErrorWindow
						modalForWindow: [_outline window]
						modalDelegate: self
						didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
						contextInfo: nil];
				}
				return;
			}
			else {
				@throw;
			}
		}
		[self addUpdatedNode:source_parent];
		restItemsCount--;
		if (!applyAllFlag) replaceFlag = NO;
		insertIndex++;
		[self moveFileTreeNode:[nodeEnumerator nextObject] withReplacing:replaceFlag];
	}
	else {
		[self cleanupDragMoveOrCopy];
	}
}

- (void)_performDropOperation:(id <NSDraggingInfo>)info 
						onNode:(FileTreeNode*)parentNode atIndex:(int)childIndex {
    // Helper method to insert dropped data into the model. 
    NSPasteboard *pboard = [info draggingPasteboard];
    
    // Do the appropriate thing depending on wether the data is DragDropSimplePboardType or NSStringPboardType.
    if ([pboard availableTypeFromArray:
					[NSArray arrayWithObjects:MovedNodesType, nil]] != nil) {
        NSArray *uniqDraggedNodes
					 = [TreeNode minimumNodeCoverFromNodesInArray: draggedNodes];
        
		if (isOptionKeyDown()) {
			itemsToSelect = [parentNode insertChildrenWithCopy:uniqDraggedNodes 
											atIndex:childIndex];
			[self addUpdatedNode:parentNode];
			[self reloadUpdatedNodes:_outline];
			if (itemsToSelect != nil) {
				[_outline selectItems:itemsToSelect byExtendingSelection: NO];
			}
		}
		else {
			itemsToSelect = [[NSMutableArray arrayWithArray:
									[_outline allSelectedItems]] retain];
			nodeEnumerator = [[uniqDraggedNodes objectEnumerator] retain];
			restItemsCount = [uniqDraggedNodes count];
			insertIndex = childIndex;
			destinationNode = parentNode;
			applyAllFlag = NO;
			
			[self setupAfterSheetInvocation:
								@selector(moveFileTreeNode:withReplacing:)];
			id next_item = [nodeEnumerator nextObject];
			[afterSheetInvocation setArgument:&next_item atIndex:2];
			[afterSheetInvocation invoke];
		}
	} 
	else if ([pboard availableTypeFromArray:
				[NSArray arrayWithObjects:NSFilenamesPboardType, nil]] != nil) {
		NSArray *path_array = [pboard propertyListForType:NSFilenamesPboardType];
		[self addNodesWithPaths:path_array toNode:parentNode atIndex:childIndex];
	}	
}

#pragma mark methods for drag & drop
- (BOOL)outlineView:(NSOutlineView *)olv
			writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pboard
{
#if useLog
	NSLog(@"start outlineView:writeItems:toPasteboard:");
#endif
	draggedNodes = items;
    
//	[pboard declareTypes: 
//		[NSArray arrayWithObjects:MovedNodesType, NSStringPboardType, 
//				NSFilesPromisePboardType, NSFilenamesPboardType, nil] owner:self];
	[pboard declareTypes: 
		[NSArray arrayWithObjects:MovedNodesType, 
				 NSFilesPromisePboardType, nil] owner:self];

	
    // the actual data doesn't matter 
	// since MovedNodesType drags aren't recognized by anyone but us!.
    [pboard setData:[NSData data] forType:MovedNodesType]; 
    
    //[pboard setString: [draggedNodes description] forType: NSStringPboardType];
	//[pboard setPropertyList:[items valueForKey:@"path"] forType:NSFilenamesPboardType];
		
	//	[pboard setPropertyList:[NSArray array] forType:NSFilesPromisePboardType];
	//[pboard setPropertyList:[NSArray arrayWithObjects:@"dic", nil] forType:NSFilesPromisePboardType];
	[pboard setPropertyList:[items valueForKeyPath:@"nodeData.typeForPboard"] forType:NSFilesPromisePboardType];

    return YES;
}

- (unsigned int)outlineView:(NSOutlineView*)olv 
			validateDrop:(id <NSDraggingInfo>)info 
			proposedItem:(id)item proposedChildIndex:(int)childIndex
{
    // This method validates whether or not the proposal is a valid one. Returns NO if the drop should not be allowed.
	FileTreeNode *targetNode = item;
    BOOL targetNodeIsValid = YES;
	
	BOOL isOnDropTypeProposal = childIndex==NSOutlineViewDropOnItemIndex;
#if useLog
//    NSLog(@"start validateDrop");
//	NSLog(@"childIndex : %i", childIndex);
//	NSLog(@"NSOutlineViewDropOnItemIndex : %i", NSOutlineViewDropOnItemIndex);
#endif

	if (isOnDropTypeProposal) {
		targetNodeIsValid = [[targetNode nodeData] isContainer];
	}
	// Check to make sure we don't allow a node to be inserted into one of its descendants!
	if (targetNodeIsValid && ([info draggingSource]==_outline) && 
			[[info draggingPasteboard] availableTypeFromArray:
							[NSArray arrayWithObject: MovedNodesType]] != nil) {
		targetNodeIsValid = ![targetNode isDescendantOfNodeInArray: draggedNodes];
	}
	
	unsigned int result;
	if (targetNodeIsValid) {
		if (isOptionKeyDown()) {
			result = NSDragOperationCopy;
		}
		else {
			result = NSDragOperationMove;
		}
	}
	else {
		result = NSDragOperationNone;
	}
	
	return result;
}

- (BOOL)outlineView:(NSOutlineView*)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)targetItem childIndex:(int)childIndex
{
#if useLog
    NSLog(@"start acceptDrop");
#endif
	FileTreeNode *parentNode = nil;
          
	if (targetItem == nil) {
		parentNode = fileTreeRoot;
	}
	else {
		parentNode = targetItem;
	}
	childIndex = (childIndex==NSOutlineViewDropOnItemIndex ? 0:childIndex);
    
    [self _performDropOperation:info onNode:parentNode atIndex:childIndex];
    return YES;
}

- (NSArray *)outlineView:(NSTableView *)tv 
			namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination 
											forDraggedItems:(NSArray *)items {
#if useLog
	NSLog(@"start namesOfPromisedFilesDroppedAtDestination");
#endif	
	NSMutableArray *filenames = [NSMutableArray array];
	NSEnumerator *aEnumerator = [items objectEnumerator];
	FileTreeNode *aNode;
	NSString *sourcePath;
	NSString *destinationPath;
	NSString *a_name;
	promisedFiles = [[NSMutableArray alloc] init];
	
	while (aNode = [aEnumerator nextObject]) {
		sourcePath = [[aNode nodeData] path];
		a_name = [sourcePath lastPathComponent];
		destinationPath = [[dropDestination path] stringByAppendingPathComponent:a_name];
		NSDictionary *promised_file_dict = [NSDictionary dictionaryWithObjectsAndKeys:
					aNode, @"sourceNode", destinationPath, @"destination", nil];
		[filenames addObject:a_name];
		[promisedFiles addObject:promised_file_dict];
	}
	return ([filenames count] ? filenames : nil);
}

- (void)copyPromisedFile:(NSDictionary *)promisedInfo replacing:(BOOL)replaceFlag
{
	if (promisedInfo != nil) {
		currentOperationName = @"copying";
		NSFileManager *file_manager = [NSFileManager defaultManager];
		NSString *destinationPath = [promisedInfo objectForKey:@"destination"];
		NSString *sourcePath = [[promisedInfo objectForKey:@"sourceNode"] path];
		if (![file_manager copyPath:sourcePath toPath:destinationPath handler:nil] ) {
			if (replaceFlag) {
				[file_manager removeFileAtPath:destinationPath handler:nil];
				[self copyPromisedFile:promisedInfo replacing:replaceFlag];
			}
			else if (!applyAllFlag) {
				BOOL isSingle = (restItemsCount <= 1);
				[applyAllSwitch setHidden:isSingle];
				[cancelForItemButton setHidden:isSingle];
				[self setupConflictMessage:[sourcePath lastPathComponent]];
				[afterSheetInvocation setArgument:&promisedInfo atIndex:2];
				[iconInConflictErrorWindow setImage:
						[[NSWorkspace sharedWorkspace] iconForFile:sourcePath]];
				[NSApp beginSheet: conflictErrorWindow
					modalForWindow: [_outline window]
					modalDelegate: self
					didEndSelector: @selector(didEndAskReplaceSheet:returnCode:contextInfo:)
					contextInfo: nil];
				return;
			}

		}
		else {
			if (!applyAllFlag) replaceFlag = NO;
			restItemsCount--;
			[self copyPromisedFile:[nodeEnumerator nextObject] replacing:replaceFlag];
		}
	}
	else {
		[self cleanupDragMoveOrCopy];
	}

}

- (void)copyPromisedFiles:(id)sourceView
{
	if (promisedFiles == nil) return;
	
	nodeEnumerator = [[promisedFiles objectEnumerator] retain];
	[self setupAfterSheetInvocation:@selector(copyPromisedFile:replacing:)];
	id next_item = [nodeEnumerator nextObject];
	[afterSheetInvocation setArgument:&next_item atIndex:2];
	BOOL replaceFlag = NO;
	[afterSheetInvocation setArgument:&replaceFlag atIndex:3];
	restItemsCount = [promisedFiles count];
	[afterSheetInvocation invoke];
}

- (void)trashPromisedFiles:(id)sourceView
{
	if (promisedFiles == nil) return;
	
	NSArray *nodes = [promisedFiles valueForKey:@"sourceNode"];
	[self fileTreeView:sourceView deleteItems:nodes];
	[promisedFiles release];
	promisedFiles = nil;
}

#pragma mark data source methods of FileTreeView
- (void)fileTreeView:(FileTreeView *)ftv didEndDragOperation:(NSDragOperation)operation
{
	switch (operation) {
		case (NSDragOperationGeneric):
			[self copyPromisedFiles:ftv];
			break;
		case (NSDragOperationDelete):
			[self trashPromisedFiles:ftv];
			break;
	}
}

- (void)fileTreeView:(FileTreeView *)ftv addNodesWithPathes:(NSArray *)pathArray afterNode:(FileTreeNode *)node
{
	FileTreeNode *parent;
	BOOL is_root = NO;
	BOOL is_expanded = NO;
	int index = 0;
	if (node) {
		if ([ftv isItemExpanded:node]) {
			parent = node;
			is_expanded = YES;
			index = 0;
		}
		else {
			parent = (FileTreeNode *)[node nodeParent];
			is_root = ([parent nodeParent] == nil);
			index = [parent indexOfChild:node] + 1;
		}
			
	}
	else {
		parent = fileTreeRoot;
		index = [[fileTreeRoot children] count];
	}
	isNeededToScroll = YES;
	[self addNodesWithPaths:pathArray toNode:parent atIndex:index];
	
}

- (void)fileTreeView:(FileTreeView *)ftv makeFolderAfter:(FileTreeNode *)item
{
	FileTreeNode *parent;
	FileTreeNode *new_item;
	BOOL is_root = NO;
	BOOL is_expanded = NO;
	if (item) {
		if ([ftv isItemExpanded:item]) {
			is_expanded = YES;
		}
		else {
			parent = (FileTreeNode *)[item nodeParent];
			is_root = ([parent nodeParent] == nil);
		}
			
	}
	else {
		parent = fileTreeRoot;
		is_root = YES;
	}
	
	NSString *untitled_folder_name = NSLocalizedString(@"Untitled", @"The name of untitled new folder");
	if (is_expanded) {
		if (new_item = [item createFolderAtIndex:0 withName:untitled_folder_name]) {
			[ftv reloadItem:item reloadChildren:YES];
			[item saveOrderWithView:ftv];
		}
	}
	else {
		if (new_item = [parent createFolderAfter:item withName:untitled_folder_name] ) {
			if (is_root) {
				[ftv reloadData];
			}
			else {
				[ftv reloadItem:parent reloadChildren:YES];
			}
			[parent saveOrderWithView:ftv];
		}
	}
	
	if (new_item) {
		int the_row = [ftv rowForItem:new_item];
		[ftv selectRow:the_row byExtendingSelection:NO];
		[ftv editColumn:[ftv columnWithIdentifier:@"displayName"] 
				row:the_row withEvent:nil select:YES];
	}
}

- (void)fileTreeView:(FileTreeView *)ftv revealItems:(NSArray *)array
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSEnumerator *enumerator = [array objectEnumerator];
	FileTreeNode *item;
	while (item = [enumerator nextObject]) {
		[workspace selectFile:[[item nodeData] path] inFileViewerRootedAtPath:@""];
	}
}


- (void)fileTreeView:(FileTreeView *)ftv deleteItems:(NSArray *)array
{
	NSEnumerator *enumerator = [array objectEnumerator];
	FileTreeNode *item;
	while (item = [enumerator nextObject]) {
		FileTreeNode *parent = (FileTreeNode *)[item nodeParent];
		[parent removeChildWithFileDelete:item];
		[self addUpdatedNode:parent];
	}
	
	[self reloadUpdatedNodes:ftv];
}

- (void)fileTreeView:(FileTreeView *)ftv renameItem:(id)item intoName:newName
{
	if (![[(FileTreeNodeData *)[item nodeData] name] isEqualToString:newName]) {
		FileTreeNode *parent = (FileTreeNode *)[item nodeParent];
		if (![parent renameChild:item intoName:newName withView:ftv]) {
		
			NSString *message_template = NSLocalizedString(
				@"The name %@ have been used. Choose the other file name.",
				 @"The infomative text for conflicting file names when renaming");
			NSString *message = [NSString stringWithFormat:message_template, newName];
			
			NSString *alert_message = NSLocalizedString(
				@"Can't change the file name", 
				@"The alert message for conflicting file names when renaming");
				
			NSAlert *alert = [NSAlert alertWithMessageText:alert_message
								defaultButton:@"OK"
								alternateButton:nil otherButton:nil 
								informativeTextWithFormat:message];
								
			[alert beginSheetModalForWindow:[_outline window] 
					modalDelegate:nil 
					didEndSelector:nil
					contextInfo:nil];
		}
		[_outline reloadItem:item];
	}
}

- (void)fileTreeView:(FileTreeView *)ftv dupulicateItems:(NSArray *)array
{
	NSEnumerator *enumerator = [array objectEnumerator];
	FileTreeNode *item;
	while (item = [enumerator nextObject]) {
		FileTreeNode *parent = (FileTreeNode *)[item nodeParent];
		int index = [parent indexOfChild:item];
		[parent insertChildWithCopy:item atIndex:++index];
		[self addUpdatedNode:parent];
	}
	
	[self reloadUpdatedNodes:ftv];
}

#pragma mark delegate methods of outline view
- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	FileTreeView *ftv = [notification object];
	FileTreeNode *item = [[notification userInfo] objectForKey:@"NSObject"];
	[(FileTreeNode *)[item nodeParent] saveOrderWithView:ftv];
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	FileTreeView *ftv = [notification object];
	FileTreeNode *item = [[notification userInfo] objectForKey:@"NSObject"];
	[(FileTreeNode *)[item nodeParent] saveOrderWithView:ftv];
}

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell *)cell 
									forTableColumn:(NSTableColumn *)tableColumn 
									item:(id)item
{    
    id identifier = [tableColumn identifier];
	if ([identifier isEqualToString:@"displayName"]) {
        [cell setImage:[(FileTreeNodeData *)[item nodeData] iconImage]];
    }
	if ([item shouldExpand]) {
		[olv expandItem:item];
		[item setShouldExpand:NO];
	}
}

#pragma mark data source methods of outline view
- (BOOL)outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
#if useLog
	//NSLog([NSString stringWithFormat:@"start isItemExpandable for item : %@", [item description]]);
#endif
	if (!item) {
		item = [self getRootInfo];
	}

	return [(FileTreeNodeData *)[item nodeData] isContainer];
}

/* 指定したitemの子の数を返します */
- (int)outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
#if useLog
	NSLog([NSString stringWithFormat:@"start numberOfChildrenOfItem for item : %@", [item description]]);
#endif
	if (!item) {
		item = [self getRootInfo];
	}

	return [item numberOfChildren];
}

/* itemの、指定したインデックスの子のアイテムを返します */
- (id)outlineView:(NSOutlineView*)outlineView child:(int)index ofItem:(id)item
{
#if useLog
	//NSLog([NSString stringWithFormat:@"start child:%d ofItem: %@",index, [item description]]);
#endif
	if (!item) {
		item = [self getRootInfo];
	}
	id result = [item childAtIndex:index];

	return result;
}

- (id)outlineView:(NSOutlineView*)outlineView 
		objectValueForTableColumn:(NSTableColumn*)tableColumn
		byItem:(id)item
{
#if useLog
	//NSLog(@"start objectValueForTableColumn");
#endif
	id identifier = [tableColumn identifier];
	return [[item nodeData] valueForKey:identifier];
}

@end
