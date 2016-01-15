#import "FileTreeNode.h"
#import "PathExtra.h"

//NSString *ORDER_CHACHE_NAME = @"order.plist";

@implementation FileTreeNodeData

- (id)initWithPath:(NSString *)path
{
    self = [super init];
    if (self==nil) return nil;
   
	[self setPath:path];
    [self loadFileInfo];
    return self;
}

+ (id)fileTreeNodeDataWithPath:(NSString *)path
{
	return [[[[self class] alloc] initWithPath:path] autorelease];
}

- (BOOL)updateDisplayName
{
	NSFileManager *file_manager = [NSFileManager defaultManager];
	NSString *current_name = [file_manager displayNameAtPath:[self path]];
	if (![displayName isEqualToString:current_name]) {
		[self setDisplayName:current_name];
		return YES;
	}
	
	return NO;
}

- (void)dealloc
{
	[_path release];
	[_attributes release];
	[displayName release];
	[_iconImage release];
	[kind release];
	[super dealloc];
}

- (BOOL)updateAttributes
{
	BOOL is_updated = NO;
	NSFileManager *file_manager = [NSFileManager defaultManager];
	NSString *a_path = [self path];
	NSString *current_name = [file_manager displayNameAtPath:a_path];
	if (![displayName isEqualToString:current_name]) {
		[self setDisplayName:current_name];
		is_updated = YES;
	}
	
	NSString *current_kind;
	OSStatus err = LSCopyKindStringForURL((CFURLRef)[NSURL fileURLWithPath:a_path], (CFStringRef *)&current_kind);
	NSAssert1(err == noErr, @"Fail to get kind of : %@", current_kind);
	[current_kind autorelease];
	if (![kind isEqualToString:current_kind]) {
		[self setKind:current_kind];
		is_updated = YES;
	}
	
	if (is_updated) {
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		NSImage *icon = [workspace iconForFile:a_path];
		[icon setSize:NSMakeSize(16, 16)];
		[self setIconImage:icon];
		[self setAttributes:[file_manager fileAttributesAtPath:a_path traverseLink:YES]];
		_isContainer = ([_attributes objectForKey:NSFileType] == NSFileTypeDirectory) && 
			(![workspace isFilePackageAtPath:a_path]);
	}
	
	return is_updated;
}

- (void)loadFileInfo
{		
	NSFileManager *file_manager = [NSFileManager defaultManager];
	NSString *aPath = [self path];
	[self setAttributes:[file_manager fileAttributesAtPath:aPath traverseLink:YES]];
	[self setDisplayName:[file_manager displayNameAtPath:aPath]];
	
	/* icon image*/
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSImage *icon = [workspace iconForFile:aPath];
	[icon setSize:NSMakeSize(16, 16)];
	[self setIconImage:icon];
	//_isChildrenLoaded = NO;
	
	_isContainer = ([_attributes objectForKey:NSFileType] == NSFileTypeDirectory) && 
		(![workspace isFilePackageAtPath:aPath]);
	
	NSString *kindString;
	OSStatus err = LSCopyKindStringForURL((CFURLRef)[NSURL fileURLWithPath:aPath], (CFStringRef *)&kindString);
	if (err == noErr) {
		[self setKind:kindString];
	}
	else {
		NSLog(@"can't get kind");
	}
}

#pragma mark accessors

- (BOOL)isContainer
{
	return _isContainer;
}

- (BOOL)setPath:(NSString *)path
{
    NSError *error = nil;
    self.bookmarkData = [[NSURL fileURLWithPath:path] bookmarkDataWithOptions:0
                                               includingResourceValuesForKeys:nil
                                                                relativeToURL:nil
                                                                        error:&error];
    if (error) {
        [NSApp presentError:error];
        return NO;
    }
	return YES;
}

- (NSString *)path
{
    
	BOOL is_stale;
    NSError *error = nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:_bookmarkData
                                           options:0 relativeToURL:NULL
                               bookmarkDataIsStale:&is_stale error:&error];
    if (error) {
        [NSApp presentError:error];
        return nil;
    }
    return [url path];
}

- (void)setDisplayName:(NSString*)aName
{
	[aName retain];
	[displayName release];
	displayName = aName;
}

