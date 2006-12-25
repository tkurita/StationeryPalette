#import "DropBox.h"

@implementation DropBox
- (id)initWithFrame:(NSRect)rect
{
    self = [super initWithFrame:rect];
    if(self) {
        NSArray* array = 
            [NSArray arrayWithObject:NSFilenamesPboardType];
        [self registerForDraggedTypes:array];
    }
    return self;
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
    //NSLog(@"draggingEntered: filenames: %@", [filenames description]);
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
    //NSLog(@"performDragOperation: filenames: %@", [filenames description]);
    if ([filenames count]) {
		didPerformDragOperation = [delegate dropBox:self acceptDrop:sender item:[filenames lastObject]];
    }

    return didPerformDragOperation;
}

@end
