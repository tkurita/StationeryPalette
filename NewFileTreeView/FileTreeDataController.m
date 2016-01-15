#import "FileTreeDataController.h"
#import "ImageAndTextCell.h"
#import "NSIndexPath_Extensions.h"
#import "PathExtra.h"
#import "NSRunningApplication+SmartActivate.h"

#include <Carbon/Carbon.h>

#define useLog 0

@implementation FileTreeDataController

@synthesize rootDirectory;
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
	[_rootNode release];
	[rootDirectory release];
	[_afterSheetInvocation release];
	[_dndEnumerator release];
	[_destinationIndexPath release];
	[_processedNodes release];
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

	self.conflictMessageTemplate = [conflictMessage stringValue];
	id pre_responder = [outlineView window];
	[self setNextResponder: [pre_responder nextResponder]];
	[pre_responder setNextResponder:self];
    
    [outlineView setAutoresizesOutlineColumn:NO];
    
	[outlineView registerForDraggedTypes:
     [NSArray arrayWithObjects:MovedNodesType, NSFilenamesPboardType, nil]];
	[outlineView setDraggingSourceOperationMask:NSDragOperationCopy|NSDragOperationDelete forLocal:NO];
}

/* need to call from showWindow of window controller */
- (void)restoreSelectionWithKey:(NSString *)keyname
{
    NSData *ud_data = [[NSUserDefaults standardUserDefaults] objectForKey:keyname];
    if (ud_data) {
        NSArray *selection_indexpath = [NSKeyedUnarchiver unarchiveObjectWithData:ud_data];
        if ([selection_indexpath count]) {
            [treeController setSelectionIndexPaths:selection_indexpath];
            [outlineView scrollRowToVisible:[outlineView selectedRow]+1];
            // does not work in awakeFromNib and windowDidLoad.
            // must be placed in showWindow.
        }
    }
}

#pragma mark destinatioNode
- (void)setDestinationWithNode:(NewFileTreeNode *)aNode atIndexPath:anIndexPath
{
	self.destinationNode = aNode;
	self.destinationIndexPath = anIndexPath;
}