- (NSString *)fileType
{
	return [_attributes objectForKey:NSFileType];
}

- (NSString *)typeCode
{
	return NSFileTypeForHFSTypeCode([[_attributes objectForKey:NSFileHFSTypeCode]
											unsignedLongValue]);
}

- (NSString *)typeForPboard
{
	NSString *a_type = [self typeCode];
	if (! a_type) {
		a_type = [[self path] pathExtension];
	}
	return a_type;
}

- (NSDictionary *)attributes
{
	return _attributes;
}

- (void)setAttributes:(NSDictionary *)attributes
{
	[attributes retain];
	[_attributes release];
	_attributes = attributes;
}

- (void)setIconImage:(NSImage *)iconImage
{
	[iconImage retain];
	[_iconImage release];
	_iconImage = iconImage;
}

- (NSImage *)iconImage
{
	return _iconImage;
}

- (NSString *)name
{
	return [[self path] lastPathComponent];
}

- (NSString *)displayName
{
	return displayName;
}

- (void)setKind:(NSString *)aKind
{
	[aKind retain];
	[kind release];
	kind = aKind;
}

- (NSString *)kind
{
	return kind;
}


- (NSString *)originalPath
{
	NSString *source_path = [self path];
	NSString *resolved_path = nil;
	NSString *file_type = [_attributes objectForKey:NSFileType];

	if ([file_type isEqualToString:NSFileTypeSymbolicLink]) {
		NSFileManager *file_manager = [NSFileManager defaultManager];
		resolved_path = [file_manager pathContentOfSymbolicLinkAtPath:source_path];
		return resolved_path;
	}
	
	if ([file_type isEqualToString:NSFileTypeRegular]) {
		CFURLRef url;
 
		url = CFURLCreateWithFileSystemPath(NULL /*allocator*/, (CFStringRef)source_path,
                         kCFURLPOSIXPathStyle, NO /*isDirectory*/);
		if (url != NULL) {
			FSRef fsRef;
			if (CFURLGetFSRef(url, &fsRef)) {
				Boolean targetIsFolder, wasAliased;
				if (FSResolveAliasFile (&fsRef, true /*resolveAliasChains*/, 
						&targetIsFolder, &wasAliased) == noErr && wasAliased) {
						
					CFURLRef resolvedUrl = CFURLCreateFromFSRef(NULL, &fsRef);
					if (resolvedUrl != NULL) {
						resolved_path = (NSString*)CFURLCopyFileSystemPath(resolvedUrl,
										kCFURLPOSIXPathStyle);
						CFRelease(resolvedUrl);
					}
				}
			}
			CFRelease(url);
		}
 
		if (resolved_path != nil)
			return resolved_path;
	}
	
	return source_path;
}

@end

@implementation FileTreeNode

#pragma mark initialize and class method
- (id) init
{
	self = [super init];
	if (self==nil) return nil;
	
	_isChildrenLoaded = NO;
	return self;
}

- (id) initWithPath:(NSString *)path parent:(FileTreeNode *)parent
{
	return [self initWithData:[FileTreeNodeData fileTreeNodeDataWithPath:path] parent:parent];
}

+ (id)fileTreeNodeWithPath:(NSString *)path parent:(FileTreeNode *)parent
{
	return [[[[self class] alloc] initWithPath:path parent:parent] autorelease];
}

+ (id)fileTreeNodeWithPath:(NSString *)path parent:(FileTreeNode *)parent atIndex:(int)index
{
	FileTreeNode *obj = [FileTreeNode fileTreeNodeWithPath:path parent:nil];
	[parent insertChild:obj atIndex:index];
	return obj;
}

#pragma mark indexPath
- (FileTreeNode *)childWithIndexPath:(NSIndexPath *)indexPath currentLevel:(unsigned int)level
{
	FileTreeNode *child = (FileTreeNode *)[self childNodeAtIndex:[indexPath indexAtPosition:level]];
	if ([indexPath length] == ++level) {
		return child;
	}
	else {
		return [child childWithIndexPath:indexPath currentLevel:level];
	}
}

