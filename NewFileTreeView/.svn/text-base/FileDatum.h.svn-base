#import <Cocoa/Cocoa.h>
#import "NDAlias.h"
#import "NewFileTreeNode.h"

@interface FileDatum : NSObject {
	NewFileTreeNode *treeNode;
	NSDictionary *attributes;
	NSImage *iconImage;
	NSString *kind;
	BOOL isContainer;
	NDAlias *alias;
	
	BOOL isChildrenLoaded;
	BOOL shouldExpand;
}

@property (retain) NSDictionary *attributes;
@property (retain) NSImage *iconImage;
@property (retain) NSString *kind;
@property (retain) NDAlias *alias;

@property (assign) BOOL isContainer;
@property (assign) BOOL shouldExpand;

+ (id)fileDatumWithPath:(NSString *)aPath;
- (void)loadChildren;

- (BOOL)isChildrenLoaded;
- (void)setDisplayName:(NSString *)aName;
- (NSString *)displayName;
- (void)setPath:(NSString *)aPath;
- (NSString *)path;
- (NSString *)name;
- (NewFileTreeNode *)treeNode;
- (NSString *)typeCode;
- (NSString *)typeForPboard;
- (void)loadFileInfo;
- (void)setShouldExpandWithNumber:(NSNumber *)boolNumber;
- (void)saveOrder;
- (BOOL)update;

@end
