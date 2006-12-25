/*
 *  NSURL+NDCarbonUtilities.m category
 *  AppleScriptObjectProject
 *
 *  Created by nathan on Wed Dec 05 2001.
 *  Copyright (c) 2001 __CompanyName__. All rights reserved.
 */

#import "NSURL+NDCarbonUtilities.h"

/*
 * category implementation NSURL (NDCarbonUtilities)
 */
@implementation NSURL (NDCarbonUtilities)

/*
 * +URLWithFSRef:
 */
+ (NSURL *)URLWithFSRef:(const FSRef *)aFsRef
{
	return [(NSURL *)CFURLCreateFromFSRef( kCFAllocatorDefault, aFsRef ) autorelease];
}

/*
 * +URLWithFileSystemPathHFSStyle:
 */
+ (NSURL *)URLWithFileSystemPathHFSStyle:(NSString *)aHFSString
{
	return [(NSURL *)CFURLCreateWithFileSystemPath( kCFAllocatorDefault, (CFStringRef)aHFSString, kCFURLHFSPathStyle, [aHFSString hasSuffix:@":"] ) autorelease];
}

/*
 * -getFSRef:
 */
- (BOOL)getFSRef:(FSRef *)aFsRef
{
	return CFURLGetFSRef( (CFURLRef)self, aFsRef ) != 0;
}

/*
 * -getFSRef:
 */
- (BOOL)getFSSpec:(FSSpec *)aFSSpec
{
	FSRef			aFSRef;

	return [self getFSRef:&aFSRef] && (FSGetCatalogInfo( &aFSRef, kFSCatInfoNone, NULL, NULL, aFSSpec, NULL ) == noErr);
}

/*
 * -URLByDeletingLastPathComponent
 */
- (NSURL *)URLByDeletingLastPathComponent
{
	return [(NSURL *)CFURLCreateCopyDeletingLastPathComponent( kCFAllocatorDefault, (CFURLRef)self) autorelease];
}

/*
 * -fileSystemPathHFSStyle
 */
- (NSString *)fileSystemPathHFSStyle
{
    return [(NSString *)CFURLCopyFileSystemPath((CFURLRef)self, kCFURLHFSPathStyle) autorelease];
}

/*
 * -resolveAliasFile
 */
- (NSURL *)resolveAliasFile
{
	FSRef			theRef;
	Boolean		theIsTargetFolder,
					theWasAliased;
	NSURL			* theResolvedAlias = nil;;

	[self getFSRef:&theRef];

	if( (FSResolveAliasFile ( &theRef, YES, &theIsTargetFolder, &theWasAliased ) == noErr) )
	{
		theResolvedAlias = (theWasAliased) ? [NSURL URLWithFSRef:&theRef] : self;
	}

	return theResolvedAlias;
}

/*
 * -finderInfoFlags:type:creator:
 */
- (BOOL)finderInfoFlags:(UInt16*)aFlags type:(OSType*)aType creator:(OSType*)aCreator
{
	FSRef         theFSRef;
	FSCatalogInfo catalogInfo = {0};

	if ([self getFSRef:&theFSRef] && 
		FSGetCatalogInfo(&theFSRef, kFSCatInfoFinderInfo, &catalogInfo, NULL ,NULL, NULL) == noErr )
	{
		FileInfo *finfo = (FileInfo *)(&catalogInfo.finderInfo);
		if (aFlags) *aFlags = finfo->finderFlags;
		if (aType) *aType = finfo->fileType;
		if (aCreator) *aCreator = finfo->fileCreator;

		return YES;
	}
	else
		return NO;
}

/*
 * -finderLocation
 */
- (NSPoint)finderLocation
{
	NSPoint		thePoint = NSMakePoint( 0, 0 );
	FSRef		theFSRef;
	FSCatalogInfo catalogInfo = {0};
	
	if ([self getFSRef:&theFSRef] && 
		FSGetCatalogInfo(&theFSRef, kFSCatInfoFinderInfo, &catalogInfo, NULL ,NULL, NULL) == noErr )
	{
		Point location;
		FileInfo *finfo = (FileInfo *)(&catalogInfo.finderInfo);
		location = finfo->location;
		thePoint = NSMakePoint(location.h, location.v);
	}
	return thePoint;
}

/*
 * -setFinderInfoFlags:mask:type:creator:
 */
- (BOOL)setFinderInfoFlags:(UInt16)aFlags mask:(UInt16)aMask type:(OSType)aType creator:(OSType)aCreator
{
	BOOL		theResult = NO;
	FSRef		theFSRef;
	FSCatalogInfo catalogInfo = {0};
	
	if ([self getFSRef:&theFSRef] && 
		FSGetCatalogInfo(&theFSRef, kFSCatInfoFinderInfo, &catalogInfo, NULL ,NULL, NULL) == noErr )
	{
		FileInfo *finfo = (FileInfo *)(&catalogInfo.finderInfo);
		finfo->finderFlags = (aFlags & aMask) | (finfo->finderFlags & !aMask);
		finfo->fileType = aType;
		finfo->fileCreator = aCreator;

		theResult = (FSSetCatalogInfo(&theFSRef, kFSCatInfoFinderInfo, &catalogInfo) == noErr);
	}

	return theResult;
}

/*
 * -setFinderLocation:
 */
- (BOOL)setFinderLocation:(NSPoint)aLocation
{
	BOOL          theResult = NO;
	FSRef         theFSRef;
	FSCatalogInfo catalogInfo = {0};

	if ([self getFSRef:&theFSRef] && 
		FSGetCatalogInfo(&theFSRef, kFSCatInfoFinderInfo|kFSCatInfoNodeFlags, &catalogInfo, NULL ,NULL, NULL) == noErr )
	{
		Point *locationPtr;
		// file ‚Æ folder ‚ÅU‚è•ª‚¯‚é•K—v‚Í‚È‚¢‚©‚à
		if (catalogInfo.nodeFlags & kFSNodeIsDirectoryMask == 0) {
			FileInfo *finfo = (FileInfo *)(&catalogInfo.finderInfo);
			locationPtr = &finfo->location;
		}
		else {
			FolderInfo *finfo = (FolderInfo *)(&catalogInfo.finderInfo);
			locationPtr = &finfo->location;
		}
		
		locationPtr->h = aLocation.x;
		locationPtr->v = aLocation.y;
		
		theResult = (FSSetCatalogInfo(&theFSRef, kFSCatInfoFinderInfo, &catalogInfo ) == noErr);
	}

	return theResult;
}

@end

@implementation NSURL (NDCarbonUtilitiesInfoFlags)

- (BOOL)hasCustomIcon
{
	UInt16	theFlags;
	return [self finderInfoFlags:&theFlags type:NULL creator:NULL] == YES && (theFlags & kHasCustomIcon) != 0;
}

@end



