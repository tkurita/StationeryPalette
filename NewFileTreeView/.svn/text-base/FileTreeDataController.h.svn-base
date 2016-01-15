#import <Cocoa/Cocoa.h>
#import "FileDatum.h"

@interface FileTreeDataController : NSResponder {
	IBOutlet NSTreeController *treeController;
	IBOutlet NSOutlineView *outlineView;
	IBOutlet id conflictErrorWindow;
	IBOutlet id applyAllSwitch;
	IBOutlet id conflictMessage;
	IBOutlet id iconInConflictErrorWindow;
	IBOutlet id cancelForItemButton;
	IBOutlet id doubleActionTarget;
	
	NSTreeNode *rootNode;
	FileDatum *rootDirectory;
	
	//related move and copy with drag&drop
	NSEnumerator *nodeEnumerator;
	NSInvocation *afterSheetInvocation;
	NSIndexPath *destinationIndexPath;
	NSTreeNode *destinationNode;
	NSString *destinationPath;
	BOOL applyAllFlag;
	NSMutableArray *processedNodes;
	NSMutableArray *nodesToDelete;
	unsigned int restItemsCount;
	NSString *conflictMessageTemplate;
}

@property (retain) NSTreeNode *rootNode;
@property (retain) FileDatum *rootDirectory;
@property (retain) NSEnumerator *nodeEnumerator;
@property (retain) NSInvocation *afterSheetInvocation;
@property (retain) NSIndexPath *destinationIndexPath;
@property (retain) NSTreeNode *destinationNode;
@property (retain) NSString *destinationPath;
@property (retain) NSMutableArray *processedNodes;
@property (retain) NSMutableArray *nodesToDelete;
@property (retain) NSString *conflictMessageTemplate;

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
@end
