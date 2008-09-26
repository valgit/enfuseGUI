#import "enfuseController.h"

#include <math.h>

@implementation enfuseController

#pragma mark -
#pragma mark init & dealloc

+ (void)initialize
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		@"YES", @"useCIECAM02",
		@"default", @"cachesize",
		@"default", @"blocksize",
		nil];
	
    [defaults registerDefaults:appDefaults];
}


// when first launched, this routine is called when all objects are created
// and initialized.  It's a chance for us to set things up before the user gets
// control of the UI.
-(void)awakeFromNib
{
    findRunning=NO;
    enfuseTask=nil;
#if 0
	NSString *path = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] bundlePath],
		/*@"/greycstoration.app/Contents/MacOS/greycstoration"*/
		@"/enfuse/enfuse"];
	
	// check for enfuse binaries...
	if([[NSFileManager defaultManager] isExecutableFileAtPath:path]==NO){
		NSString *alert = [path stringByAppendingString: @" is not executable!"];
		NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
#if 0
        [NSException raise:NSGenericException
					format:@"bad_find_binary:_%@", path];
#endif
	}
#endif
	
	[window center];
	[window makeKeyAndOrderFront:nil];
	
	// this allows us to declare which type of pasteboard types we support
	//[mTableImage setDataSource:self];
	[mTableImage setRowHeight:128]; // have some place ...
	[mTableImage registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,NSStringPboardType,NSURLPboardType,nil]];
	// theIconColumn = [table tableColumnWithIdentifier:@"icon"];
	// [ic setImageScaling:NSScaleProportionally]; // or NSScaleToFit
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSLog(@"ICC aware ? %d",[defaults boolForKey:@"useCIECAM02"]); // ICC profile
																   // int cachesize = [defaults intForKey:@"cachesize"]; // def 1024
																   // int blocksize = [defaults intForKey:@"blocksize"]; // def 2048
}

- (id)init
{
	if ( ! [super init])
        return nil;
	
	images = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)dealloc
{
	[images release];
    [super dealloc];
}


- (NSString *)nextUniqueNameUsing:(NSString *)templatier withFormat:(NSString *)format appending:(NSString *)append
{
    static int unique = 1;
    NSString *tempName = nil;
	
    if ([format isEqualToString:@""])
		format = [templatier pathExtension];
	
    NSLog(@"format is : %@",format);
	
    tempName =[NSString stringWithFormat:@"%@%@.%@",
		[templatier stringByDeletingPathExtension],append,
		//[templatier pathExtension]];
		format];
		if ([[NSFileManager defaultManager] fileExistsAtPath:tempName]) {
			do {
				tempName =[NSString stringWithFormat:@"%@%@_%d.%@",
					[templatier stringByDeletingPathExtension],append,unique++,
					//[templatier pathExtension]];
					format];
            } while ([[NSFileManager defaultManager] fileExistsAtPath:tempName]);
    }
		return tempName;
}

-(void)openFile:(NSString *)file
{
	NSWorkspace *wm = [NSWorkspace sharedWorkspace];
	NSLog(@"%s tag: %d file : %@",__PRETTY_FUNCTION__,[[mDoAfter selectedCell] tag],file);
	switch ([[mDoAfter selectedCell] tag]) {
		case 0 :
			[wm openFile:file withApplication:@"Photoshop" andDeactivate:YES];
			break;
		case 1 :
			[wm openFile:file];
			break;
		default :
			// do nothing
			break;
    }
}

#pragma mark -
#pragma mark table binding 

//speak well !	
-(NSString *)pluralImagesToProcess;
{
	return ([images count] <= 1)? @"" : @"s";
}

// KVC compliant for array
- (unsigned)countOfImages
{
	NSLog(@"%s icount: %d",__PRETTY_FUNCTION__,[images count]);
	
	return [images count];
}

