#import <Cocoa/Cocoa.h>
#import "NDAlias.h"
#import "DropBox.h"

@interface FileTreeWindowController : NSWindowController <DropBoxDragAndDrop> {
	IBOutlet id fileTreeView;
	IBOutlet id fileTreeDataSource;
	IBOutlet NSView *helpButtonView;
	IBOutlet id saveLocationField;
	IBOutlet id fileNameField;
	IBOutlet id saveToBox;
	
    NSMutableDictionary *toolbarItems; //The dictionary that holds all our "master" copies of the NSToolbarItems
	NSAppleScript *insertionLocationScript;
	NDAlias *insertionLocation;
	BOOL shouldOpenFile;
	BOOL isFirstOpen;
	NSString *untitledName;
	//FileTreeView *previousSelection;
	NSString *previousSelectionName;
}

- (IBAction)newFileFromStationery:(id)sender;
- (IBAction)cancelAction:(id)sender;
- (IBAction)copyStationery:(id)sender;

- (void)showWindowWithFinderSelection:(id)sender;
- (void)showWindowWithDirectory:(NSString *)folderPath;

@end
