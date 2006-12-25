#import "FileTreeView.h"
#import "FileTreeDataSource.h"
#import "NSOutlineView_Extensions.h"
#import "ImageAndTextCell.h"

#define useLog 0

@implementation FileTreeView

- (void) dealloc {
	[searchColumnIdentifier release];
	[super dealloc];
}

- (void)awakeFromNib
{
	isInstalledTextInputEvent = NO;
	isFindBegin = NO;
	isUsingInputWindow = NO;
	resetTimer = nil;  
	mainColumnID = @"displayName";
		
	NSTableColumn *column = [self tableColumnWithIdentifier:mainColumnID];
    ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
    [imageAndTextCell setEditable: YES];
    [column setDataCell:imageAndTextCell];
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint
								operation:(NSDragOperation)operation
{
#if useLog
	NSLog([NSString stringWithFormat:@"start draggedImage with operation %d",operation]);
#endif	
	[super draggedImage: anImage endedAt: aPoint operation: operation];
	if ( [self delegate] && 
			[[self delegate] respondsToSelector:
					@selector(fileTreeView:didEndDragOperation:)]) {
		[[self dataSource] fileTreeView:self didEndDragOperation:operation];
	}
}

#pragma mark accessors
- (void)setSearchColumnIdenteifier:(id)identifier
{
	[identifier retain];
	[searchColumnIdentifier release];
	searchColumnIdentifier = identifier;
}


#pragma mark keytype find
static OSStatus inputText(EventHandlerCallRef nextHandler, EventRef theEvent, void* userData)
{
#if useLog    
	NSLog(@"inputText");
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
	NSLog(@"end inputText");
#endif
	return(CallNextEventHandler(nextHandler, theEvent));
}

- (NSTimeInterval)findTimeoutInterval
{
    // from Dan Wood's 'Table Techniques Taught Tastefully', as pointed out by someone
    // on cocoadev.com
    
    // Timeout is two times the key repeat rate "InitialKeyRepeat" user default.
    // (converted from sixtieths of a second to seconds), but no more than two seconds.
    // This behavior is determined based on Inside Macintosh documentation on the List Manager.
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int keyThreshTicks = [defaults integerForKey:@"InitialKeyRepeat"]; // undocumented key.  Still valid in 10.3. 
    if (0 == keyThreshTicks)	// missing value in defaults?  Means user has never changed the default.
    {
        keyThreshTicks = 35;	// apparent default value. translates to 1.17 sec timeout.
    }
    
    return MIN(2.0/60.0*keyThreshTicks, 2.0);
}


BOOL isReturnOrEnterKeyEvent(NSEvent *keyEvent) {
	unsigned short key_code = [keyEvent keyCode];
	return ((key_code == 36) || (key_code == 76));
}


BOOL isEscapeKeyEvent(NSEvent *keyEvent) {
	unsigned short key_code = [keyEvent keyCode];
	return (key_code == 53);
}

BOOL shouldBeginFindForKeyEvent(NSEvent *keyEvent)
{
    if (([keyEvent modifierFlags] & (NSCommandKeyMask | NSControlKeyMask | NSFunctionKeyMask)) != 0) {
        return NO;
    }
    
	unsigned short key_code = [keyEvent keyCode];
	// if true, arrow key's event.
	if ((123 <= key_code) && (key_code <= 126)) {
		return NO;
	}
	
	//escape key
	if (isEscapeKeyEvent(keyEvent)) return NO;
	
	if (isReturnOrEnterKeyEvent(keyEvent)) return NO;
	
	//space and tab and newlines are ignored
	unichar character = [[keyEvent characters] characterAtIndex:0];
	if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:character]){
		return NO;
	}
    return YES;    
}

- (BOOL)canChangeSelection
{
    id delegate = [self delegate];
    
    if (   [self isKindOfClass:[NSOutlineView class]] 
           && [delegate respondsToSelector:@selector(selectionShouldChangeInOutlineView:)])
    {
        return [delegate selectionShouldChangeInOutlineView:(NSOutlineView *)self];
    }
    else if ([delegate respondsToSelector:@selector(selectionShouldChangeInTableView:)])
    {
        return [delegate selectionShouldChangeInTableView:self];
    }
    else
    {
        return YES;
    }    
}

