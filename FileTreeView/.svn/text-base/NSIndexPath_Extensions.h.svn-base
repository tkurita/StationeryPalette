#import <Cocoa/Cocoa.h>


@interface NSIndexPath (FileTreeViewExtensions)

- (NSIndexPath *)indexPathByIncrementLastIndex:(NSUInteger)increment;
- (NSUInteger)lastIndex;
- (BOOL) isDescendantOfIndexPath:(NSIndexPath *)indexPath;
- (BOOL) isDescendantOfIndexPathInArray:(NSArray *)indexPathes;
+ (NSArray *) minimumIndexPathesCoverFromIndexPathesArray: (NSArray *)allIndexPathes;
@end
