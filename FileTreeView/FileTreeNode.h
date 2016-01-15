#import <Cocoa/Cocoa.h>


@interface FileTreeNode : NSTreeNode {
	BOOL isExpanded;
}

@property (assign) BOOL isExpanded;

- (BOOL)isDescendantOfNode:(NSTreeNode *)node;
/*
- (BOOL)isDescendantOfNodeInArray:(NSArray *)nodes;
+ (NSArray *) minimumNodeCoverFromNodesInArray: (NSArray *)allNodes;
*/
@end
