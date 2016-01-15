#import <Cocoa/Cocoa.h>
#import "NewFileTreeNode.h"

@interface FileDatum : NSObject {
	BOOL isChildrenLoaded;
}

@property (retain) NSData *bookmarkData;
@property (retain) NSDictionary *attributes;
@property (retain) NSImage *iconImage;
@property (retain) NSString *kind;

@property (assign) BOOL isContainer;
@property (assign) BOOL shouldExpand;
@property (assign) NewFileTreeNode *myTreeNode;

+ (id)fileDatumWithURL:(NSURL *)anURL;
+ (id)fileDatumWithPath:(NSString *)aPath;
- (void)loadChildren;

- (BOOL)isChildrenLoaded;
- (void)setDisplayName:(NSString *)aName;
- (NSString *)displayName;
- (void)setFileURL:(NSURL *)anURL;
- (NSURL *)fileURL;
- (void)setPath:(NSString *)aPath;
- (NSString *)path;
- (NSString *)name;
- (NSString *)typeCode;
- (NSString *)typeForPboard;
- (void)loadFileInfo;
- (void)setShouldExpandWithNumber:(NSNumber *)boolNumber;
- (void)saveOrder;
- (BOOL)update;
- (BOOL)updateChildren;
- (NSString *)fileType;
- (NewFileTreeNode *)treeNode;
- (FileDatum *)updateBookmarkData;

@end

extern NSString *ORDER_CHACHE_NAME;