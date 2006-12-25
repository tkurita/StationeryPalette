#import <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>

@interface FileTreeView : NSOutlineView
{
	IBOutlet id searchField;
	BOOL isInstalledTextInputEvent;
	BOOL isFindBegin;
	BOOL isUsingInputWindow;
	NSText *fieldEditor;
	NSTimer *resetTimer;
	EventHandlerRef textInputEventHandler;
	id searchColumnIdentifier;
	NSString *mainColumnID;
}

- (IBAction)revealSelection:(id)sender;
- (IBAction)makeFolder:(id)sender;
- (IBAction)dupulicateSelection:(id)sender;
- (IBAction)deleteSelection:(id)sender;
- (IBAction)renameSelection:(id)sender;
- (IBAction)openSelection:(id)sender;


#pragma mark public
- (void)setSearchColumnIdenteifier:(id)identifier;
- (void)findForString:(NSString *)aString;

#pragma mark private
- (void)stopResetTimer;
- (void)insertTextInputSendText:(NSString *)aString;
 
@end
