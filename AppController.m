#import "AppController.h"
#import "FileTreeWindowController.h"
#include <Carbon/Carbon.h>

@implementation AppController
#pragma mark delegate of NSApplication

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	NSLog(@"applicationShouldHandleReopen");
	[NSApp activateIgnoringOtherApps:YES];
	return YES;
}

- (void)applicationWillBecomeActive:(NSNotification *)aNotification
{
	if (![[windowController window] isVisible]) [windowController showWindow:self];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSString *defaultsPlistPath = [[NSBundle mainBundle] pathForResource:@"FactorySettings" ofType:@"plist"];
	NSDictionary *factoryDefaults = [[NSDictionary dictionaryWithContentsOfFile:defaultsPlistPath] retain];

	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults registerDefaults:factoryDefaults];
	
	NSArray *app_support_dirs = NSSearchPathForDirectoriesInDomains(
						NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *stationry_folder = [[app_support_dirs lastObject] stringByAppendingPathComponent:@"Stationery"];
	
	[userDefaults setObject:stationry_folder forKey:@"FileTreeRoot"];
}

/*
static OSStatus appLaunched(EventHandlerCallRef nextHandler, EventRef theEvent, void* userData)
{
#if useLog    
	NSLog(@"appLaunched");
#endif
	UInt32 dataSize;
	OSStatus err = GetEventParameter(theEvent, kEventParamTextInputSendText, typeUnicodeText, NULL, 0, &dataSize, NULL);
	UniChar *dataPtr = (UniChar *)malloc(dataSize);
	err = GetEventParameter(theEvent, kEventParamTextInputSendText, typeUnicodeText, NULL, dataSize, NULL, dataPtr);
	NSString *aString =[[NSString alloc] initWithBytes:dataPtr length:dataSize encoding:NSUnicodeStringEncoding];
	//NSLog([NSString stringWithFormat:@"aString : %@", aString]);
	[(id)userData insertTextInputSendText:aString];
	free(dataPtr);
#if useLog	
	NSLog(@"end appLaunched");
#endif
	return(CallNextEventHandler(nextHandler, theEvent));
}
*/

- (void)allWillLaunch:(NSNotification *)notification
{
	NSLog(@"allWillLaunch");
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	windowController = [[FileTreeWindowController alloc] initWithWindowNibName:@"FileTreeWindow"];
	[windowController showWindow:self];

/*	
	EventTypeSpec spec = { kEventClassApplication, kEventAppLaunchNotification };
	EventTypeSpec spec = { kEventClassApplication, kEventAppLaunched };
	EventHandlerUPP handlerUPP = NewEventHandlerUPP(appLaunched);
	OSStatus err = InstallApplicationEventHandler(handlerUPP, 1, &spec, (void*)self, NULL);
	DisposeEventHandlerUPP(handlerUPP);
	if (err != noErr) {
		NSLog(@"fail to InstallApplicationEventHandler");
		return;
	}
*/

}

@end
