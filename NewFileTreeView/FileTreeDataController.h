#import <Cocoa/Cocoa.h>
#import "FileDatum.h"
#import "NewFileTreeNode.h"

@interface FileTreeDataController : NSResponder {
	IBOutlet NSTreeController *treeController;
	IBOutlet NSOutlineView *outlineView;
	IBOutlet id conflictErrorWindow;
	IBOutlet id applyAllSwitch;
	IBOutlet id conflictMessage;
	IBOutlet id iconInConflictErrorWindow;
	IBOutlet id cancelForItemButton;
	IBOutlet id doubleActionTarget;
	
	FileDatum *rootDirectory;
	
	//related move and copy with drag&drop
	BOOL applyAllFlag;
	NSMutableArray *nodesToDelete;
	unsigned int restItemsCount;
	NSString *conflictMessageTemplate;
}

@property (retain) NewFileTreeNode *rootNode;
@property (retain) FileDatum *rootDirectory;
@property (retain) NSInvocation *afterSheetInvocation;
@property (retain) NSIndexPath *destinationIndexPath;
@property (retain) NewFileTreeNode *destinationNode;
@property (retain) NSString *destinationPath;
@property (retain) NSMutableArray *processedNodes;
@property (retain) NSMutableArray *nodesToDelete;
@property (retain) NSString *conflictMessageTemplate;
@property (retain) NSEnumerator *dndEnumerator;
@property (retain) NSURL *promisedDragDestination;
@property (retain) NSArray *draggedNodes;

- (IBAction)conflictErrorAction:(id)sender;
- (IBAction)deleteSelection:(id)sender;
- (IBAction)renameSelection:(id)sender;
- (IBAction)makeFolder:(id)sender;
- (IBAction)dupulicateSelection:(id)sender;
- (IBAction)revealSelection:(id)sender;
- (IBAction)openSelection:(id)sender;
- (IBAction)updateSelection:(id)sender;

- (void)setRootDirPath:(NSString *)rootDirPath;
- (NSArray *)selectedPaths;
- (void)insertCopyingPath:(NSString *)sourcePath withName:(NSString *)newname;
- (IBAction)updateRoot:(id)sender;
- (IBAction)openRootDirectory:(id)sender;
- (void)insertCopyingPathes:(NSArray *)sourcePaths;
- (void)insertCopyingURLs:(NSArray *)srcURLs;
- (void)restoreSelectionWithKey:(NSString *)keyname;

@end
