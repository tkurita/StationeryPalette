#import "FileTreeDataController.h"
#import "ImageAndTextCell.h"
#import "NSIndexPath_Extensions.h"
#import "PathExtra.h"
#import "NSRunningApplication+SmartActivate.h"

#include <Carbon/Carbon.h>

#define useLog 0

@implementation FileTreeDataController


static NSString *MovedNodesType = @"MOVED_Nodes_TYPE";


static BOOL isOptionKeyDown()
{
	UInt32 mod_key_status = GetCurrentKeyModifiers();
	return ((mod_key_status & optionKey) != 0);
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
	ImageAndTextCell *image_text_cell = [ImageAndTextCell new];
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
     @[MovedNodesType, NSFilenamesPboardType]];
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
- (void)setDestinationWithNode:(FileTreeNode *)aNode atIndexPath:anIndexPath
{
	self.destinationNode = aNode;
	self.destinationIndexPath = anIndexPath;
}

- (void)updateDestinationNode
{
    NSIndexPath *index_path = [treeController selectionIndexPath];
    FileTreeNode *a_node = _rootNode;
	if (index_path) {
		if ([index_path length]) {
			a_node = (FileTreeNode *)[_rootNode descendantNodeAtIndexPath:index_path];
            if ([[a_node representedObject] isContainer] && [a_node isExpanded] ) {
                index_path = [index_path indexPathByAddingIndex:0];
            } else {
                a_node = (FileTreeNode *)[a_node parentNode];
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
	NSTreeNode *controller_node = [notification userInfo][@"NSObject"];
	FileTreeNode *file_tree_node = [controller_node representedObject];
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
	NSTreeNode *controller_node = [notification userInfo][@"NSObject"];
	FileTreeNode *file_tree_node = [controller_node representedObject];
	file_tree_node.isExpanded = NO;
	[(FileDatum *)[[file_tree_node parentNode] representedObject] saveOrder];
}

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell 
	 forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	FileTreeNode *file_tree_node = [item representedObject];
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
	NSString *localized_operation = NSLocalizedStringFromTable(operationName,
                                                               @"FileTreeView_Localizable",
                                                               @"");
	[conflictMessage setStringValue:
	 [NSString stringWithFormat:_conflictMessageTemplate, fileName, localized_operation]];
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

- (NSInvocation *)setupAfterCopyInvocation:(SEL)aSelector
{
    self.afterCopyInvocation = [NSInvocation invocationWithMethodSignature:
                                [self methodSignatureForSelector:aSelector]];
	[_afterCopyInvocation setSelector:aSelector];
	[_afterCopyInvocation retainArguments];
	[_afterCopyInvocation setTarget:self];
	
	return _afterCopyInvocation;
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
					[_nodesToDelete addObjectsFromArray:conflict_nodes];
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
                                     [_nodesToDelete valueForKeyPath:@"indexPath"]];
    [updated_file_data makeObjectsPerformSelector:@selector(saveOrder)];
    [[_destinationNode representedObject] saveOrder];
}

- (void)insertNewNodeWithURL:(NSURL *)anURL
{
    FileTreeNode *newnode = [[FileDatum fileDatumWithURL:anURL] treeNode];
    [[_destinationNode mutableChildNodes] insertObject:newnode atIndex:_destinationIndexPath.lastIndex];
    self.destinationIndexPath = [_destinationIndexPath indexPathByIncrementLastIndex:1];
}

- (void)insertChildrenCopyingPaths:(NSArray *)srcPaths
{
  /* call setDestinationWithNode:atIndexPath before */
    self.nodesToDelete = [NSMutableArray array];
    NSMutableArray *src_urls = [NSMutableArray arrayWithCapacity:[srcPaths count]];
    [srcPaths enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
        [src_urls addObject:[NSURL fileURLWithPath:obj]];
    }];
    applyAllFlag = NO;
    self.dndEnumerator = [src_urls objectEnumerator];
    NSURL *src = [_dndEnumerator nextObject];
    NSURL *dst = [[[_destinationNode representedObject] fileURL]
                    URLByAppendingPathComponent:[src lastPathComponent]];
    NSInvocation *invocation = [self setupAfterSheetInvocation:
                                @selector(copyFileAtURL:toURL:replacing:)];
    [self setupAfterCopyInvocation:@selector(insertNewNodeWithURL:)];
    BOOL replace_flag = NO;
	[invocation setArgument:&replace_flag atIndex:4];
    
    [self copyFileAtURL:src toURL:dst replacing:NO];
}

//- (void)insertChildrenCopyingPaths:(NSArray *)sourcePaths
//{
//    /* call setDestinationWithNode:atIndexPath before */
//	NSFileManager *fm = [NSFileManager defaultManager];
//	NSMutableArray *child_nodes = [_destinationNode mutableChildNodes];
//	NSUInteger index_len = [_destinationIndexPath length];
//	NSUInteger indexes[index_len];
//	[_destinationIndexPath getIndexes:indexes];
//    NSString *dest_path = [[_destinationNode representedObject] path];
//	for (NSString *a_source in sourcePaths) {
//		NSString *target_path = [dest_path stringByAppendingPathComponent:
//										   [a_source lastPathComponent]];
//		target_path = [target_path uniqueName];
//        NSError *err = nil;
//        [fm copyItemAtPath:a_source toPath:target_path error:&err];
//        if (err) {
//            [NSApp presentError:err];
//        }
//		
//		FileTreeNode *newnode = [[FileDatum fileDatumWithPath:target_path] treeNode];
//		[child_nodes insertObject:newnode atIndex:indexes[index_len-1]++];
//	}
//}


- (void)cleanupContentsAtURL:(NSURL *)anURL
{
    NSError *err = nil;
    if (![anURL isFolder]) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtURL:[anURL URLByAppendingPathComponent:ORDER_CHACHE_NAME] error:&err];
    NSDirectoryEnumerator *dir_enum = [fm enumeratorAtURL:anURL
                               includingPropertiesForKeys:@[NSURLIsDirectoryKey]
        options:NSDirectoryEnumerationSkipsPackageDescendants|NSDirectoryEnumerationSkipsHiddenFiles
                        errorHandler:^BOOL(NSURL *url, NSError *error) {
                    NSLog(@"error:%@ cleanupCOntentsAtURL:%@", error, url);
                            return YES;}];
    
    for (NSURL *url in dir_enum) {
        if ([url isFolder]) {
            [self cleanupContentsAtURL:url];
        }
    }
}