- (NSIndexPath *)indexPathForChild:(FileTreeNode *)child
{
	FileTreeNode *parent = (FileTreeNode *)[self nodeParent];
	int index = [self indexOfChild:child];
	if (parent) {
		NSIndexPath *index_path = [parent indexPathForChild:self];
		return [index_path indexPathByAddingIndex:index];
	}
	else {
		return [NSIndexPath indexPathWithIndex:index];
	}
}

- (NSIndexPath *)indexPath
{
	FileTreeNode *parent = (FileTreeNode *)[self nodeParent];
	if (parent) {
		return [(FileTreeNode *)[self nodeParent] indexPathForChild:self];
	}
	else {
		return nil;
	}
}

#pragma mark accessors
- (FileTreeNodeData *)nodeData
{
	return (FileTreeNodeData *)[super nodeData];
}

- (NSString *)path
{
	return [[self nodeData] path];
}

#pragma mark renaming
- (BOOL)changeNameTo:(NSString *)newName
{
	NSFileManager *file_manager = [NSFileManager defaultManager];
	FileTreeNodeData *node_data = [self nodeData];
	NSString *original_path = [node_data path];
	NSString *new_path = [[original_path stringByDeletingLastPathComponent] 
								stringByAppendingPathComponent:newName];
	
	if ([file_manager fileExistsAtPath:new_path]) return NO;
	
	if ([file_manager movePath:original_path toPath:new_path handler:nil]) {
		[node_data setPath:new_path];
		[node_data loadFileInfo];
		return YES;
	}
	return NO;
}

- (BOOL)renameChild:(FileTreeNode *)child intoName:(NSString *)newName withView:(NSOutlineView *)view
{
	BOOL result = [child changeNameTo:newName];
	if (result) {
		[self saveOrderWithView:view];
	}
	return result;
}

#pragma mark remove
- (void)removeChildWithFileDelete:(FileTreeNode *)child
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSString *path = [[child nodeData] path];
	NSString *source_path = [path stringByDeletingLastPathComponent];
	NSString *file_name = [path lastPathComponent];
	[workspace performFileOperation:NSWorkspaceRecycleOperation 
			source:source_path destination:nil 
			files:[NSArray arrayWithObject:file_name] tag:nil];

	[self removeChild:child];
}

- (BOOL)removeChildWithPath:(NSString *) path removedIndex:(int *)indexPtr
{
	NSFileManager *file_manager = [NSFileManager defaultManager];
	NSArray *children = [self children];
	NSEnumerator *enumerator = [children objectEnumerator];
	FileTreeNode *child;
	BOOL result = NO;
	int itemCounter = 0;
	while (child = [enumerator nextObject]) {
		NSString *child_path = [[child nodeData] path];
		if ([child_path isEqualToString:path]) {
			result = [file_manager removeFileAtPath:path handler:nil];
			if (result) [self removeChild:child];
			break;
		}
		itemCounter++;
	}
	if (indexPtr != nil) *indexPtr = itemCounter;
	return result;
}

#pragma mark create
- (NSString *)copyOrMoveFromPath:(NSString *)sourcePath 
							withSelector:(SEL)aSelector
							atIndex:(int *)indexPtr
							withReplacing:(BOOL)replaceFlag
{
	NSString *new_folder_path = [[self nodeData] path];
	NSString *target_path = [new_folder_path stringByAppendingPathComponent:
										[sourcePath lastPathComponent]];
										
	NSFileManager *file_manager = [NSFileManager defaultManager];
	NSInvocation *invocation  = [NSInvocation invocationWithMethodSignature:
									[file_manager methodSignatureForSelector:aSelector]];
	[invocation setSelector:aSelector];
	[invocation setTarget:file_manager];
	SEL dummy = nil;
	[invocation setArgument:&dummy atIndex:4];
	[invocation setArgument:&sourcePath atIndex:2];
	[invocation setArgument:&target_path atIndex:3];
	[invocation invoke];
	BOOL result;
	[invocation getReturnValue:&result];
	if(!result) {
		if (replaceFlag) {
			int removedIndex;
			if (![self removeChildWithPath:target_path removedIndex:&removedIndex]) {
				NSException *exception = [NSException exceptionWithName:@"FileRemoveException"
						reason:[NSString stringWithFormat:@"Fail to Remove %@.", target_path]
						userInfo:nil];
				@throw exception;			
			}
			if (removedIndex < *indexPtr) (*indexPtr)--;
			[invocation invoke];
		}
		else {
			NSException *exception = [NSException exceptionWithName:@"FileMoveOrCopyException"
					reason:[NSString stringWithFormat:@"Fail for source: %@,target %@", sourcePath, target_path]
					userInfo:nil];
			@throw exception;
		}
	}
	return target_path;
}

