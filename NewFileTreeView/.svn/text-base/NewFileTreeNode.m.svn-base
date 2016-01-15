#import "NewFileTreeNode.h"
#import "FileDatum.h"

@implementation NewFileTreeNode

@synthesize isExpanded;

- (id) init
{
	self = [super init];
	if (!self) return nil;
	
	isExpanded = NO;
	return self;
}

- (BOOL)isLeaf
{
	return ![(FileDatum*)[self representedObject] isContainer];
}

- (NSArray *)childNodes
{
	FileDatum *file_datum = [self representedObject];
	if (![file_datum isChildrenLoaded]) {
		[[self representedObject] loadChildren];
	}
	return [super childNodes];
}

- (BOOL)isDescendantOfNode:(NSTreeNode *)node {
    // returns YES if 'node' is an ancestor.
    // Walk up the tree, to see if any of our ancestors is 'node'.
    NSTreeNode *parent = self;
    while(parent) {
        if(parent==node) return YES;
        parent = [parent parentNode];
    }
    return NO;
}

/*
- (BOOL)isDescendantOfNodeInArray:(NSArray *)nodes {
    // returns YES if any 'node' in the array 'nodes' is an ancestor of ours.
    // For each node in nodes, if node is an ancestor return YES.  If none is an
    // ancestor, return NO.
    NSEnumerator *nodeEnum = [nodes objectEnumerator];
    TreeNode *node = nil;
    while((node=[nodeEnum nextObject])) {
        if([self isDescendantOfNode:node]) return YES;
    }
    return NO;
}

+ (NSArray *) minimumNodeCoverFromNodesInArray: (NSArray *)allNodes {
    NSMutableArray *minimumCover = [NSMutableArray array];
    NSMutableArray *nodeQueue = [NSMutableArray arrayWithArray:allNodes];
    TreeNode *node = nil;
    while ([nodeQueue count]) {
        node = [nodeQueue objectAtIndex:0];
        [nodeQueue removeObjectAtIndex:0];
        while ( [node parentNode] && [nodeQueue containsObjectIdenticalTo:[node parentNode]] ) {
            [nodeQueue removeObjectIdenticalTo: node];
            node = [node parentNode];
        }
        if (![node isDescendantOfNodeInArray: minimumCover]) [minimumCover addObject: node];
        [nodeQueue removeObjectIdenticalTo: node];
    }
    return minimumCover;
}
*/
@end
