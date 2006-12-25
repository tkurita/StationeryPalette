#import <Cocoa/Cocoa.h>
#import "FileTreeNode.h"
#import "FileTreeViewDataSource.h"

@interface FileTreeDataSource : NSObject <FileTreeViewDataSource>{
	IBOutlet id _outline;
	IBOutlet id conflictErrorWindow;
	IBOutlet id applyAllSwitch;
	IBOutlet id conflictMessage;
	IBOutlet id iconInConflictErrorWindow;
	IBOutlet id cancelForItemButton;

	FileTreeNode *fileTreeRoot;
	NSString *rootDirectory;
	
	NSMutableSet *updatedNodes;
	BOOL isRootUpdated;
	NSString *conflictMessageTemplate;
	
	//related move and copy with drag&drop
	NSArray *itemsToSelect;
	NSEnumerator *nodeEnumerator;
	BOOL applyAllFlag;
	FileTreeNode *destinationNode; //is not retained
	int insertIndex;
	int restItemsCount;
	NSInvocation *nodeOperationInvocation;
	NSInvocation *afterSheetInvocation;
	NSMutableArray *promisedFiles;
	BOOL isNeededToScroll;
	
	//temporay space which are't retain
	NSArray *draggedNodes;
	NSString *currentOperationName;
}
- (IBAction)reloadData:(id)sender;
- (IBAction)reloadFileTreeNodes:(id)sender;

- (IBAction)conflictErrorAction:(id)sender;
- (void)cleanupDragMoveOrCopy;

- (void)addNodeFromPath:(NSString *)sourcePath withReplacing:(BOOL)replaceFlag;

- (FileTreeNode *)nodeWithIndexPath:(NSIndexPath *)indexPath;

@end