- (void)cleanupFolderContents:(NSString *)path //deprecated
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
    [pboard declareTypes:@[MovedNodesType, NSFilesPromisePboardType] 
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
				  proposedItem:(id)proposed_node
            proposedChildIndex:(NSInteger)index
{
#if useLog
    NSLog(@"start validateDrop");
#endif	
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
				return NSDragOperationNone;
			}
			NSIndexPath *proposed_index_path = [proposed_node indexPath];
			if ([proposed_index_path isDescendantOfIndexPathInArray:dropped_index_pathes]) {
				return NSDragOperationNone;
			}			
		} else {
			// drop from finder
            return NSDragOperationCopy;
		}
	} else {
		return NSDragOperationNone;
	}

	if (isOptionKeyDown()) {
		return NSDragOperationCopy;
	}
	else {
		return NSDragOperationMove;
	}
}

/*
 Performing a drop in the outline view. This allows the user to manipulate the structure of the tree by moving subtrees under new parent nodes.
 */
- (BOOL)outlineView:(NSOutlineView *)olv
         acceptDrop:(id <NSDraggingInfo>)info
			   item:(id)proposed_node childIndex:(NSInteger)index
{
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
    if ([pboard availableTypeFromArray: @[MovedNodesType]]) {
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
			  @[NSFilenamesPboardType]] != nil) {
		NSArray *path_array = [pboard propertyListForType:NSFilenamesPboardType];
        [self insertChildrenCopyingPaths:path_array];
	}	
	
    return YES;
}

- (NSArray *)outlineView:(NSOutlineView *)olv
                namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
                                        forDraggedItems:(NSArray *)items
{
#if useLog
	NSLog(@"start namesOfPromisedFilesDroppedAtDestination");
#endif
    self.promisedDragDestination = dropDestination;
    self.draggedNodes = items;
    restItemsCount = [items count];
    NSArray *filenames = [items valueForKeyPath:@"representedObject.representedObject.name"];

    return filenames;
}

