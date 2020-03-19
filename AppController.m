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
	if (![[_windowController window] isVisible])
        [_windowController showWindowWithFinderSelection:self];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSBundle *main_bundle = [NSBundle mainBundle];
	NSString *defaultsPlistPath = [main_bundle pathForResource:@"FactorySettings" ofType:@"plist"];
	NSDictionary *factoryDefaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPlistPath];

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
				arguments:@[@"--sequesterRsrc", @"-x", @"-k", zip_path, [app_support_dirs lastObject]]];
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
	NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSDictionary *file_info = [fm attributesOfItemAtPath:path error:&err];
	NSString *file_type = file_info[NSFileType];

	if ([file_type isEqualToString:NSFileTypeDirectory]) {
		return [workspace isFilePackageAtPath:path] ? [path stringByDeletingLastPathComponent] : path;
	}
	
	NSString *original_path = path;
	BOOL is_directory = NO;
	if ([file_type isEqualToString:NSFileTypeSymbolicLink]) {
        original_path = [fm destinationOfSymbolicLinkAtPath:path error:&err];
        if (err) {
            [NSApp presentError:err];
            return nil;
        }
        file_info = [fm attributesOfItemAtPath:original_path error:&err];
        if (err) {
            [NSApp presentError:err];
            return nil;
        }
		is_directory = [file_info[NSFileType] isEqualToString:NSFileTypeDirectory];
	}
	else if ([file_type isEqualToString:NSFileTypeRegular]){
		NSDictionary *dict = [path infoResolvingAliasFile];
		if ([dict[@"WasAliased"] boolValue]) {
			original_path = dict[@"ResolvedPath"];
			is_directory = [dict[@"IsDirectory"] boolValue] ;
		}
	}

	if (is_directory && ![workspace isFilePackageAtPath:original_path])
		return original_path;
		
	return [path stringByDeletingLastPathComponent];
}

- (void)showWindowForFolder:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
#if useLog
    NSLog(@"%@", @"startshowWindowForFolder");
#endif
    NSArray *types = [pboard types];
	NSArray *file_names;
	if (![types containsObject:NSFilenamesPboardType] 
			|| !(file_names = [pboard propertyListForType:NSFilenamesPboardType])) {
        *error = NSLocalizedString(@"Error: Pasteboard doesn't contain file paths.",
								   @"Pasteboard couldn't give string.");
        NSLog(@"%@", *error);
        return;
    }
	
	NSString *file_path = resolveContainerPath([file_names lastObject]);
	[_windowController showWindowWithDirectory:file_path];
	[NSApp activateIgnoringOtherApps:YES];
}

- (void)showWindowForFinderSelection:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
#if useLog
    NSLog(@"%@", @"showWindowForFinderSelection");
#endif
    [_windowController showWindowWithFinderSelection:self];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#if useLog
	NSLog(@"start applicationDidFinishLaunching");
#endif
	self.windowController = [[FileTreeWindowController alloc]
                             initWithWindowNibName:@"FileTreeWindow"];
	[NSApp setServicesProvider:self];
	if (![[_windowController window] isVisible]) {
		[_windowController showWindowWithFinderSelection:self];
		[NSApp activateIgnoringOtherApps:YES];
	}
	[DonationReminder remindDonation];
}

@end
