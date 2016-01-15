#import "FileDatum.h"
#import "PathExtra.h"

NSString *ORDER_CHACHE_NAME = @"order.plist";

@implementation FileDatum

@synthesize attributes;
@synthesize iconImage;
@synthesize kind;
@synthesize alias;
@synthesize isContainer;
@synthesize shouldExpand;

- (void)dealloc
{
	[attributes release];
	[iconImage release];
	[kind release];
	[alias release];
	[super dealloc];
}

- (id)initWithPath:(NSString *)aPath
{
    self = [super init];
    if (self==nil) return nil;
	
	[self setPath:aPath];
    [self loadFileInfo];
	isChildrenLoaded = NO;
    return self;
}

+ (id)fileDatumWithPath:(NSString *)aPath
{
	return [[[[self class] alloc] initWithPath:aPath] autorelease];
}

- (void)loadFileInfo
{		
	NSFileManager *file_manager = [NSFileManager defaultManager];
	NSString *a_path = [alias path];
	[self setAttributes:[file_manager fileAttributesAtPath:a_path traverseLink:YES]];
	[self setDisplayName:[file_manager displayNameAtPath:a_path]];
	
	/* icon image*/
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSImage *icon = [workspace iconForFile:a_path];
	[icon setSize:NSMakeSize(16, 16)];
	[self setIconImage:icon];
	
	isContainer = ([attributes objectForKey:NSFileType] == NSFileTypeDirectory) && 
								(![workspace isFilePackageAtPath:a_path]);
	
	NSString *kindString;
	OSStatus err = LSCopyKindStringForURL((CFURLRef)[NSURL fileURLWithPath:a_path], (CFStringRef *)&kindString);
	if (err == noErr) {
		[self setKind:kindString];
	}
	else {
		NSLog(@"can't get kind");
	}
}

- (BOOL)updateAttributes
{
	BOOL is_updated = NO;
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *a_path = [alias path];
	NSString *current_name = [fm displayNameAtPath:a_path];
	[self setDisplayName:current_name];
	
	NSString *current_kind;
	OSStatus err = LSCopyKindStringForURL((CFURLRef)[NSURL fileURLWithPath:a_path], 
													(CFStringRef *)&current_kind);
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
		NSError *error;
		[self setAttributes:[fm attributesOfItemAtPath:a_path error:&error]];
		isContainer = ([attributes objectForKey:NSFileType] == NSFileTypeDirectory)  
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
	NSMutableArray *contents_names = [[fm directoryContentsAtPath:folder_path] 
											mutableCopy];
	
	//find removed item in child_nodes
	for (NewFileTreeNode *a_node in child_nodes) {
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
	NSTreeNode *my_node = [self treeNode];
	NSArray *children = [my_node childNodes];
	if (!children) {
		return;
	}
	NSMutableArray *order = [NSMutableArray array];
	
	for (NewFileTreeNode *a_node in children) {
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
	
	if (!isContainer) {
		goto bail;
	}
	
	NSFileManager *file_manager = [NSFileManager defaultManager];	
	NSString *path = self.path;
	NSArray *child_names = [file_manager directoryContentsAtPath:path];
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
	if ([file_manager fileExistsAtPath:order_file_path]) {
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
	NSString *my_path = [self path];
	NewFileTreeNode *my_node = [self treeNode];
	NewFileTreeNode *parent_node = (NewFileTreeNode *)[my_node parentNode];
	NSString *parent_path = [[parent_node representedObject] path];
	if (![my_path hasPrefix:parent_path]) {
		[[parent_node mutableChildNodes] removeObject:my_node];
		return YES;
	}
	
	if (self.isContainer) {
		[self updateChildren];
	}
	return [self updateAttributes];
}
		 
#pragma mark custom accessors
- (BOOL)isChildrenLoaded
{
	return isChildrenLoaded;
}

- (void)setDisplayName:(NSString *)newName
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *current_name = self.name;
	
	if ([attributes objectForKey:NSFileExtensionHidden]) {
		NSString *suffix = [current_name pathExtension];
		if (![[newName pathExtension] isEqualToString:suffix]) {
			newName = [newName stringByAppendingPathExtension:suffix];
		}
	}
		
	NSString *a_path = [self path];
	NSString *new_path = [[a_path stringByDeletingLastPathComponent]
						  stringByAppendingPathComponent:newName];
	if ([fm fileExistsAtPath:new_path]) return;
	
	
	[fm movePath:a_path toPath:new_path handler:nil];
	[[[[self treeNode] parentNode] representedObject] saveOrder];
}

- (NSString *)displayName {
	NSFileManager *fm = [NSFileManager defaultManager];
	return [fm displayNameAtPath:[alias path]];
}

- (void)setPath:(NSString *)aPath
{
	BOOL result = YES;
	if (alias == nil) {
		[self setAlias:[NDAlias aliasWithPath:aPath]];
	}
	else {
		result = [alias setPath:aPath];
	}
}

- (NSString *)path
{
	return [alias path];
}

- (NewFileTreeNode *)treeNode
{
	if (! treeNode) {
		treeNode = [NewFileTreeNode treeNodeWithRepresentedObject:self];

	}
	return treeNode;
}

						   
- (BOOL)hasTreeNode
{
	return (treeNode != nil);
}
						   
- (NSString *)typeCode
{
	return NSFileTypeForHFSTypeCode([[attributes objectForKey:NSFileHFSTypeCode]
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
	return [[alias path] lastPathComponent];
}

- (NSString *)originalPath
{
	NSString *source_path = [self path];
	NSString *resolved_path = nil;
	NSString *file_type = [attributes objectForKey:NSFileType];
	
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

- (void)setShouldExpandWithNumber:(NSNumber *)boolNumber
{
	shouldExpand = [boolNumber boolValue];
}


@end