// minimum ...
// KVC compliant for array
-(NSDictionary *)objectInImagesAtIndex:(unsigned)index
{
#if 0
	NSImage* image;
	NSString *text;
	NSNumber *enable = [NSNumber numberWithBool: YES];
	
	NSLog(@"%s for: %d",__PRETTY_FUNCTION__,index);
	// TODO : better check for null ...
	image = nil;
	if ( nil == image) {
		NSLog(@"%s : can't get thumbnail",__PRETTY_FUNCTION__);
	}
	// TODO : grab real value !
	text = [[@"test"  retain ] autorelease];
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",text,@"text",image,@"thumb",nil];  
#else
	return [images objectAtIndex:index];
#endif
}

// 
-(void)insertObject:(id)obj inImagesAtIndex:(unsigned)index;
{
	NSLog(@"%s obj is : %@",__PRETTY_FUNCTION__,obj);
	[images insertObject: obj  atIndex: index];
}

-(void)removeObjectFromImagesAtIndex:(unsigned)index;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	[images removeObjectAtIndex: index];
}

-(void)replaceObjectInImagesAtIndex:(unsigned)index withObject:(id)obj;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	[images replaceObjectAtIndex: index withObject: obj];
}

/*
 * note to react at selection change :
 * [searchArrayController addObserver: self
                           forKeyPath: @"selectionIndexes"
							  options: NSKeyValueObservingOptionNew
							  context: NULL];
 
 * and use observeValueForKeyPath:						   
 */

#pragma mark -
#pragma mark drag drop from finder ?

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	// [tv setDropRow: -1 dropOperation:NSTableViewDropOn];
    //return NSDragOperationMove;
	
	if( [info draggingSource] == mTableImage )
	{
		/*if( operation == NSTableViewDropOn )
		[tv setDropRow:row dropOperation:NSTableViewDropAbove];
		*/
		/* if ((row==0)&&(operation==NSTableViewDropOn)) {
		[tv setDropRow:0 dropOperation:NSTableViewDropAbove];
		}*/
		return NSDragOperationEvery;
	} else 	{
		return NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	NSPasteboard *pasteboard = [info draggingPasteboard];
	if ( [[pasteboard types] containsObject:NSFilenamesPboardType] ) {
		//NSWorkspace* workspace = [NSWorkspace sharedWorkspace];
		NSArray * fileArray = [pasteboard propertyListForType: NSFilenamesPboardType];
		unsigned fileArrayCount = [fileArray count];
		if ( fileArray == nil || fileArrayCount < 1 ) return NO;
		
		//NSArray *allItemsArray = [itemsArrayController arrangedObjects];
		//NSMutableArray *draggedItemsArray = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
		
		// create and configure a new Image
		NSString *sourcePath = [fileArray objectAtIndex:0];
		NSImage* image =[[NSImage alloc] initWithContentsOfFile:sourcePath];
		NSNumber *enable = [NSNumber numberWithBool: YES];
		
		NSMutableDictionary *newImage = [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",sourcePath,@"text",image,@"thumb",nil]; 
		[images insertObject:newImage atIndex:row];
		[newImage release];
		
	}
	
	return YES;
}

#pragma mark -
#pragma mark User Action

- (IBAction)cancel:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	if (findRunning) {
		[enfuseTask stopProcess];
		// Release the memory for this wrapper object
		[enfuseTask release];
		enfuseTask=nil;
	}
	[mEnfuseButton setEnabled:YES];
	
}