- (FileTreeNode *)createChildFromPath:(NSString *)sourcePath 
							withSelector:(SEL)aSelector
							atIndex:(int *)indexPtr
							withReplacing:(BOOL)replaceFlag
{
	NSString *new_path = [self copyOrMoveFromPath:sourcePath withSelector:aSelector
									atIndex:indexPtr withReplacing:(BOOL)replaceFlag];
	return [FileTreeNode fileTreeNodeWithPath:new_path parent:self atIndex:*indexPtr];
}
							
- (FileTreeNode *)createChildWithMovingPath:(NSString *)sourcePath atIndex:(int *)indexPtr
							withReplacing:(BOOL)replaceFlag
{
	return [self createChildFromPath:sourcePath 
							withSelector:@selector(movePath:toPath:handler:)
							atIndex:indexPtr withReplacing:replaceFlag];
}

- (FileTreeNode *)createChildWithCopyingPath:(NSString *)sourcePath atIndex:(int *)indexPtr
							withReplacing:(BOOL)replaceFlag
{
		return [self createChildFromPath:sourcePath 
							withSelector:@selector(copyPath:toPath:handler:)
							atIndex:indexPtr withReplacing:replaceFlag];
}

- (FileTreeNode *)createFolderAtIndex:(int)index withName:(NSString *)aName
{
	NSString *new_path = [[self path] stringByAppendingPathComponent:aName];
	new_path = [new_path uniqueName];
	
	NSFileManager *file_manager = [NSFileManager defaultManager];
	if (![file_manager createDirectoryAtPath:new_path attributes:nil]) return nil;
	
	return [FileTreeNode fileTreeNodeWithPath:new_path parent:self atIndex:index];	
}


- (FileTreeNode *)createFolderAfter:(FileTreeNode *)item withName:(NSString *)aName
{
	NSInteger child_index;
	if (item) {
		child_index = [self indexOfChild:item];
	}
	else {
		child_index = [[self children] count]-1;
	}
	
	if (child_index == NSNotFound) return nil;
		
	return [self createFolderAtIndex:++child_index withName:aName];
}

#pragma mark insert
- (FileTreeNode *)insertChildWithCopy:(FileTreeNode *)child atIndex:(int)index 
{
	NSString *new_folder_path = [[self nodeData] path];
	NSString *source_path, *target_path;
	NSFileManager *file_manager = [NSFileManager defaultManager];
	
	source_path = [[child nodeData] path];
	target_path = [new_folder_path stringByAppendingPathComponent:[source_path lastPathComponent]];
	target_path = [target_path uniqueName];
	[file_manager copyPath:source_path toPath:target_path handler:nil];
	FileTreeNode *new_node = [FileTreeNode fileTreeNodeWithPath:target_path parent:nil];
	[self insertChild:new_node atIndex:index];
	return new_node;
}

- (NSMutableArray *)insertChildrenWithCopy:(NSArray*)children atIndex:(int)index 
{
	NSString *new_folder_path = [[self nodeData] path];
	NSEnumerator *enumerator = [children objectEnumerator];
	FileTreeNode *source_child;
	NSString *source_path, *target_path;
	NSFileManager *file_manager = [NSFileManager defaultManager];
	NSMutableArray *new_nodes = [NSMutableArray array];
	
	while (source_child = [enumerator nextObject]) {
		source_path = [[source_child nodeData] path];
		target_path = [new_folder_path stringByAppendingPathComponent:[source_path lastPathComponent]];
		target_path = [target_path uniqueName];
		[file_manager copyPath:source_path toPath:target_path handler:nil];
		[new_nodes addObject:[FileTreeNode fileTreeNodeWithPath:target_path parent:nil]];
	}
	
	[self insertChildren:new_nodes atIndex: index];
	return new_nodes;
}

