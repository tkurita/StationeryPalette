#import <Cocoa/Cocoa.h>
#import "FileTreeNode.h"

@interface FileDatum : NSObject {
	BOOL isChildrenLoaded;
}

@property (strong) NSData *bookmarkData;
@property (strong) NSDictionary *attributes;
@property (strong) NSImage *iconImage;
@property (strong) NSString *kind;

@property (assign) BOOL isContainer;
@property (assign) BOOL shouldExpand;
@property (strong) FileTreeNode *myTreeNode;

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
- (FileTreeNode *)treeNode;
- (FileDatum *)updateBookmarkData;

@end

extern NSString *ORDER_CHACHE_NAME;