- (IBAction)enfuse:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	
	   if (findRunning) {
		   NSLog(@"already running");
		   // This stops the task and calls our callback (-processFinished)
		   //[enfuseTask stopProcess];
		   // Release the memory for this wrapper object
		   //[enfuseTask release];
		   //enfuseTask=nil;
		   return;
	   } else {
		   // If the task is still sitting around from the last run, release it
		   if (enfuseTask!=nil)
			   [enfuseTask release];
		   // Let's allocate memory for and initialize a new TaskWrapper object, passing
		   // in ourselves as the controller for this TaskWrapper object, the path
		   // to the command-line tool, and the contents of the text field that
		   // displays what the user wants to search on
		   NSMutableArray *args = [NSMutableArray array];
		   
		   NSString *filename = @""; // TODO [[mInputFile stringValue] lastPathComponent];
									 //NSString *extension = [[filename pathExtension] lowercaseString];
									 //NSLog(filename);
		   NSString* outputfile;
		   
		   switch ([[mOutputType selectedCell] tag]) {
			   case 0 : /* absolute */
				   outputfile = [[mOuputFile stringValue]
                                      stringByAppendingPathComponent:[self nextUniqueNameUsing:[mOutFile stringValue]
																					withFormat:[[mOutFormat titleOfSelectedItem] lowercaseString]
																					 appending:[mAppendTo stringValue] ]];
				   break;
			   case 1: /* append */
				   outputfile = [[mOuputFile stringValue]
	                                stringByAppendingPathComponent:[self nextUniqueNameUsing:filename
																				  withFormat:[[mOutFormat titleOfSelectedItem] lowercaseString]
																				   appending:[mAppendTo stringValue] ]];
				   break;
			   default:
				   NSLog(@"bad selected tag is %d",[[mOutputType selectedCell] tag]);
		   }
		   
		   NSLog(outputfile);
		   [self setOutputfile:outputfile];
		   
#ifndef GNUSTEP
		   NSString *path = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] bundlePath],
			   @"/enfuse/enfuse"];
		   //[[ NSBundle mainBundle ] pathForAuxiliaryExecutable: @"greycstoration"];
		   //NSLog(@"path is %@ -> %@",path,[[ NSBundle mainBundle ] bundlePath]);
		   //[args addObject:[ [ NSBundle mainBundle ] pathForAuxiliaryExecutable: @"greycstoration" ]];
		   [args addObject:path];
		   //[args addObject:@"/Users/vbr/Source/CImg-1.2.9/examples/greycstoration"];
		   // NSString *pathToFfmpeg = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],@"/ffmpeg"];
#else
		   [args addObject:@"./enfuse"];
#endif
		   // for debug ? [args addObject:@"-v"]; // be a little bit verbose ?
		   
		   //[args addObject:@"greycstoration"];
		   NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		   if ([defaults boolForKey:@"useCIECAM02"]) { // ICC profile
			   [args addObject:@"-c"];
		   }
		   
		   [args addObject:@"-o"];
		   [args addObject:outputfile];
		   
		   //[args addObject:@"-restore"];
#if 0
		   [args addObject:@"dsc_0EV.tif"];
	       [args addObject:@"dsc_-2EV.tif"];
		   [args addObject:@"dsc_+2EV.tif"];
#else	
		   //[args addObject:[mInputFile stringValue]];
		   NSDictionary* obj=nil;
		   NSEnumerator *enumerator = [images objectEnumerator];
		   
		   while ( nil != (obj = [enumerator nextObject]) ) {
			   if ([[obj valueForKey:@"enable"] boolValue]){
				   //NSLog(@"add enable : %@",[obj valueForKey:@"text"]);
				   [args addObject:[obj valueForKey:@"file"]]; // TODO : better !
			   }
		   }
		   
#endif
		   
		   //NSLog(@"info jpeg : %@",[mOutQuality stringValue]);
		   if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"JPEG"] ) {
			   [args addObject:[NSString stringWithFormat:@"--compression=%@",[mOutQuality stringValue]]];
		   } else if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"TIFF"] ) {
			   [args addObject:@"--compression=LZW"]; // if jpeg !
		   }
		   
		   [args addObject:[NSString stringWithFormat:@"--wExposure=%@",[mExposureSlider stringValue]]];
		   [args addObject:[NSString stringWithFormat:@"--wSaturation=%@",[mSaturationSlider stringValue]]];
		   [args addObject:[NSString stringWithFormat:@"--wContrast=%@",[mContrastSlider stringValue]]];
		   
		   [args addObject:[NSString stringWithFormat:@"--wMu=%@",[mMuSlider stringValue]]];
		   [args addObject:[NSString stringWithFormat:@"--wSigma=%@",[mSigmaSlider stringValue]]];
		   
		   enfuseTask=[[TaskWrapper alloc] initWithController:self arguments:args];
		   // kick off the process asynchronously
		   [enfuseTask startProcess];
	   }
	   
	   
}

