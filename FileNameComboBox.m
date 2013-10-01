#import "FileNameComboBox.h"


@implementation FileNameComboBox

- (BOOL)becomeFirstResponder
{
	BOOL result = [super becomeFirstResponder];
	NSText* field_editor = [self.window fieldEditor:YES forObject:self];
	NSString *filename = [self stringValue];
	NSRange range = {0, [[filename stringByDeletingPathExtension] length]};
	[field_editor setSelectedRange:range];
	return result;

}

@end
