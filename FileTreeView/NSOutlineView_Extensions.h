#import <Cocoa/Cocoa.h>

@interface NSOutlineView (MyExtensions)

- (id)selectedItem;
- (NSArray*)allSelectedItems;
- (void)selectItems:(NSArray*)items byExtendingSelection:(BOOL)extend;


@end