- (void)copyFileAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL replacing:(BOOL)replaceFlag
{
#if useLog
	NSLog(@"start copyPromisedFile");
#endif
    if (!srcURL) {
        [treeController removeObjectsAtArrangedObjectIndexPaths:
         [_nodesToDelete valueForKeyPath:@"indexPath"]];
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    if (![fm copyItemAtURL:srcURL toURL:dstURL error:&err]) {
        if (replaceFlag) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:
                                      @"representedObject.name like %@", [srcURL lastPathComponent]];
            NSArray *array = [[_destinationNode childNodes] filteredArrayUsingPredicate:predicate];
            [_nodesToDelete addObjectsFromArray:array];
            [fm removeItemAtURL:dstURL error:&err];
            [self copyFileAtURL:srcURL toURL:dstURL replacing:replaceFlag];

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
        [_afterCopyInvocation setArgument:&dstURL atIndex:2];
        [_afterCopyInvocation invoke];
        if (!applyAllFlag) replaceFlag = NO;
        restItemsCount--;

        NSURL *src = [_dndEnumerator nextObject];
        if (!src) {
            [treeController removeObjectsAtArrangedObjectIndexPaths:
             [_nodesToDelete valueForKeyPath:@"indexPath"]];
            [_destinationNode.representedObject saveOrder];
            return;
        }
        NSURL *dst = [_promisedDragDestination
                      URLByAppendingPathComponent:[src lastPathComponent]];
        [self copyFileAtURL:src toURL:dst replacing:replaceFlag];
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
                                @selector(copyFileAtURL:toURL:replacing:)];
	[self setupAfterCopyInvocation:@selector(cleanupContentsAtURL:)];
    BOOL replace_flag = NO;
	[invocation setArgument:&replace_flag atIndex:4];

    [self copyFileAtURL:src toURL:dst replacing:NO];
}

