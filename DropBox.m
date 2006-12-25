#import "DropBox.h"

#define useLog 0

@implementation DropBox

/*
- (id)initWithFrame:(NSRect)rect
{
#if useLog
	NSLog(@"initWithFrame DropBox");
#endif	
	self = [super initWithFrame:rect];
    if(self) {
        NSArray* array = 
            [NSArray arrayWithObject:NSFilenamesPboardType];
        [self registerForDraggedTypes:array];
    }
    return self;
}
*/

- (void)awakeFromNib
{
#if useLog
	NSLog(@"awakeFromNib in DropBox");
#endif
	NSArray* array = 
		[NSArray arrayWithObject:NSFilenamesPboardType];
	[self registerForDraggedTypes:array];
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
#if useLog
    NSLog(@"draggingEntered: filenames: %@", [filenames description]);
#endif	
    int dragOperation = NSDragOperationNone;
    if ([filenames count] == 1) {
        
        NSEnumerator *filenameEnum = [filenames objectEnumerator]; 
        NSString *filename;
        dragOperation = NSDragOperationCopy;
		NSFileManager *file_manager = [NSFileManager defaultManager];
		NSDictionary *file_info;
        while (filename = [filenameEnum nextObject]) {
			file_info = [file_manager fileAttributesAtPath:filename traverseLink:NO];
			if (![[file_info objectForKey:NSFileType] isEqualToString:NSFileTypeDirectory]) {
                dragOperation = NSDragOperationNone;
                break;
            }
        }
    }
    return dragOperation;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
    BOOL didPerformDragOperation = NO;
#if useLog
    NSLog(@"performDragOperation: filenames: %@", [filenames description]);
#endif	
    if ([filenames count]) {
		didPerformDragOperation = [delegate dropBox:self acceptDrop:sender item:[filenames lastObject]];
    }

    return didPerformDragOperation;
}

@end