- (IBAction)reset:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	
	[mContrastSlider setFloatValue:0.0]; // (0 <= WEIGHT <= 1).  Default: 0
	[self takeContrast:mContrastSlider];
	
	[mExposureSlider setFloatValue:1.0]; // 0 <= WEIGHT <= 1).  Default: 1
	[self takeExposure:mExposureSlider];
	
	[mSaturationSlider setFloatValue:0.2]; // (0 <= WEIGHT <= 1).  Default: 0.2
	[self takeSaturation:mSaturationSlider];
	
	// mu (0 <= MEAN <= 1).  Default: 0.5
	// sigma (SIGMA > 0).  Default: 0.2
}

- (IBAction) about: (IBOutlet)sender;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
}

- (IBAction) chooseOutputDirectory: (IBOutlet)sender;
{
	// Create the File Open Panel class.
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
	
	[oPanel setCanChooseDirectories:YES];
	[oPanel setCanChooseFiles:NO];
	[oPanel setCanCreateDirectories:YES];
	[oPanel setAllowsMultipleSelection:NO];
	[oPanel setAlphaValue:0.95];
	[oPanel setTitle:@"Select a directory for output"];
	
	// Display the dialog.  If the OK button was pressed,
	// process the files.
	//      if ( [oPanel runModalForDirectory:nil file:nil types:fileTypes]
	if ( [oPanel runModalForDirectory:nil file:nil types:nil]
		 == NSOKButton )
	{
		// Get an array containing the full filenames of all
		// files and directories selected.
		NSArray* files = [oPanel filenames];
		
		NSString* fileName = [files objectAtIndex:0];
		NSLog(fileName);
		[mOuputFile setStringValue:fileName];
		
	}
	
}

- (IBAction) takeSaturation: (IBOutlet)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mSaturationTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mSaturationSlider setFloatValue:theValue];
}

- (IBAction) quit: (IBOutlet)sender;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
}

- (IBAction) takeContrast: (IBOutlet)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mContrastTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mContrastSlider setFloatValue:theValue];
}

- (IBAction) takeExposure: (IBOutlet)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mExposureTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mExposureSlider setFloatValue:theValue];
}

- (IBAction) takeSigma: (IBOutlet)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mSigmaTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mSigmaSlider setFloatValue:theValue];
}

- (IBAction) takeMu: (IBOutlet)sender;
{
	//NSLog(@"%s",__PRETTY_FUNCTION__);
	float theValue = [sender floatValue];
	[mMuTextField setFloatValue:theValue];
	//[mStrengthStepper setFloatValue:theValue];
	[mMuSlider setFloatValue:theValue];
}


#pragma mark -
#pragma mark TaskWrapper

// This callback is implemented as part of conforming to the ProcessController protocol.
// It will be called whenever there is output from the TaskWrapper.
- (void)appendOutput:(NSString *)output
{
    // add the string (a chunk of the results from locate) to the NSTextView's
    // backing store, in the form of an attributed string
    NSLog(@"output is : [%@]",output);
	// TODO        [mProgress incrementBy:1.0];
    //[[resultsTextField textStorage] appendAttributedString: [[[NSAttributedString alloc]
    //                         initWithString: output] autorelease]];
    // setup a selector to be called the next time through the event loop to scroll
    // the view to the just pasted text.  We don't want to scroll right now,
    // because of a bug in Mac OS X version 10.1 that causes scrolling in the context
    // of a text storage update to starve the app of events
    //[self performSelector:@selector(scrollToVisible:) withObject:nil afterDelay:0.0];
}

// A callback that gets called when a TaskWrapper is launched, allowing us to do any setup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processStarted
{
    findRunning=YES;
    // clear the results
    //[resultsTextField setString:@""];
    // change the "Sleuth" button to say "Stop"
    //[mRestoreButton setTitle:@"Stop"];
    [mEnfuseButton setEnabled:NO];
	// TODO  [mProgress startAnimation:self];
}

// A callback that gets called when a TaskWrapper is completed, allowing us to do any cleanup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processFinished
{
    // TODO    [mProgress stopAnimation:self];
    // TODO    [mProgress setDoubleValue:0];
	
    findRunning=NO;
    // change the button's title back for the next search
    //[mEnfuseButton setTitle:@"Enfuse"];
    [mEnfuseButton setEnabled:YES];
	
    if([mCopyMeta state]==NSOnState)  {
		NSLog(@"%s : copying Exif",__PRETTY_FUNCTION__);
		
    }
	
    [self openFile:[self outputfile]];
}

