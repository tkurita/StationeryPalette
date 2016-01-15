#import "NSIndexPath_Extensions.h"


@implementation NSIndexPath (FileTreeViewExtensions)

- (NSIndexPath *)indexPathByIncrementLastIndex:(NSUInteger)increment
{
	NSUInteger index_len = [self length];
	NSUInteger indexes[index_len];
	[self getIndexes:indexes];
	indexes[index_len-1] = indexes[index_len-1] + increment;
	return [NSIndexPath indexPathWithIndexes:indexes length:index_len];
}

- (NSUInteger)lastIndex
{
	NSUInteger index_len = [self length];
	return [self indexAtPosition:index_len-1];
}

- (BOOL) isDescendantOfIndexPath:(NSIndexPath *)indexPath
{
	NSIndexPath *parent = self;
	while (YES) {
		if ([indexPath compare:parent] ==  NSOrderedSame) return YES;
		if ([parent length] == 1) break;
		parent = [parent indexPathByRemovingLastIndex];
	}
	return NO;
}

- (BOOL) isDescendantOfIndexPathInArray:(NSArray *)indexPathes
{
	for (NSIndexPath *index_path in indexPathes) {
		if ([self isDescendantOfIndexPath:index_path]) return YES;
	}
	return NO;
}

+ (NSArray *) minimumIndexPathesCoverFromIndexPathesArray: (NSArray *)allIndexPathes {
    NSMutableArray *minimumCover = [NSMutableArray array];
    NSMutableArray *index_path_queue = [NSMutableArray arrayWithArray:allIndexPathes];
    NSIndexPath *index_path = nil;
	NSIndexPath *parent_index_path = nil;
    while ([index_path_queue count]) {
        index_path = [index_path_queue objectAtIndex:0];
        [index_path_queue removeObjectAtIndex:0];
		
		while (YES) {
			if ([index_path length] == 1) break;
			parent_index_path = [index_path indexPathByRemovingLastIndex];
			BOOL break_loop = YES;
			int n = 0;
			for (NSIndexPath *idxp in index_path_queue) {
				if ([parent_index_path compare:idxp] == NSOrderedSame) {
					[index_path_queue removeObjectAtIndex:n++];
					index_path = parent_index_path;
					break_loop = NO;
				}
			}
			if (break_loop) break;			
		}
		
        if (![index_path isDescendantOfIndexPathInArray: minimumCover]) [minimumCover addObject: index_path];
    }
    return minimumCover;
}

@end
