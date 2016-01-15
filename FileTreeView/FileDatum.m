#import "FileDatum.h"
#import "PathExtra.h"

#define useLog 0

NSString *ORDER_CHACHE_NAME = @"order.plist";

@implementation FileDatum

- (void)dealloc
{
	[_attributes release];
	[_iconImage release];
	[_kind release];
    [_bookmarkData release];
	[super dealloc];
}

- (id)initWithURL:(NSURL *)anURL
{
    self = [super init];
    if (self==nil) return nil;
	
	[self setFileURL:anURL];
    [self loadFileInfo];
	isChildrenLoaded = NO;
    return self;
}

- (id)initWithPath:(NSString *)aPath
{
    return [self initWithURL:[NSURL fileURLWithPath:aPath]];
}

+ (id)fileDatumWithURL:(NSURL *)anURL
{
    return [[[[self class] alloc] initWithURL:anURL] autorelease];
}

+ (id)fileDatumWithPath:(NSString *)aPath
{
#if useLog
    NSLog(@"start fileDatumWithPath %@", aPath);
#endif
    return [[[[self class] alloc] initWithPath:aPath] autorelease];
}

- (void)loadFileInfo
{		
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *a_path = self.path;
    NSError *error = nil;
    self.attributes = [fm attributesOfItemAtPath:[a_path stringByResolvingSymlinksInPath]
                                           error:&error];
    if (error) {
        [NSApp presentError:error];
        return;
    }
	[self setDisplayName:[fm displayNameAtPath:a_path]];
	
	/* icon image*/
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSImage *icon = [workspace iconForFile:a_path];
	[icon setSize:NSMakeSize(16, 16)];
	self.iconImage = icon;
	
	_isContainer = ([_attributes objectForKey:NSFileType] == NSFileTypeDirectory) &&
								(![workspace isFilePackageAtPath:a_path]);
	NSString *kind_str;
	OSStatus err = LSCopyKindStringForURL((CFURLRef)[NSURL fileURLWithPath:a_path], (CFStringRef *)&kind_str);
	if (err == noErr) {
		self.kind = kind_str;
        CFRelease(kind_str);
	}
	else {
		NSLog(@"can't get kind");
	}
}

- (BOOL)updateAttributes
{
	BOOL is_updated = NO;
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *a_path = self.path;
	NSString *current_name = [fm displayNameAtPath:a_path];
	[self setDisplayName:current_name];
	
	NSString *current_kind;
	OSStatus err = LSCopyKindStringForURL((CFURLRef)[NSURL fileURLWithPath:a_path], 
													(CFStringRef *)&current_kind);
	NSAssert1(err == noErr, @"Fail to get kind of : %@", current_kind);
	[current_kind autorelease];
	if (![_kind isEqualToString:current_kind]) {
		self.kind = current_kind;
		is_updated = YES;
	}
	
	if (is_updated) {
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		NSImage *icon = [workspace iconForFile:a_path];
		[icon setSize:NSMakeSize(16, 16)];
		[self setIconImage:icon];
		NSError *error;
		self.attributes = [fm attributesOfItemAtPath:a_path error:&error];
		self.isContainer = ([_attributes objectForKey:NSFileType] == NSFileTypeDirectory)
							&& (![workspace isFilePackageAtPath:a_path]);
	}
	
	return is_updated;
}

- (BOOL)updateChildren
{
	BOOL is_updated = NO;
	
	NSString *folder_path = [self path];
	NSMutableArray *child_nodes = [self.treeNode mutableChildNodes];
	
	NSFileManager * fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSMutableArray *contents_names = [[fm contentsOfDirectoryAtPath:folder_path
                                                             error:&err]
                                      mutableCopy];
    if (err) {
        [NSApp presentError:err];
        return NO;
    }
	//find removed item in child_nodes
	for (FileTreeNode *a_node in child_nodes) {
		FileDatum *fd = [a_node representedObject];
		NSString *a_name = [fd name];
		if ([contents_names containsObject:a_name]) {
			[contents_names removeObject:a_name];
			is_updated = is_updated || [fd update];
		} else {
			[child_nodes removeObject:a_node];
			is_updated = YES;
		}
	}
	
	//append new items
	for (NSString *a_name in contents_names) {
		if ([a_name isEqualToString:ORDER_CHACHE_NAME]) continue;
		NSString *new_path = [self.path stringByAppendingPathComponent:a_name];
		if (![new_path isVisible]) continue;
		FileDatum *fd = [FileDatum fileDatumWithPath:new_path];
		[child_nodes addObject:[fd treeNode]];
	}
	
	if (is_updated) [self saveOrder];
	return is_updated;
}

- (void)saveOrder
{
	NSArray *children = [_myTreeNode childNodes];
	if (!children) {
		return;
	}
	NSMutableArray *order = [NSMutableArray array];
	
	for (FileTreeNode *a_node in children) {
		FileDatum *file_datum = [a_node representedObject];
		NSString *name = [file_datum name];
		BOOL is_expanded = a_node.isExpanded;
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
							  name, @"name", [NSNumber numberWithBool:is_expanded], @"isExpanded", nil];
		[order addObject:dict];
	}
	
	NSDictionary *order_dict = [NSDictionary dictionaryWithObjectsAndKeys:order, @"order", nil];
	NSString *order_file = [[self path]
								stringByAppendingPathComponent:ORDER_CHACHE_NAME];
	[order_dict writeToFile:order_file atomically:YES];
}