// If the user closes the search window, let's just quit
-(BOOL)windowShouldClose:(id)sender
{
    if (findRunning == YES) {
		[enfuseTask stopProcess];
		// Release the memory for this wrapper object
		[enfuseTask release];
		enfuseTask=nil;
    }
	
    [NSApp terminate:nil];
    return YES;
}

#pragma mark -
#pragma mark tableview delegate

//
// tableview delegate and datasources ...
//

// return the number of row int the table
- (int)numberOfRowsInTableView: (NSTableView *)aTable
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	// TODO return [images count];
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	// TODO return [[images objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
	return nil;
}

// use a delegate do watch the selection ...
- (void)tableViewSelectionDidChange:
	(NSNotification *)aNotification
{
	int row = [mTableImage selectedRow];
	if (row >= 0)
	{
		// display info in the drawer ...
		NSLog(@"the user just clicked on row %d -> %@", row,
			  /* [[images objectAtIndex:row] objectForKey:@"name"] */ @"TODO" );
	}
}

// button action ...
- (IBAction)addImage:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	// Create the File Open Panel class.
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
	
	[oPanel setCanChooseDirectories:NO];
	[oPanel setCanChooseFiles:YES];
	[oPanel setCanCreateDirectories:YES];
	[oPanel setAllowsMultipleSelection:YES];
	[oPanel setAlphaValue:0.95];
	[oPanel setTitle:@"Select a image to add"];
	
	// Display the dialog.  If the OK button was pressed,
	// process the files.
	//      if ( [oPanel runModalForDirectory:nil file:nil types:fileTypes]
	if ( [oPanel runModalForDirectory:nil file:nil types:nil]
		 == NSOKButton )
	{
		// Get an array containing the full filenames of all
		// files and directories selected.
		NSArray* files = [oPanel filenames];
		
		unsigned fileArrayCount = [files count];
		int i;
		
		for(i=0;i<fileArrayCount;i++) {
		NSString* fileName = [files objectAtIndex:i];
		NSLog(fileName);
		
		// create and configure a new Image
		NSImage* image =[[NSImage alloc] initWithContentsOfFile:fileName];
		// create a meaning full info ...
		NSBitmapImageRep *rep =[image bestRepresentationForDevice:nil];
		NSMutableDictionary *exifDict =  [rep valueForProperty:@"NSImageEXIFData"];
		NSString *text;
		//NSLog(@"Exif Data in  %@", exifDict);
		// TODO better with ImageIO
		if (exifDict != nil) {
			NSNumber *expo = [exifDict valueForKey:@"ExposureTime"];
			NSString *speed;
			if (expo)
				speed = [NSString stringWithFormat:@"1/%.0f",ceil(1.0 / [expo doubleValue])];
			else
				speed = @"";
			
			text = [NSString stringWithFormat:@"%@\n%@ @ f/%@", [fileName lastPathComponent],
				speed,[exifDict valueForKey:@"FNumber"]];
		} else {
			text = [fileName lastPathComponent];
		}

		NSNumber *enable = [NSNumber numberWithBool: YES];
		// [NSString stringWithFormat: 
		NSMutableDictionary *newImage = [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",fileName,@"file",text,@"text",image,@"thumb",nil]; 
		//[images addObject:newImage];
		[mImageArrayCtrl addObject:newImage];
		//[newImage release]; // memory bug ?
		}
		
		
	}
	
	
}


#pragma mark -
#pragma mark TODO

//
// Temporary Directory stuff: useful code.
//

BOOL directoryOK(NSString *path)
{
    BOOL isDirectory;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory) {
        NSDictionary *dict = [NSDictionary dictionaryWithObject:
            [NSNumber numberWithUnsignedLong:0777]
														 forKey:NSFilePosixPermissions];
        if (![fileManager createDirectoryAtPath:path attributes:dict]) 
            return NO;
    }
    return YES;
}