- (void)updateDestinationNode
{
    NSIndexPath *index_path = [treeController selectionIndexPath];
    NewFileTreeNode *a_node = _rootNode;
	if (index_path) {
		if ([index_path length]) {
			a_node = (NewFileTreeNode *)[_rootNode descendantNodeAtIndexPath:index_path];
            if ([[a_node representedObject] isContainer] && [a_node isExpanded] ) {
                index_path = [index_path indexPathByAddingIndex:0];
            } else {
                a_node = (NewFileTreeNode *)[a_node parentNode];
                index_path = [index_path indexPathByIncrementLastIndex:1];
            }
		} else {
			index_path = [NSIndexPath indexPathWithIndex:[[_rootNode childNodes] count]];
		}
	} else {
		index_path = [NSIndexPath indexPathWithIndex:[[_rootNode childNodes] count]];
	}
    self.destinationNode = a_node;
	self.destinationIndexPath = index_path;
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

- (NSString *)outlineView:(NSOutlineView *)olv typeSelectStringForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSString *cid = [tableColumn identifier] ;
    if ([cid isEqualTo:@"displayName"] ) {
        NSCell *a_cell = [olv preparedCellAtColumn:[olv columnWithIdentifier:cid]
                           row:[olv rowForItem:item]];
        return [a_cell stringValue] ;
    } else {
        return nil;
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
    id dummynil = nil;
	BOOL replaceFlag;
	switch (returnCode) {
		case kPerformReplacing:
			replaceFlag = YES;
			[_afterSheetInvocation setArgument:&replaceFlag atIndex:4];
			[_afterSheetInvocation invoke];
			break;
		case kStopAll:
            [_afterSheetInvocation setArgument:&dummynil atIndex:2];
			[_afterSheetInvocation invoke];
			break;
		case kCancelForItem:
			replaceFlag = NO;
			[_afterSheetInvocation setArgument:&replaceFlag atIndex:4];
			[_afterSheetInvocation invoke];
			break;
	}
	
}

#pragma mark subcontract of drag and drop, private
- (NSInvocation *)setupAfterSheetInvocation:(SEL)aSelector
{
	self.afterSheetInvocation  = [NSInvocation invocationWithMethodSignature:
									[self methodSignatureForSelector:aSelector]];
	[_afterSheetInvocation setSelector:aSelector];
	[_afterSheetInvocation retainArguments];
	[_afterSheetInvocation setTarget:self];
	
	return _afterSheetInvocation;
}

- (void)moveFileTreeNode:(NSTreeNode *)targetNode toURL:(NSURL *)dstURL
                                                withReplacing:(BOOL)replaceFlag
{
	if (targetNode) {
		FileDatum *file_datum = [[targetNode representedObject] representedObject];
        NSURL *target_url = [file_datum fileURL];
        if ([dstURL isEqualTo:target_url]) {
			[_processedNodes addObject:targetNode];
            
		} else {
			NSFileManager *fm = [NSFileManager defaultManager];
			NSString *target_name = [target_url lastPathComponent];
			//NSString *new_path = [dstURL stringByAppendingPathComponent:
			//										  target_name];
            NSError *err = nil;
            if (![fm moveItemAtURL:target_url toURL:dstURL error:&err]) {
				if (![fm fileExistsAtPath:[dstURL path]]) {
                    [NSApp presentError:err];
					NSLog(@"destination path : %@ does not exist. Bail faild to move.", [dstURL path]);
					goto skip;
				}
				
				if (replaceFlag) {
					NSPredicate *name_predicate = [NSPredicate predicateWithFormat:
													 @"representedObject.name like %@", target_name];
					NSArray *conflict_nodes = [[_destinationNode childNodes]
											   filteredArrayUsingPredicate:name_predicate];
                    if ([fm removeItemAtURL:dstURL error:&err]) {
                        if (![fm moveItemAtURL:target_url toURL:dstURL error:&err]) {
                            if (err) [NSApp presentError:err];
                            goto skip;
                        }
					} else {
						NSLog(@"Failed to remove :%@.", dstURL);
						goto skip;
					}
					[nodesToDelete addObjectsFromArray:conflict_nodes];
				} else {
					BOOL is_single = (restItemsCount <= 1);
					[applyAllSwitch setHidden:is_single];
					[cancelForItemButton setHidden:is_single];
					[_afterSheetInvocation setArgument:&targetNode atIndex:2];
                    [_afterSheetInvocation setArgument:&dstURL atIndex:3];
                    [_afterSheetInvocation setArgument:&replaceFlag atIndex:4];
					[self setupConflictMessage:[file_datum name] forOperationName:@"moving"];
					[iconInConflictErrorWindow setImage:
						[[NSWorkspace sharedWorkspace] iconForFile:[target_url path]]];
					[NSApp beginSheet: conflictErrorWindow
					   modalForWindow: [outlineView window]
						modalDelegate: self
					   didEndSelector: @selector(didEndAskReplaceSheet:returnCode:contextInfo:)
						  contextInfo: nil];
					return;
				}
			}
            [[[targetNode representedObject] representedObject] updateBookmarkData];
			[_processedNodes addObject:targetNode];
		}
skip:
		restItemsCount--;
		if (!applyAllFlag) replaceFlag = NO;
        NSTreeNode *src_node = [_dndEnumerator nextObject];
        if (src_node) {
            NSURL *src_url = [[[src_node representedObject] representedObject] fileURL];
            NSURL *dst_url = [[[_destinationNode representedObject] fileURL]
                          URLByAppendingPathComponent:[src_url lastPathComponent]];
            [self moveFileTreeNode:src_node toURL:dst_url withReplacing:replaceFlag];
            return;
        }
    }
    
    NSMutableSet *updated_file_data = [NSMutableSet setWithCapacity:[_processedNodes count]];
    for (NSTreeNode *controller_node in _processedNodes) {
        [updated_file_data addObject:[[controller_node representedObject] representedObject]];
    }
    [treeController moveNodes:_processedNodes toIndexPath:_destinationIndexPath];
    [treeController removeObjectsAtArrangedObjectIndexPaths:
                                     [nodesToDelete valueForKeyPath:@"indexPath"]];
    [updated_file_data makeObjectsPerformSelector:@selector(saveOrder)];
    [[_destinationNode representedObject] saveOrder];
}

- (void)insertChildrenCopyingPaths:(NSArray *)sourcePaths //deprecated
{
    /* call setDestinationWithNode:atIndexPath before */
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *child_nodes = [_destinationNode mutableChildNodes];
	NSUInteger index_len = [_destinationIndexPath length];
	NSUInteger indexes[index_len];
	[_destinationIndexPath getIndexes:indexes];
    NSString *dest_path = [[_destinationNode representedObject] path];
	for (NSString *a_source in sourcePaths) {
		NSString *target_path = [dest_path stringByAppendingPathComponent:
										   [a_source lastPathComponent]];
		target_path = [target_path uniqueName];
        NSError *err = nil;
        [fm copyItemAtPath:a_source toPath:target_path error:&err];
        if (err) {
            [NSApp presentError:err];
        }
		
		NewFileTreeNode *newnode = [[FileDatum fileDatumWithPath:target_path] treeNode];
		[child_nodes insertObject:newnode atIndex:indexes[index_len-1]++];
	}
}

- (void)cleanupFolderContents:(NSString *)path
{
    if (![path isFolder]) return;
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
			[self cleanupFolderContents:file_path];
		}
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
#if useLog
    NSLog(@"start acceptDrop: %@", info);
#endif
	index = (index==NSOutlineViewDropOnItemIndex ? 0:index);
	NSTreeNode *root_node = [treeController arrangedObjects]; //instance variable rootNode does not work.
	if (proposed_node) {
		[self setDestinationWithNode:[proposed_node representedObject] 
						 atIndexPath:[[proposed_node indexPath] indexPathByAddingIndex:index]];
	} else {
		[self setDestinationWithNode:_rootNode
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
			[[_destinationNode representedObject] saveOrder];
		} else {
			self.dndEnumerator = [uniq_dragged_nodes objectEnumerator];

			applyAllFlag = NO;
			self.processedNodes = [NSMutableArray arrayWithCapacity:restItemsCount];
			self.nodesToDelete = [NSMutableArray array];
			[self setupAfterSheetInvocation:
             @selector(moveFileTreeNode:toURL:withReplacing:)];
            NSTreeNode *src_node = [_dndEnumerator nextObject];
			NSURL *src_url = [[[src_node representedObject] representedObject] fileURL];
            NSURL *dst_url = [[[_destinationNode representedObject] fileURL]
                                URLByAppendingPathComponent:[src_url lastPathComponent]];
            [self moveFileTreeNode:src_node toURL:dst_url withReplacing:NO];
		}
	} 
	else if ([pboard availableTypeFromArray:
			  [NSArray arrayWithObjects:NSFilenamesPboardType, nil]] != nil) {
		NSArray *path_array = [pboard propertyListForType:NSFilenamesPboardType];
		[self insertChildrenCopyingPaths:path_array];
	}	
	
    return YES;
}