- (void)trashPromisedFiles
{
	if (_draggedNodes == nil) return;
    [self deleteNodes:_draggedNodes];
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session
                    willBeginAtPoint:(NSPoint)screenPoint forItems:(NSArray *)draggedItems
{
    self.draggedNodes = draggedItems;
    self.promisedDragDestination = nil;
}

- (void)outlineView:(NSOutlineView *)olv draggingSession:(NSDraggingSession *)session
                    endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
#if useLog
    NSLog(@"start draggingSession operation %ld", operation);
#endif
    switch (operation) {
		case NSDragOperationCopy:
		case NSDragOperationGeneric:
			if(_promisedDragDestination) {
                [self copyPromisedFiles];
            }
			break;
		case NSDragOperationDelete:
			[self trashPromisedFiles];
			break;
	}
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

- (NSArray *)targetNodes
{
    NSInteger clicked_row = [outlineView clickedRow];
    if (clicked_row != -1) { // contextual menu
        if ([outlineView isRowSelected:clicked_row]) {
            return [treeController selectedNodes];
        } else {
            NSTreeNode *clicked_node = [outlineView itemAtRow:clicked_row];
            return [NSArray arrayWithObject:clicked_node];
        }
    }
    return [treeController selectedNodes];;
}

- (void)deleteNodes:(NSArray *)nodes
{
    NSArray *min_index_pathes = [NSIndexPath minimumIndexPathesCoverFromIndexPathesArray:
								 [nodes valueForKeyPath:@"indexPath"]];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSMutableSet *updated_nodes = [NSMutableSet set];
	NSEnumerator *reverse_enum = [min_index_pathes reverseObjectEnumerator];
    
    for (NSIndexPath *an_indexpath in reverse_enum) {
		NSTreeNode *controller_node = [[treeController arrangedObjects]
                                       descendantNodeAtIndexPath:an_indexpath];
		FileTreeNode *file_tree_node = controller_node.representedObject;
		NSString *a_path = [[file_tree_node representedObject] path];
		NSString *dir_path = [a_path stringByDeletingLastPathComponent];
		NSString *a_name = [a_path lastPathComponent];
		[workspace performFileOperation:NSWorkspaceRecycleOperation
								 source:dir_path destination:nil
								  files:@[a_name] tag:nil];

        FileTreeNode *parent_node = (FileTreeNode *)file_tree_node.parentNode;
        FileDatum *fdatum = parent_node.representedObject;
        [updated_nodes addObject:fdatum];
        // make a unique set of parent nodes,
        // to avoid dupulicate sending saveOrder message.
        
        [treeController removeObjectAtArrangedObjectIndexPath:an_indexpath];
	}
    
    for (FileDatum *fdatum in updated_nodes) {
        [fdatum saveOrder];
    }
}

- (IBAction)deleteSelection:(id)sender
{
    NSArray *nodes = [self targetNodes];
    [self deleteNodes:nodes];
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
    NSString *untitled_folder_name = NSLocalizedStringFromTable(@"Untitled",
                                                                @"FileTreeView_Localizable",
                                                                @"The name of untitled new folder");
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
	NSArray *src_nodes = [self targetNodes];
	
    NSFileManager *fm = [NSFileManager defaultManager];
	NSUInteger n_src = [src_nodes count];
	NSMutableArray *new_nodes = [NSMutableArray arrayWithCapacity:n_src];
	
	for (NSTreeNode *a_node in src_nodes) {
		NSIndexPath *new_indexpath = [[a_node indexPath] indexPathByIncrementLastIndex:1];
		NSTreeNode *a_src_node = [a_node representedObject];
		NSString *src_path = [[a_src_node representedObject] path];
		FileTreeNode *parent_node = (FileTreeNode *)[a_src_node parentNode];
		NSString *target_path = [[[parent_node representedObject] path] stringByAppendingPathComponent: 
												[src_path lastPathComponent]];
		target_path = [target_path uniqueName];
        NSError *err = nil;
        if ([fm copyItemAtPath:src_path
                        toPath:target_path error:&err]) {
            FileTreeNode *a_new_node = [[FileDatum fileDatumWithPath:target_path] treeNode];
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
    NSArray *src_nodes = [self targetNodes];

	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	for (NSTreeNode *a_node in src_nodes) {
		NSString *a_path = [[[a_node representedObject] representedObject] path];
		[workspace selectFile:a_path inFileViewerRootedAtPath:@""];
	}
	[NSRunningApplication activateAppOfIdentifier:@"com.apple.finder"];
}


- (IBAction)openSelection:(id)sender
{
    NSArray *src_nodes = [self targetNodes];
	
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
- (void)setRootDirPath:(NSString *)rootDirPath
{
#if useLog
    NSLog(@"start setRootDirPath : %@", rootDirPath);
#endif
    self.rootDirectory = [FileDatum fileDatumWithPath:rootDirPath];
	self.rootNode = [_rootDirectory treeNode];
	[_rootDirectory loadChildren];
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
			destination_fd = _rootDirectory;
			destination_path = [_rootDirectory path];
			index_path = [NSIndexPath indexPathWithIndex:[[_rootNode childNodes] count]];
		}
	} else {
		destination_fd = _rootDirectory;
		destination_path = [_rootDirectory path];
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
	FileTreeNode *newnode = [[FileDatum fileDatumWithPath:target_path] treeNode];
	[[[destination_fd treeNode] mutableChildNodes]
     insertObject:newnode atIndex:[index_path lastIndex]];
	[destination_fd saveOrder];
}

- (void)insertCopyingPathes:(NSArray *)sourcePaths
{
    [self updateDestinationNode];
    [self insertChildrenCopyingPaths:sourcePaths];
}

- (void)insertCopyingURLs:(NSArray *)srcURLs
{
    [self updateDestinationNode];
    [self insertChildrenCopyingPaths:[srcURLs valueForKeyPath:@"path"]];
}

- (IBAction)updateRoot:(id)sender
{
	[_rootDirectory updateChildren];
}

- (IBAction)openRootDirectory:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[_rootDirectory path]];
	[NSRunningApplication activateAppOfIdentifier:@"com.apple.finder"];
}


@end
