#import <Cocoa/Cocoa.h>
#import "DropBox.h"
#import "FileTreeDataController.h"

@interface FileTreeWindowController : NSWindowController <DropBoxDragAndDrop> {
	IBOutlet id fileTreeView;
	IBOutlet id fileTreeDataSource;
    IBOutlet FileTreeDataController *fileTreeDataController;
    IBOutlet NSTreeController *treeController;
	IBOutlet NSView *helpButtonView;
    IBOutlet NSToolbarItem *helpToolBarItem;
	IBOutlet id saveLocationField;
	IBOutlet id fileNameField;
	IBOutlet id saveToBox;
	
	NSAppleScript *insertionLocationScript;
	BOOL shouldOpenFile;
	BOOL isFirstOpen;
	NSString *untitledName;
	//FileTreeView *previousSelection;
	NSString *previousSelectionName;
}

@property (retain) NSData *insertionLocationBookmark;

- (IBAction)newFileFromStationery:(id)sender;
- (IBAction)cancelAction:(id)sender;
- (IBAction)copyStationery:(id)sender;

- (void)showWindowWithFinderSelection:(id)sender;
- (void)showWindowWithDirectory:(NSString *)folderPath;

@end
