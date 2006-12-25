#import "KeyedUnarchiveFromDataTransformer.h"


@implementation KeyedUnarchiveFromDataTransformer
+ (Class)transformedValueClass
{
	return [NSArray class];
}


+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue:(id)value
{
	NSLog([[NSKeyedUnarchiver unarchiveObjectWithData:value] description]);
	return [NSKeyedUnarchiver unarchiveObjectWithData:value];
}
		
- (id)reverseTransformedValue:(id)value
{
	NSLog([value description]);
	return [NSKeyedArchiver archivedDataWithRootObject:value];
}
@end
