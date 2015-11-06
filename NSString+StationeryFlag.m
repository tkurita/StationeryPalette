#import "NSString+StationeryFlag.h"


#ifndef AH_RETAIN
#if __has_feature(objc_arc)
#define AH_RETAIN(x) x
#define AH_RELEASE(x)
#define AH_AUTORELEASE(x) x
#define AH_SUPER_DEALLOC
#else
#define __AH_WEAK
#define AH_WEAK assign
#define AH_RETAIN(x) [x retain]
#define AH_RELEASE(x) [x release]
#define AH_AUTORELEASE(x) [x autorelease]
#define AH_SUPER_DEALLOC [super dealloc]
#endif
#endif

@implementation NSString (StationeryFlag)

- (BOOL)setStationeryFlag:(BOOL)newFlag
{
	// It looks stationery flag can't not be changed by CoreFoundation or Cocoa
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

@end
