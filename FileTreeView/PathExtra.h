#import <Cocoa/Cocoa.h>


@interface NSString (PathExtra)

- (BOOL)isVisible;
- (BOOL)setStationeryFlag:(BOOL)newFlag;
- (NSString *)relativePathWithBase:(NSString *)inBase;
- (NSString *)uniqueName;

@end