NSString * existingPath(NSString *path)
{
    while (path && ![path isEqualToString:@""]
		   && ![[NSFileManager defaultManager] fileExistsAtPath:path])
        path = [path stringByDeletingLastPathComponent];
    return path;    
}

NSArray *directoriesToAdd(NSString *path, NSString *existing)
{
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:4];
    if (path != nil && existing != nil) {
        while (![path isEqualToString:existing]) {
            [a insertObject:[path lastPathComponent] atIndex:0];
            path = [path stringByDeletingLastPathComponent];
        }
    }
    return a;
}

// this will go up the path until it finds an existing directory
// and will add each subpath and return YES if succeeds, NO if fails:

- (BOOL)createWritableDirectory:(NSString *)path
{
    BOOL isDirectory;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path isDirectory:&isDirectory]
        && isDirectory && [fileManager isWritableFileAtPath:path])
        return YES; // no work to do
    else {
        NSString *existing = existingPath(path);
        NSArray *dirsToAdd = directoriesToAdd(path,existing);
        int i;
        BOOL good = YES;
        for (i = 0; i < [dirsToAdd count]; i++) {
            existing = [existing stringByAppendingPathComponent:
                [dirsToAdd objectAtIndex:i]];
            if (!directoryOK(existing)) {
                good = NO;
                break;
            }
        }
        return good;
    }
}

- (NSString *)temporaryDirectory
{
    NSString *tempDir =[[NSTemporaryDirectory() 
        stringByAppendingPathComponent:
        [[NSProcessInfo processInfo] processName]]
        stringByAppendingPathComponent:NSUserName()];
	
    if (! [self createWritableDirectory:tempDir]) {
        NSLog(@"Couldn't create %@, using %@",tempDir, 
			  NSTemporaryDirectory());
        tempDir = NSTemporaryDirectory();
    }
    return tempDir;
}

-(NSString*)outputfile;
{
	return _outputfile;
}

-(void)setOutputfile:(NSString *)file;
{
	if (_outputfile != file) {
		[_outputfile release];
        _outputfile = [file copy];
	}
}

- (IBAction)revealInFinder:(IBOutlet)sender {
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self outputfile] isDirectory:&isDir]) {
		if (isDir)
			[[NSWorkspace sharedWorkspace] selectFile:nil inFileViewerRootedAtPath:[self outputfile]];
		else
			[[NSWorkspace sharedWorkspace] selectFile:[self outputfile] inFileViewerRootedAtPath:nil];
    }
}

- (IBAction)openPreferences:(id)sender
{
	[[MyPrefsWindowController sharedPrefsWindowController] showWindow:nil];
	(void)sender;
}

#if 0
// read metadata ...
mMetadata = (CFMutableDictionaryRef)CGImageSourceCopyPropertiesAtIndex (source, 0, (CFDictionaryRef)options);
NSDictionary* exif = [(NSDictionary*)mMetadata objectForKey:@"{Exif}"];

// write metadata
NSMutableDictionary* newExif = [NSMutableDictionary dictionaryWithDictionary:[newMetadata objectForKey:@"{Exif}"]];

[newExif setObject:@"2001:01:01 11:53:07" forKey:@"DateTimeOriginal"];
[newExif setObject:@"This is a test" forKey:@"UserComment"];
[newMetadata setObject:newExif forKey:@"{Exif}"];

CGImageDestinationCreateWithURL((CFURLRef)absURL, (CFStringRef) typeName, 1, nil);
CGImageDestinationAddImage(dest, image, (CFDictionaryRef)newMetadata);

==== ref : http://developer.apple.com/documentation/GraphicsImaging/Reference/CGImageSource/Reference/reference.html#//apple_ref/doc/constant_group/kCGImagePropertyExifDictionary_Keys

CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)imageURL, NULL);
if(source != nil)
{
	NSDictionary *properties = (NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
	NSLog(@"props: %@", [properties description]);
	NSDictionary *exif = [properties objectForKey:@"{Exif}"];
	if(exif)
	{
		NSLog(@"the exif data is: %@", [exif description]);
	}   
}

sample at :
http://caffeinatedcocoa.com/blog/?p=7

#endif

@end