- (FileTreeNode *)insertChildWithMove:(FileTreeNode *)child
						atIndex:(int *)indexPtr withReplacing:(BOOL)replaceFlag
{
	FileTreeNode *source_parent = (FileTreeNode*)[child nodeParent];
	if (self == source_parent) {
		if  ([source_parent indexOfChild:child] < *indexPtr) (*indexPtr)--;
	}
	else {
		NSString *new_folder_path = [[self nodeData] path];
		NSFileManager *file_manager = [NSFileManager defaultManager];
		
		NSString *source_path = [[child nodeData] path];
		NSString *target_path = [new_folder_path stringByAppendingPathComponent:
													[source_path lastPathComponent]];
		if (![file_manager movePath:source_path toPath:target_path handler:nil]) {
			if (replaceFlag) {
				int removedIndex;
				if (![self removeChildWithPath:target_path removedIndex:&removedIndex]) {
					NSException *exception = [NSException exceptionWithName:@"FileRemoveException"
						reason:[NSString stringWithFormat:@"Fail to Remove %@.", target_path]
						userInfo:nil];
					@throw exception;			
				}
				if (removedIndex < *indexPtr) (*indexPtr)--;
				if (![file_manager movePath:source_path toPath:target_path handler:nil])
					NSLog(@"Fail to move with replacing");
			}
			else {
				NSException *exception = [NSException exceptionWithName:@"FileMoveException"
					reason:[NSString stringWithFormat:@"Fail to move %@ to %@",source_path, target_path]
					userInfo:nil];
				@throw exception;
			}
		}
	}
	[source_parent removeChild:child];
	[self insertChild:child atIndex:*indexPtr];
	return child;
}

#pragma mark methods for maintenance
- (BOOL)shouldExpand
{
	return shouldExpand;
}

- (void)setShouldExpand:(BOOL)aBool
{
	shouldExpand = aBool;
}

- (void)setShouldExpandWithNumber:(NSNumber *)boolNumber
{
	shouldExpand = [boolNumber boolValue];
}

- (void)saveOrderWithView:(NSOutlineView *)view
{
	NSArray *children = [self children];
	NSMutableArray *order = [NSMutableArray array];
	
	NSEnumerator *enumerator = [children objectEnumerator];
	FileTreeNode *item;
	NSString *name;
	NSDictionary *dict;
	while (item = [enumerator nextObject]) {
		name = [[item nodeData] name];
		BOOL isExpanded = NO;
		if (view && [[item nodeData] isContainer]) {
			isExpanded = [view isItemExpanded:item];
		}
		dict = [NSDictionary dictionaryWithObjectsAndKeys:
				name, @"name", [NSNumber numberWithBool:isExpanded], @"isExpanded", nil];
		[order addObject:dict];
	}
	
	NSDictionary *order_dict = [NSDictionary dictionaryWithObjectsAndKeys:order, @"order", nil];
	NSString *orderFilePath = [[(FileTreeNodeData *)nodeData path] stringByAppendingPathComponent:ORDER_CHACHE_NAME];
	[order_dict writeToFile:orderFilePath atomically:YES];
}

//- (void)saveOrder
//{
//	NSArray *children = [self children];
//	NSArray *names = [children valueForKeyPath:@"nodeData.name"];
//	NSString *orderFilePath = [[(FileTreeNodeData *)nodeData path] stringByAppendingPathComponent:@"order.plist"];
//	[names writeToFile:orderFilePath atomically:YES];
//}

- (NSString *)description
{
	return [[self nodeData] path];
}

