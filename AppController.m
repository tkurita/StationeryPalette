#import "AppController.h"

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
	if (![[windowController window] isVisible]) [windowController showWindow:self];
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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	windowController = [[FileTreeWindowController alloc] initWithWindowNibName:@"FileTreeWindow"];
	[windowController showWindow:self];
	id reminderWindow = [DonationReminder remindDonation];
	if (reminderWindow != nil) [NSApp activateIgnoringOtherApps:YES];
}

@end