- (NSArray *)outlineView:(NSOutlineView *)olv
namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
         forDraggedItems:(NSArray *)items {
#if useLog
	NSLog(@"start namesOfPromisedFilesDroppedAtDestination");
#endif
    self.promisedDragDestination = dropDestination;
    self.draggedNodes = items;
    restItemsCount = [items count];
    NSArray *filenames = [items valueForKeyPath:@"representedObject.representedObject.name"];

    return filenames;
}

- (void)copyPromisedFile:(NSURL *)srcURL toURL:(NSURL *)dstURL replacing:(BOOL)replaceFlag
{
#if useLog
	NSLog(@"start copyPromisedFile");
#endif
    if (!srcURL) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    if (![fm copyItemAtURL:srcURL toURL:dstURL error:&err]) {
        if (replaceFlag) {
            [fm removeItemAtURL:dstURL error:&err];
            [self copyPromisedFile:srcURL toURL:dstURL replacing:replaceFlag];

        } else if (!applyAllFlag) {
            BOOL is_single = (restItemsCount <= 1);
            [applyAllSwitch setHidden:is_single];
            [cancelForItemButton setHidden:is_single];
            [self setupConflictMessage:[srcURL lastPathComponent]
                      forOperationName:@"copying"];
            [_afterSheetInvocation setArgument:&srcURL atIndex:2];
            [_afterSheetInvocation setArgument:&dstURL atIndex:3];
            
            [iconInConflictErrorWindow setImage:
                [[NSWorkspace sharedWorkspace] iconForFile:[srcURL path]]];
            [NSApp beginSheet: conflictErrorWindow
               modalForWindow: [outlineView window]
                modalDelegate: self
               didEndSelector: @selector(didEndAskReplaceSheet:returnCode:contextInfo:)
                  contextInfo: nil];
            return;
        }
        
    } else {
        /*[[NSNotificationCenter defaultCenter]
         postNotificationName:@"NewFileNotification"
         object:self
         userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                   destinationPath, @"destination", sourceNode, @"sourceNode", nil]];
        */
        [self cleanupFolderContents:[dstURL path]];
        if (!applyAllFlag) replaceFlag = NO;
        restItemsCount--;

        NSURL *src = [_dndEnumerator nextObject];
        if (!src) return;
        NSURL *dst = [_promisedDragDestination
                      URLByAppendingPathComponent:[src lastPathComponent]];
        [self copyPromisedFile:src toURL:dst replacing:replaceFlag];
    }
}

