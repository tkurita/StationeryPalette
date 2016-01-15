#import <Cocoa/Cocoa.h>
#import "DropBox.h"
#import "FileTreeDataController.h"

@interface FileTreeWindowController : NSWindowController <DropBoxDragAndDrop> {
	IBOutlet id fileTreeView;
    IBOutlet FileTreeDataController *fileTreeDataController;
    IBOutlet NSTreeController *treeController;
	IBOutlet NSView *helpButtonView;
    IBOutlet NSToolbarItem *helpToolBarItem;
	IBOutlet id saveLocationField;
	IBOutlet id fileNameField;
	IBOutlet id saveToBox;
	
	BOOL shouldOpenFile;
	BOOL isFirstOpen;
}

@property (strong) NSAppleScript *insertionLocationScript;
@property (strong) NSString *untitledName;
@property (strong) NSString *previousSelectionName;
@property (strong) NSData *insertionLocationBookmark;

- (IBAction)newFileFromStationery:(id)sender;
- (IBAction)cancelAction:(id)sender;
- (IBAction)copyStationery:(id)sender;

- (void)showWindowWithFinderSelection:(id)sender;
- (void)showWindowWithDirectory:(NSString *)folderPath;

@end
