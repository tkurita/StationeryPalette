#import "PathExtra.h"
#include <sys/param.h>
#include <unistd.h>;

@implementation NSString (PathExtra)

- (BOOL)isVisible
{
	FSRef ref;
	//OSStatus status = FSPathMakeRef((UInt8 *)[self UTF8String], &ref, NULL);
	OSStatus status = FSPathMakeRef((UInt8 *)[self fileSystemRepresentation], &ref, NULL);
	NSAssert(status == noErr, @"Error in FSPathMakeRef");
	FSCatalogInfo catalogInfo;
	OSErr err = FSGetCatalogInfo (&ref,
								  kFSCatInfoFinderInfo,
								  &catalogInfo,
								  NULL, NULL, NULL);
	NSAssert(err == noErr, @"Error in FSGetCatalogInfo");
	FileInfo *theFileInfo = (FileInfo *)(&catalogInfo.finderInfo);
	//int tmp = theFileInfo->finderFlags & kIsInvisible;
	return ((theFileInfo->finderFlags & kIsInvisible) ==  0) ;
}

- (BOOL)setStationeryFlag:(BOOL)newFlag
{
	FSRef ref;
	//OSStatus status = FSPathMakeRef((UInt8 *)[self UTF8String], &ref, NULL);
	Boolean is_directory;
	OSStatus status = FSPathMakeRef((UInt8 *)[self fileSystemRepresentation], &ref, &is_directory);
	NSAssert(status == noErr, @"Error in FSPathMakeRef");
	NSAssert1(is_directory == NO, @"Can't set stationary flag to directory %@", self);
	
	FSCatalogInfo catalogInfo;
	OSErr err = FSGetCatalogInfo (&ref,
								  kFSCatInfoFinderInfo,
								  &catalogInfo,
								  NULL, NULL, NULL);
	NSAssert(err == noErr, @"Error in FSGetCatalogInfo");
	FileInfo *theFileInfo = (FileInfo *)(&catalogInfo.finderInfo);
	BOOL is_stationery = ((theFileInfo->finderFlags & kIsStationery) == kIsStationery);

	BOOL result = NO;
	if (newFlag != is_stationery) {
		if (newFlag) {
			theFileInfo->finderFlags |= kIsStationery;
		}
		else {
			theFileInfo->finderFlags &= (~kIsStationery);
		}
		err = FSSetCatalogInfo (&ref, kFSCatInfoFinderInfo, &catalogInfo);
		NSAssert(err == noErr, @"Error in FSGetCatalogInfo");
		result = YES;
	}
	
	return result;
}

- (NSString *)uniqueName
{
	NSFileManager *file_manager = [NSFileManager defaultManager];
	if (![file_manager fileExistsAtPath:self]) return self;
	
	NSString *dir_path = [self stringByDeletingLastPathComponent];
	NSString *file_suffix = [self pathExtension];
	NSString *base_name = [[self lastPathComponent] stringByDeletingPathExtension];
	NSString *copy_suffix_format = NSLocalizedString(@"%@ copy", @"The suffix for the dupulicated items");
	NSString *new_path = [dir_path stringByAppendingPathComponent:
					[NSString stringWithFormat:copy_suffix_format, base_name]];
	BOOL has_suffix = ([file_suffix length] > 0);
	
	if (has_suffix) 
		new_path = [new_path stringByAppendingPathExtension:file_suffix];
	
	int n = 1;
	NSString *new_name;
	copy_suffix_format = NSLocalizedString(@"%@ copy%d", @"The suffix for the dupulicated items");
	while ([file_manager fileExistsAtPath:new_path]) {
		new_name = [NSString stringWithFormat:copy_suffix_format, base_name, n++ ];
		if (has_suffix) 
			new_name = [new_name stringByAppendingPathExtension:file_suffix];
			
		new_path = [dir_path stringByAppendingPathComponent:new_name];
	}
	return new_path;
}

- (NSString *)relativePathWithBase:(NSString *)inBase {
	if (![inBase hasPrefix:@"/"])		{
		return nil	;
	}
	
	if (![self hasPrefix:@"/"]) {
		return nil;
	}
	
	NSArray *targetComps = [[self stringByStandardizingPath] pathComponents];
	
	NSString *selealizedBase = [inBase stringByStandardizingPath];
	NSArray *baseComps;
	if ([inBase hasSuffix:@"/"]) {
		selealizedBase = [selealizedBase stringByAppendingString:@"/"];
	}
	baseComps = [selealizedBase pathComponents];
	
	NSEnumerator *targetEnum = [targetComps objectEnumerator];
	NSEnumerator *baseEnum = [baseComps objectEnumerator];
	
	NSString *baseElement;
	NSString *targetElement = nil;

	BOOL hasRest = NO;
	BOOL hasTargetRest = YES;
	while( baseElement = [baseEnum nextObject]) {
		if (targetElement = [targetEnum nextObject]) {
			if (![baseElement isEqualToString:targetElement]) {
				hasRest = YES;
				break;
			}
		}
		else {
			hasTargetRest = NO;
			break;
		}
	}
	
	NSMutableArray *resultComps = [NSMutableArray array];
	if (hasRest) {
		while([baseEnum nextObject]) {
			[resultComps addObject:@".."];
		}
	}
	
	[resultComps addObject:targetElement];
	if (hasTargetRest) {
		while(targetElement = [targetEnum nextObject]) {
			[resultComps addObject:targetElement];
		}
	}
	
	return [resultComps componentsJoinedByString:@"/"];
}

@end
