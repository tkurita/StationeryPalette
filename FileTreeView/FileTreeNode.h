#import <Cocoa/Cocoa.h>
#import "TreeNode.h"
#import "NDAlias.h"

extern NSString *ORDER_CHACHE_NAME;

@interface FileTreeNodeData : TreeNodeData {
	NSString *_path;
	NSDictionary *_attributes;
	NSString *displayName;	
	NSImage *_iconImage;
	NSString *kind;
	BOOL _isContainer;
	NDAlias *alias;
}

+ (id)fileTreeNodeDataWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;
- (void)loadFileInfo;

#pragma mark accessors
- (BOOL)isContainer;
- (NSString *)path;
- (NSString *)name;
- (NSString *)displayName;
- (NSImage *)iconImage;
- (NSString *)kind;
- (void)setAlias:(NDAlias *)theAlias;
- (NSString *)originalPath;

// private
- (BOOL)setPath:(NSString *)path;
- (void)setAttributes:(NSDictionary *)attributes;
- (void)setKind:(NSString *)kind;
- (void)setDisplayName:(NSString *)displayName;
- (void)setIconImage:(NSImage *)iconImage;

@end

@interface FileTreeNode : TreeNode {
	BOOL _isChildrenLoaded;
	BOOL shouldExpand;
}

- (id)initWithPath:(NSString *)path parent:(FileTreeNode *)parent;
+ (id)fileTreeNodeWithPath:(NSString *)path parent:(FileTreeNode *)parent;
+ (id)fileTreeNodeWithPath:(NSString *)path parent:(FileTreeNode *)parent atIndex:(int)index;

- (BOOL)renameChild:(FileTreeNode *)child intoName:(NSString *)newName withView:(NSOutlineView *)view;
- (void)removeChildWithFileDelete:(FileTreeNode *)child;
- (BOOL)removeChildWithPath:(NSString *) path removedIndex:(int *)indexPtr;

- (FileTreeNode *)createFolderAtIndex:(int)index withName:(NSString *)aName;
- (FileTreeNode *)createFolderAfter:(FileTreeNode *)item withName:(NSString *)aName;

- (NSMutableArray *)insertChildrenWithCopy:(NSArray*)children atIndex:(int)index;
- (FileTreeNode *)insertChildWithCopy:(FileTreeNode *)child atIndex:(int)index;

- (FileTreeNode *)insertChildWithMove:(FileTreeNode *)child
						atIndex:(int *)indexPtr withReplacing:(BOOL)replaceFlag;

- (FileTreeNode *)childWithIndexPath:(NSIndexPath *)indexPath currentLevel:(unsigned int)level;
- (NSIndexPath *)indexPath;

- (void)saveOrderWithView:(NSOutlineView *)view;
//- (void)saveOrder;
//- (void)reloadChildren;
- (void)reloadChildrenWithView:(NSOutlineView *)view;

- (void)setShouldExpand:(BOOL)aBool;
- (BOOL)shouldExpand;
- (void)setShouldExpandWithNumber:(NSNumber *)boolNumber;

#pragma mark accessors
- (FileTreeNodeData *)nodeData;
- (NSString *)path;

@end
