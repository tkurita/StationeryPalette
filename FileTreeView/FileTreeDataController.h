#import <Cocoa/Cocoa.h>
#import "FileDatum.h"
#import "FileTreeNode.h"

@interface FileTreeDataController : NSResponder {
	IBOutlet NSTreeController *treeController;
	IBOutlet NSOutlineView *outlineView;
	IBOutlet id conflictErrorWindow;
	IBOutlet id applyAllSwitch;
	IBOutlet id conflictMessage;
	IBOutlet id iconInConflictErrorWindow;
	IBOutlet id cancelForItemButton;
	IBOutlet id doubleActionTarget;
		
	//related move and copy with drag&drop
	BOOL applyAllFlag;
	unsigned int restItemsCount;
}

@property (strong) FileTreeNode *rootNode;
@property (strong) FileDatum *rootDirectory;
@property (strong) NSInvocation *afterSheetInvocation;
@property (strong) NSIndexPath *destinationIndexPath;
@property (strong) FileTreeNode *destinationNode;
@property (strong) NSString *destinationPath;
@property (strong) NSMutableArray *processedNodes;
@property (strong) NSMutableArray *nodesToDelete;
@property (strong) NSString *conflictMessageTemplate;
@property (strong) NSEnumerator *dndEnumerator;
@property (strong) NSURL *promisedDragDestination;
@property (strong) NSArray *draggedNodes;

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
