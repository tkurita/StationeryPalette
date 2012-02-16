#import "NSOutlineView_Extensions.h"

@implementation NSOutlineView (MyExtensions)

- (id)selectedItem { return [self itemAtRow: [self selectedRow]]; }

- (NSArray *)allSelectedItems {
    NSMutableArray *items = [NSMutableArray array];
	NSIndexSet *indexSet = [self selectedRowIndexes];
	
	unsigned current_index = [indexSet firstIndex];
	while (current_index != NSNotFound) {
		[items addObject:[self itemAtRow:current_index]];
		current_index = [indexSet indexGreaterThanIndex: current_index];
	}
	
    return items;
}

- (void)selectItems:(NSArray*)items byExtendingSelection:(BOOL)extend {
    unsigned int i, totalCount = [items count];
    if (extend==NO) [self deselectAll:nil];
    for (i = 0; i < totalCount; i++) {
        int row = [self rowForItem:[items objectAtIndex:i]];
        if(row>=0) 
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
}

@end