- (void)copyPromisedFiles
{
	if (_draggedNodes == nil) return;
    self.dndEnumerator = [[_draggedNodes valueForKeyPath:@"representedObject.representedObject.fileURL"]
                                   objectEnumerator];
	applyAllFlag = NO;
    NSURL *src = [_dndEnumerator nextObject];
    NSURL *dst = [_promisedDragDestination
                  URLByAppendingPathComponent:[src lastPathComponent]];
	NSInvocation *invocation = [self setupAfterSheetInvocation:
                                @selector(copyPromisedFile:toURL:replacing:)];
	BOOL replace_flag = NO;
	[invocation setArgument:&replace_flag atIndex:4];

    [self copyPromisedFile:src toURL:dst replacing:NO];
}

- (void)trashPromisedFiles
{
	if (_draggedNodes == nil) return;
	NSArray *min_index_pathes = [NSIndexPath minimumIndexPathesCoverFromIndexPathesArray:
								 [_draggedNodes valueForKeyPath:@"indexPath"]];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSMutableSet *updated_nodes = [NSMutableSet set];
	
	for (NSIndexPath *an_indexpath in min_index_pathes) {
		NSTreeNode *controller_node = [[treeController arrangedObjects]
                                       descendantNodeAtIndexPath:an_indexpath];
		NSTreeNode *file_tree_node = [controller_node representedObject];
		NSString *a_path = [[file_tree_node representedObject] path];
		NSString *dir_path = [a_path stringByDeletingLastPathComponent];
		NSString *a_name = [a_path lastPathComponent];
		[workspace performFileOperation:NSWorkspaceRecycleOperation
								 source:dir_path destination:nil
								  files:[NSArray arrayWithObject:a_name] tag:nil];
		NSTreeNode *parent_node = [controller_node parentNode];
        [[parent_node mutableChildNodes] removeObject:controller_node];
        [updated_nodes addObject:[file_tree_node parentNode]];
	}

	for (NewFileTreeNode *a_node in updated_nodes) {
		[(FileDatum *)[a_node representedObject] saveOrder];
	}
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forItems:(NSArray *)draggedItems {
    self.draggedNodes = draggedItems;
}

- (void)outlineView:(NSOutlineView *)olv draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    NSLog(@"start draggingSession operation %ld", operation);
     // If the session ended in the trash, then delete all the items
    switch (operation) {
		case NSDragOperationCopy:
		case NSDragOperationGeneric:
			[self copyPromisedFiles];
			break;
		case NSDragOperationDelete:
			[self trashPromisedFiles];
			break;
	}
    /*
    if (operation == NSDragOperationDelete) {
        [_outlineView beginUpdates];
        
        [_draggedNodes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id node, NSUInteger index, BOOL *stop) {
            id parent = [node parentNode];
            NSMutableArray *children = [parent mutableChildNodes];
            NSInteger childIndex = [children indexOfObject:node];
            [children removeObjectAtIndex:childIndex];
            [_outlineView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:childIndex] inParent:parent == _rootTreeNode ? nil : parent withAnimation:NSTableViewAnimationEffectFade];
        }];
        
        [_outlineView endUpdates];
    }
    
    [_draggedNodes release];
    _draggedNodes = nil;
     */
}

