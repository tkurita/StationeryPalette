#import <Cocoa/Cocoa.h>
//#import "FileTreeView.h"
@class FileTreeView;
@class FileTreeNode;

@protocol FileTreeViewDataSource
- (void)fileTreeView:(FileTreeView *)ftv addNodesWithPathes:(NSArray *)pathArray afterNode:(FileTreeNode *)node;
- (void)fileTreeView:(FileTreeView *)ftv makeFolderAfter:(FileTreeNode *)item;
- (void)fileTreeView:(FileTreeView *)ftv revealItems:(NSArray *)array;
- (void)fileTreeView:(FileTreeView *)ftv deleteItems:(NSArray *)array;
- (void)fileTreeView:(FileTreeView *)ftv renameItem:(id)item intoName:newName;
- (void)fileTreeView:(FileTreeView *)ftv dupulicateItems:(NSArray *)array;
- (void)fileTreeView:(FileTreeView *)ftv didEndDragOperation:(NSDragOperation)operation;
@end
