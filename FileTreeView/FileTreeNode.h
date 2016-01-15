#import <Cocoa/Cocoa.h>


@interface FileTreeNode : NSTreeNode {
}

@property (assign) BOOL isExpanded;

- (BOOL)isDescendantOfNode:(NSTreeNode *)node;
/*
- (BOOL)isDescendantOfNodeInArray:(NSArray *)nodes;
+ (NSArray *) minimumNodeCoverFromNodesInArray: (NSArray *)allNodes;
*/
@end