- (BOOL) updateChildrenWithView:(NSOutlineView *)view
{
	BOOL is_updated = NO;
	NSString *folder_path = [self path];
	NSEnumerator *enumerator = [[self children] objectEnumerator];
	NSMutableArray *name_list = [NSMutableArray array];
	FileTreeNode *child;
	NSMutableArray *will_remove_children = [NSMutableArray array];
	while (child = [enumerator nextObject]) {
		NSString *child_path = [child path];
		NSString *child_folder = [child_path stringByDeletingLastPathComponent];
		if ([child_folder isEqualToString:folder_path] ) {
			[name_list addObject:[child_path lastPathComponent]];
			
			//if ([[child nodeData] isContainer]) [child reloadChildrenWithView:view];
			[child reloadChildrenWithView:view];
		}
		else {
			[will_remove_children addObject:child];
		}
	}
	
	if ([will_remove_children count]) {
		[will_remove_children makeObjectsPerformSelector:@selector(removeFromParent)];
		is_updated = YES;
	}
	
	//find new items
	NSFileManager *file_manager = [NSFileManager defaultManager];
	NSArray *contents_names = [file_manager directoryContentsAtPath:folder_path];
	if (contents_names) {
		enumerator = [contents_names objectEnumerator];
		NSString *item_name, *item_path;
		while (item_name = [enumerator nextObject]) {
			if ([item_name isEqualToString:ORDER_CHACHE_NAME]) continue;
			
			if ([name_list containsObject:item_name]) continue;
			
			item_path = [folder_path stringByAppendingPathComponent:item_name];
			if (! [item_path isVisible]) continue;
			
			[self addChild:[FileTreeNode fileTreeNodeWithPath:item_path parent:self]];
			is_updated = YES;
		}
	}
	
	return is_updated;
}

- (void)reloadChildrenWithView:(NSOutlineView *)view
{
	BOOL is_updated = [[self nodeData] updateAttributes];
	
	if ( _isChildrenLoaded) {
		if ([self updateChildrenWithView:view]) {
			is_updated = YES;
		}
	}
	
	if (is_updated) [self saveOrderWithView:view];
}

- (void)loadChildren
{
	NSFileManager *file_manager = [NSFileManager defaultManager];
	
	FileTreeNodeData *node_data = [self nodeData];
	
	if ([node_data isContainer])  {
		NSString *path = [node_data path];
		NSArray *child_names = [file_manager directoryContentsAtPath:path];
		if (child_names != nil) {
			NSEnumerator *enumerator = [child_names objectEnumerator];
			NSString *child_name;
			NSString *child_path;
			NSMutableArray* child_data_array = [NSMutableArray array];
			while (child_name = [enumerator nextObject]) {
				if ([child_name isEqualToString:ORDER_CHACHE_NAME]) continue;
				
				child_path = [path stringByAppendingPathComponent:child_name];
				if ([child_path isVisible])
					[child_data_array addObject:[FileTreeNode fileTreeNodeWithPath:child_path parent:self]];
			}
			
			NSString *order_file_path = [[(FileTreeNodeData *)nodeData path] stringByAppendingPathComponent:ORDER_CHACHE_NAME];
			NSArray *order = nil;
			NSDictionary *order_dict = nil;
			if ([file_manager fileExistsAtPath:order_file_path]) {
				order_dict = [NSDictionary dictionaryWithContentsOfFile:order_file_path];
				order = [order_dict objectForKey:@"order"];
			}
			
			if (order != nil) {
				NSMutableArray *ordered_children = [NSMutableArray array];
				NSEnumerator *enumerator = [order objectEnumerator];
				NSPredicate *name_predicate;
				NSArray *filtered_array;
				NSDictionary *child_dict;
				while (child_dict = [enumerator nextObject]) {
					child_name = [child_dict objectForKey:@"name"];
					name_predicate = [NSPredicate predicateWithFormat:@"nodeData.name like %@", child_name];
					filtered_array = [child_data_array filteredArrayUsingPredicate:name_predicate];
					if ([filtered_array count]) {
						[ordered_children addObjectsFromArray:filtered_array];
						[child_data_array removeObjectsInArray:filtered_array];
						[filtered_array makeObjectsPerformSelector:
							@selector(setShouldExpandWithNumber:) withObject:[child_dict objectForKey:@"isExpanded"]];
					}
				}
				if ([child_data_array count]) {
					[ordered_children addObjectsFromArray:child_data_array];
				}
				child_data_array = ordered_children;
			}
			
			[self setChildren:child_data_array];
			
			if (order == nil) [self saveOrderWithView:nil];
		}
	}
	else {
		[self setChildren:nil];
	}
	_isChildrenLoaded = YES;
}

- (int)numberOfChildren
{
	int result;
	if (_isChildrenLoaded) {
		result = [super numberOfChildren];
	}
	else {
		[self loadChildren];
		result = [self numberOfChildren];
	}
	return result;
}

@end