- (void)resetFind:(NSTimer *)aTimer
{
#if useLog
	NSLog(@"start restFind");
#endif	
	if (!isUsingInputWindow) {
		isFindBegin = NO;
		RemoveEventHandler(textInputEventHandler);
		isInstalledTextInputEvent = NO;
		isUsingInputWindow = NO;
		[self stopResetTimer];
	}
}

- (void)stopResetTimer
{
#if useLog
	NSLog(@"stop startResetTimer");
#endif	
	if (resetTimer != nil) {
		[resetTimer invalidate];
		[resetTimer release];
		resetTimer = nil;
	}
}

- (void)startResetTimer
{
#if useLog
	NSLog(@"start startResetTimer");
#endif	
	if (resetTimer != nil) {
		[resetTimer release];
	}
	
	resetTimer = [NSTimer scheduledTimerWithTimeInterval:[self findTimeoutInterval]
							target:self selector:@selector(resetFind:)
							userInfo:nil repeats:YES];
	[resetTimer retain];
}

- (void)insertTextInputSendText:(NSString *)aString
{
	if (isUsingInputWindow) {
		[fieldEditor insertText:aString];
		[self findForString:[fieldEditor string] ];
	}
}

- (void)keyDown:(NSEvent *)keyEvent
{
#if useLog	
	NSLog([NSString stringWithFormat:@"start KeyDown with event : %@", [keyEvent description]]);
#endif	
	BOOL eatEvent = NO;
	if (searchColumnIdentifier == nil) goto bail;
 	if (![self canChangeSelection]) goto bail;
	
	BOOL shouldFindFlag = shouldBeginFindForKeyEvent(keyEvent);
	
	if (isFindBegin) {
		if (isUsingInputWindow) {
			if (! isEscapeKeyEvent(keyEvent)) eatEvent = YES;
		}
		else if (shouldFindFlag) {
			eatEvent = YES;
		}
	}
	else if (shouldFindFlag) {
		eatEvent = YES;
	}
	
bail:
	if (eatEvent) {
		#if useLog
		NSLog(@"eat key event");
		#endif
		[self stopResetTimer];
		fieldEditor = [[self window] fieldEditor:YES forObject:self];
		//[fieldEditor setDelegate:self];
		
		if (!isFindBegin) {
			[fieldEditor setString:@""];
			isFindBegin = YES;
		}

		if (!isInstalledTextInputEvent) {
			EventTypeSpec spec = { kEventClassTextInput, kEventTextInputUnicodeForKeyEvent };
			EventHandlerUPP handlerUPP = NewEventHandlerUPP(inputText);
			OSStatus err = InstallApplicationEventHandler(handlerUPP, 1, &spec, (void*)self, NULL);
			DisposeEventHandlerUPP(handlerUPP);
			if (err != noErr) {
				NSLog(@"fail to InstallApplicationEventHandler");
				return;
			}
			isInstalledTextInputEvent = YES;
		}
		
		NSString *before_string = [NSString stringWithString:[fieldEditor string]];
		#if useLog
		NSLog([NSString stringWithFormat:@"before String : %@", before_string]);
		#endif
		[fieldEditor interpretKeyEvents:[NSArray arrayWithObject:keyEvent]];
		NSString *after_string = [fieldEditor string];
		#if useLog
		NSLog([NSString stringWithFormat:@"after String : %@", after_string]);
		#endif
		isUsingInputWindow = [before_string isEqualToString:after_string];
		#if useLog
		printf("isUsingInputWindow : %d\n", isUsingInputWindow);
		#endif
		if (!isUsingInputWindow) {
			[self findForString:after_string ];
		}
		[self startResetTimer];
	}
	else {
		if (isFindBegin) {
			[self stopResetTimer];
			isFindBegin = NO;
		}
		[super keyDown:keyEvent];	
	}
}