#pragma mark actions 
- (BOOL)respondsToSelector:(SEL)aSelector
{
	NSInteger clicked_row = [outlineView clickedRow];
	BOOL has_clicked_row = (clicked_row != -1);
	BOOL has_selection = ([[treeController selectedNodes] count] > 0);
#if useLog
    //NSLog(@"respondToSelector in FileTreeDataController, hasClickedRow %d, hasSelection %d", has_clicked_row, has_selection);
#endif
	if (aSelector == @selector(dupulicateSelection:)) 
		return (has_clicked_row || has_selection);
	
	if (aSelector == @selector(renameSelection:))
		return (has_clicked_row || has_selection);
	
	if (aSelector == @selector(deleteSelection:)) {
#if useLog		
		//NSLog(@"Respond to deleteSelection : %d", (has_clicked_row || has_selection));
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
#if useLog
    NSLog(@"start renameSelection in FileTreeDataController");
#endif
	NSString *column_id = @"displayName";
	NSUInteger target_row = [outlineView clickedRow];
    if (-1 == target_row) {
        target_row = [outlineView selectedRow];
    }
	NSTableColumn *column = [outlineView tableColumnWithIdentifier:column_id];
	[column setEditable:YES];
	[outlineView editColumn:[outlineView columnWithIdentifier:column_id] 
								row:target_row withEvent:nil select:YES];
}

- (IBAction)makeFolder:(id)sender
{
#if useLog
	NSLog(@"%@", @"start makeFolder in FileTreeDataController");
#endif
	[self updateDestinationNode];
    NSString *untitled_folder_name = NSLocalizedString(@"Untitled", @"The name of untitled new folder");
    FileDatum *dest_fd = [_destinationNode representedObject];
	NSString *new_path = [[dest_fd path]
                          stringByAppendingPathComponent:untitled_folder_name];
	new_path = [new_path uniqueName];
	NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    [fm createDirectoryAtPath:new_path
    withIntermediateDirectories:NO attributes:nil
                        error:&err];
    if (err) {
        [NSApp presentError:err];
        return;
    }	
	FileDatum *folder_dataum = [FileDatum fileDatumWithPath:new_path];
	[[_destinationNode mutableChildNodes] 
				insertObject:[folder_dataum treeNode]
                atIndex:[_destinationIndexPath lastIndex]];
	[treeController setSelectionIndexPath:_destinationIndexPath];
	[dest_fd saveOrder];
}

- (IBAction)dupulicateSelection:(id)sender
{
	NSMutableArray *src_nodes = [[treeController selectedNodes] mutableCopy];
	NSInteger clicked_row = [outlineView clickedRow];
	if (clicked_row != -1) {
		NSTreeNode *clicked_node = [outlineView itemAtRow:clicked_row];
		if (![src_nodes containsObject:clicked_node]) {
            [src_nodes addObject:clicked_node];
        }
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
        NSError *err = nil;
        if ([fm copyItemAtPath:src_path
                        toPath:target_path error:&err]) {
            NSTreeNode *a_new_node = [[FileDatum fileDatumWithPath:target_path] treeNode];
            [[parent_node mutableChildNodes] insertObject:a_new_node atIndex:[new_indexpath lastIndex]];
            [new_nodes addObject:[[treeController arrangedObjects] descendantNodeAtIndexPath:new_indexpath]];
        } else if (err) {
            [NSApp presentError:err];
        }
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
	[NSRunningApplication activateAppOfIdentifier:@"com.apple.finder"];
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

#pragma mark methods for outside objects

- (NSTreeNode *)clickedNode // 使われているか？
{
    NSUInteger clicked_row = [outlineView clickedRow];
	NSTreeNode *clicked_node = nil;
	if (clicked_row == -1) {
		clicked_node = [[[treeController selectedNodes] lastObject] representedObject];
	} else {
		clicked_node = [[outlineView itemAtRow:clicked_row] representedObject];
	}
	
	if (!clicked_node) {
		clicked_node = _rootNode;
	}
    return clicked_node;
}

- (void)setRootDirPath:(NSString *)rootDirPath
{
#if useLog
    NSLog(@"start setRootDirPath : %@", rootDirPath);
#endif
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
	NSIndexPath *index_path = [treeController selectionIndexPath];
	NSString *destination_path = nil;
	FileDatum *destination_fd = nil;
	if (index_path) {
		if ([index_path length]) {
			NSTreeNode *a_node = [_rootNode descendantNodeAtIndexPath:index_path];
			destination_fd = [[a_node parentNode] representedObject];
			destination_path = [destination_fd path];
			index_path = [index_path indexPathByIncrementLastIndex:1];
		} else {
			destination_fd = rootDirectory;
			destination_path = [rootDirectory path];
			index_path = [NSIndexPath indexPathWithIndex:[[_rootNode childNodes] count]];
		}
	} else {
		destination_fd = rootDirectory;
		destination_path = [rootDirectory path];
		index_path = [NSIndexPath indexPathWithIndex:[[_rootNode childNodes] count]];
	}
	
	NSString *target_path = [destination_path stringByAppendingPathComponent:newname];
	target_path = [target_path uniqueName];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    [fm copyItemAtPath:sourcePath toPath:target_path error:&err];
    if (err) {
        [NSApp presentError:err];
        return;
    }
	NewFileTreeNode *newnode = [[FileDatum fileDatumWithPath:target_path] treeNode];
	[[[destination_fd treeNode] mutableChildNodes]
     insertObject:newnode atIndex:[index_path lastIndex]];
	[destination_fd saveOrder];
}

- (void)insertCopyingPathes:(NSArray *)sourcePaths
{
    [self updateDestinationNode];
    [self insertChildrenCopyingPaths:sourcePaths];
}

- (IBAction)updateRoot:(id)sender
{
	[rootDirectory updateChildren];
}

- (IBAction)openRootDirectory:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[rootDirectory path]];
	[NSRunningApplication activateAppOfIdentifier:@"com.apple.finder"];
}


@end
