#import "AppController.h"

#import "PathExtra.h"
#import "FileTreeWindowController.h"
#import "DonationReminder/DonationReminder.h"

#define useLog 0

@implementation AppController

#pragma mark delegate of NSApplication
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
#if useLog	
	NSLog(@"applicationShouldHandleReopen");
#endif	
	[NSApp activateIgnoringOtherApps:YES];
	return YES;
}

- (void)applicationWillBecomeActive:(NSNotification *)aNotification
{
	if (![[windowController window] isVisible]) [windowController showWindowWithFinderSelection:self];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSBundle *main_bundle = [NSBundle mainBundle];
	NSString *defaultsPlistPath = [main_bundle pathForResource:@"FactorySettings" ofType:@"plist"];
	NSDictionary *factoryDefaults = [[NSDictionary dictionaryWithContentsOfFile:defaultsPlistPath] retain];

	NSUserDefaults *user_defaults = [NSUserDefaults standardUserDefaults];
	[user_defaults registerDefaults:factoryDefaults];
	
	NSArray *app_support_dirs = NSSearchPathForDirectoriesInDomains(
						NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *root_folder_name = [user_defaults stringForKey:@"FileTreeRootName"];
	NSString *stationry_folder = [[app_support_dirs lastObject] stringByAppendingPathComponent:root_folder_name];
	
	[user_defaults setObject:stationry_folder forKey:@"FileTreeRoot"];
	
	NSFileManager *file_manager = [NSFileManager defaultManager];
	if (![file_manager fileExistsAtPath:stationry_folder]) {
		NSString *zip_path = [main_bundle pathForResource:@"Stationery" ofType:@"zip"];
		NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/ditto"
				arguments:[NSArray arrayWithObjects:@"--sequesterRsrc", @"-x", @"-k", zip_path, [app_support_dirs lastObject], nil]];
		[task waitUntilExit];
		int exit_status = [task terminationStatus];
		NSAssert2( exit_status == 0, @"Exit ditto task with status : %d, %@", exit_status, [task standardError]);
	}
}

NSString *containerPathWithDirectory(NSString *dirPath)
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	if ([workspace isFilePackageAtPath:dirPath]) {
		return [dirPath stringByDeletingLastPathComponent];
	}
	return dirPath;
}

NSString *resolveContainerPath(NSString *path)
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSFileManager *file_manager = [NSFileManager defaultManager];
	NSDictionary *file_info = [file_manager fileAttributesAtPath:path traverseLink:NO];
	NSString *file_type = [file_info objectForKey:NSFileType];

	if ([file_type isEqualToString:NSFileTypeDirectory]) {
		return [workspace isFilePackageAtPath:path] ? [path stringByDeletingLastPathComponent] : path;
	}
	
	NSString *original_path = path;
	BOOL is_directory = NO;
	if ([file_type isEqualToString:NSFileTypeSymbolicLink]) {
		original_path = [file_manager pathContentOfSymbolicLinkAtPath:path];
		file_info = [file_manager fileAttributesAtPath:original_path traverseLink:NO];
		is_directory = [[file_info objectForKey:NSFileType] isEqualToString:NSFileTypeDirectory];
	}
	else if ([file_type isEqualToString:NSFileTypeRegular]){
		NSDictionary *dict = [path infoResolvingAliasFile];
		if ([[dict objectForKey:@"WasAliased"] boolValue]) {
			original_path = [dict objectForKey:@"ResolvedPath"];
			is_directory = [[dict objectForKey:@"IsDirectory"] boolValue] ;
		}
	}

	if (is_directory && ![workspace isFilePackageAtPath:original_path])
		return original_path;
		
	return [path stringByDeletingLastPathComponent];
}

- (void)showWindowForFolder:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
	NSArray *types = [pboard types];
	NSArray *file_names;
	if (![types containsObject:NSFilenamesPboardType] 
			|| !(file_names = [pboard propertyListForType:NSFilenamesPboardType])) {
        *error = NSLocalizedString(@"Error: Pasteboard doesn't contain file paths.",
								   @"Pasteboard couldn't give string.");
        return;
    }
	
	NSString *file_path = resolveContainerPath([file_names lastObject]);
	[windowController showWindowWithDirectory:file_path];
	[NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	windowController = [[FileTreeWindowController alloc] initWithWindowNibName:@"FileTreeWindow"];
	[NSApp setServicesProvider:self];
	if (![[windowController window] isVisible]) {
		[windowController showWindowWithFinderSelection:self];
		[NSApp activateIgnoringOtherApps:YES];
	}
	[DonationReminder remindDonation];
}

@end