- (void)findForString:(NSString *)aString {
	NSLog([NSString stringWithFormat:@"start findForString:%@", aString]);
	
	NSTableColumn *column = [self tableColumnWithIdentifier:searchColumnIdentifier];
	int nrows = [self numberOfRows];
	id dataSource = [self dataSource];
	for (int i = 0; i< nrows; i++) {
		id item = [self itemAtRow:i];
		id display_name = [dataSource outlineView:self objectValueForTableColumn:column byItem:item];
		if (NSOrderedSame == [display_name compare:aString options:NSCaseInsensitiveSearch range:NSMakeRange(0, [aString length])]) {
			NSLog(display_name);
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
			break;
		}
		
	}
}

#pragma mark actions 
- (BOOL)respondsToSelector:(SEL)aSelector
{
	if (aSelector == @selector(dupulicateSelection:))
		return ([self selectedRow] != -1);
		
	if (aSelector == @selector(renameSelection:))
		return ([[self selectedRowIndexes] count] == 1);

	if (aSelector == @selector(deleteSelection:))
		return ([self selectedRow] != -1);
		
	if (aSelector == @selector(revealSelection:))
		return ([self selectedRow] != -1);
	
	if (aSelector == @selector(openSelection:))
		return ([self selectedRow] != -1);
		
	return [[self class] instancesRespondToSelector:aSelector];
}

- (IBAction)makeFolder:(id)sender
{
	[[self dataSource] fileTreeView:self makeFolderAfter:[self selectedItem]];
}

- (IBAction)openSelection:(id)sender
{
	NSArray *selectedItems = [self allSelectedItems];
	NSArray *pathes = [selectedItems valueForKeyPath:@"nodeData.path"];
	NSEnumerator *enumerator = [pathes objectEnumerator];
	NSString *a_path;
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	while (a_path = [enumerator nextObject] ){
		[workspace openFile:a_path ];
	}
}

- (IBAction)revealSelection:(id)sender
{
	[[self dataSource] fileTreeView:self revealItems:[self allSelectedItems]];
}

- (IBAction)dupulicateSelection:(id)sender
{
	[[self dataSource] fileTreeView:self dupulicateItems:[self allSelectedItems]];
}

- (IBAction)deleteSelection:(id)sender
{
	[[self dataSource] fileTreeView:self deleteItems:[self allSelectedItems]];
	[self deselectAll:self];
}

- (IBAction)renameSelection:(id)sender
{
	//[[self dataSource] fileTreeView:self renameItems:[self allSelectedItems]];
	int selectedIndex = [self selectedRow];
	NSTableColumn *column = [self tableColumnWithIdentifier:mainColumnID];
	[column setEditable:YES];
	[self editColumn:[self columnWithIdentifier:mainColumnID] row:selectedIndex withEvent:nil select:YES];
}

#pragma mark methods for field editor
- (void)textDidEndEditing:(NSNotification *)aNotification
{	
#if useLog
	NSLog([NSString stringWithFormat:@"start textDidEndEditing with notification %@", 
							[aNotification description]]);
	NSLog([[aNotification object] string]);
#endif
	
	[[self dataSource] fileTreeView:self
		renameItem:[self selectedItem] intoName:[[aNotification object] string] ];

	if ([[[aNotification userInfo] objectForKey:@"NSTextMovement"] intValue] 
													== NSReturnTextMovement) {
		NSMutableDictionary *new_user_info = [NSMutableDictionary dictionaryWithDictionary:
																	[aNotification userInfo]];
		[new_user_info setObject:[NSNumber numberWithInt:NSIllegalTextMovement] 
															forKey:@"NSTextMovement"];
		NSNotification *new_notification = [NSNotification 
										notificationWithName:[aNotification name]
										object:[aNotification object]
										userInfo:new_user_info];
		[super textDidEndEditing:new_notification];
		[[self window] makeFirstResponder:self];
	}
	else {
		[super textDidEndEditing:aNotification];
	}
	NSTableColumn *column = [self tableColumnWithIdentifier:mainColumnID];
	[column setEditable:NO];
}

@end