- (void)loadChildren
{
	if (isChildrenLoaded) return;
	
	if (!_isContainer) {
		goto bail;
	}
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *path = self.path;
    NSError *err = nil;
	NSArray *child_names = [fm contentsOfDirectoryAtPath:path
                                                   error:&err];
    if (err) {
        [NSApp presentError:err];
        return;
    }
    
	if (!(child_names && [child_names count])) goto bail;
		
	NSString *child_path;
	NSMutableArray* child_data_array = [NSMutableArray arrayWithCapacity:[child_names count]];
	
	for (NSString *a_child_name in child_names) {
		if ([a_child_name isEqualToString:ORDER_CHACHE_NAME]) continue;
		
		child_path = [path stringByAppendingPathComponent:a_child_name];
		if ([child_path isVisible]) {
			[child_data_array addObject:[FileDatum fileDatumWithPath:child_path]];
		}
	}
			
	NSString *order_file_path = [self.path stringByAppendingPathComponent:ORDER_CHACHE_NAME];
	NSArray *order = nil;
	NSDictionary *order_dict = nil;
	if ([fm fileExistsAtPath:order_file_path]) {
		order_dict = [NSDictionary dictionaryWithContentsOfFile:order_file_path];
		order = [order_dict objectForKey:@"order"];
	}
			
	if (order) {
		NSMutableArray *ordered_children = [NSMutableArray arrayWithCapacity:[order count]];
		NSPredicate *name_predicate;
		NSArray *filtered_array;
		for (NSDictionary *child_dict in order) {
			NSString *child_name = [child_dict objectForKey:@"name"];
			name_predicate = [NSPredicate predicateWithFormat:@"name like %@", child_name];
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
			order = nil;
		}
		child_data_array = ordered_children;
	}
	
	
	NSMutableArray *child_nodes = [self.treeNode mutableChildNodes];
	for (FileDatum *a_child_data in child_data_array) {
		[child_nodes addObject:[a_child_data treeNode]];
	}
	
	// child_data_array をretain するひつようはあるかな？とりあえず、retain しない。
	isChildrenLoaded = YES;
	if (order == nil) [self saveOrder];
	return;
bail:
	isChildrenLoaded = YES;
}

- (BOOL)update
{
	FileTreeNode *parent_node = (FileTreeNode *)[_myTreeNode parentNode];
	NSString *parent_path = [[parent_node representedObject] path];
	if (![self.path hasPrefix:parent_path]) {
		[[parent_node mutableChildNodes] removeObject:_myTreeNode];
		return YES;
	}
	
	if (self.isContainer) {
		[self updateChildren];
	}
	return [self updateAttributes];
}

- (FileDatum *)updateBookmarkData
{
    [self setFileURL:[self fileURL]];
    return self;
}
		 
#pragma mark custom accessors
- (BOOL)isChildrenLoaded
{
	return isChildrenLoaded;
}

- (void)setDisplayName:(NSString *)newName
{
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ([_attributes objectForKey:NSFileExtensionHidden]) {
		NSString *suffix = [self.name pathExtension];
		if (![[newName pathExtension] isEqualToString:suffix]) {
			newName = [newName stringByAppendingPathExtension:suffix];
		}
	}
    
	NSString *a_path = [self path];
	NSString *new_path = [[a_path stringByDeletingLastPathComponent]
						  stringByAppendingPathComponent:newName];
	if ([fm fileExistsAtPath:new_path]) return;
	
	NSError *err = nil;
    [fm moveItemAtPath:a_path toPath:new_path error:&err];
    if (err) {
        [NSApp presentError:err];
    }
	[[[[self treeNode] parentNode] representedObject] saveOrder];
}

- (NSString *)displayName {
	NSFileManager *fm = [NSFileManager defaultManager];
	return [fm displayNameAtPath:self.path];
}

- (void)setFileURL:(NSURL *)anURL
{
    NSError *error = nil;
    self.bookmarkData = [anURL
                         bookmarkDataWithOptions:0
                         includingResourceValuesForKeys:nil
                         relativeToURL:nil
                         error:&error];
    if (error) {
        [NSApp presentError:error];
    }
}

- (NSURL *)fileURL
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
    return url;
}

- (void)setPath:(NSString *)aPath
{
    NSError *error = nil;
    self.bookmarkData = [[NSURL fileURLWithPath:aPath]
                            bookmarkDataWithOptions:0
                            includingResourceValuesForKeys:nil
                            relativeToURL:nil
                            error:&error];
    if (error) {
        [NSApp presentError:error];
    }
}

- (NSString *)path
{
    return [[self fileURL] path];
}

- (FileTreeNode *)treeNode
{
	if (! _myTreeNode) {
		self.myTreeNode = [FileTreeNode treeNodeWithRepresentedObject:self];
        
	}
	return _myTreeNode;
}

- (BOOL)hasTreeNode
{
	return (_myTreeNode != nil);
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

- (NSString *)name
{
	return [self.path lastPathComponent];
}

- (NSString *)originalPath
{
	NSString *a_path = [self path];
	NSString *file_type = [_attributes objectForKey:NSFileType];
	
	if ([file_type isEqualToString:NSFileTypeSymbolicLink]) {
        a_path = [a_path stringByResolvingSymlinksInPath];
	}
	
	if (![file_type isEqualToString:NSFileTypeDirectory]) {
        NSDictionary *dict = [a_path infoResolvingAliasFile];
        a_path = dict[@"ResolvedPath"];
	}
	
	return a_path;
}

- (void)setShouldExpandWithNumber:(NSNumber *)boolNumber
{
	self.shouldExpand = [boolNumber boolValue];
}


- (NSString *)fileType
{
	return [_attributes objectForKey:NSFileType];
}

@end
