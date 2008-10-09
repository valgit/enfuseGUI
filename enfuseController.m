
/* we need imageio */
#ifndef GNUSTEP
#import <ApplicationServices/ApplicationServices.h>
#import "NSImage+GTImageConversion.h"
#else
#import "NSImage-ProportionalScaling.h"
#endif
#import "enfuseController.h"


#include <math.h>

// Categories : private methods
@interface enfuseController (Private)
#ifndef GNUSTEP
- (NSImage*) createThumbnail:(CGImageSourceRef)imsource;
#endif
-(void)copyExifFrom:(NSString*)sourcePath to:(NSString*)outputfile with:(NSString*)tempfile;
-(NSString*)previewfilename:(NSString *)file;

@end

@implementation enfuseController

#pragma mark -
#pragma mark init & dealloc

+ (void)initialize
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		@"YES", @"useCIECAM",
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
		[NSApp terminate:nil];
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
	
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//NSLog(@"ICC aware ? %d",[defaults boolForKey:@"useCIECAM"]); // ICC profile
																   // int cachesize = [defaults intForKey:@"cachesize"]; // def 1024
																   // int blocksize = [defaults intForKey:@"blocksize"]; // def 2048
#ifndef GNUSTEP
	myBadge = [[CTProgressBadge alloc] init];
	[self reset:mResetButton];
#endif
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

// return a somewhat globally unique filename ...
// 
-(NSString*)tempfilename:(NSString *)format;
{
      NSString *tempFilename = NSTemporaryDirectory();
      NSString *tempString = [[NSProcessInfo processInfo] globallyUniqueString];
      tempFilename = [tempFilename stringByAppendingPathComponent:tempString];
      return [[NSString stringWithFormat:@"%@.%@",tempFilename,format] retain];
}

// saving ?
- (NSData *) dataOfType: (NSString *) typeName
{

    NSMutableData *data = [[NSMutableData alloc] init];

    NSKeyedArchiver *archiver;
    archiver = [[NSKeyedArchiver alloc]
                   initForWritingWithMutableData: data];
    [archiver setOutputFormat: NSPropertyListXMLFormat_v1_0];

    [archiver encodeDouble: [mContrastSlider doubleValue]  forKey: @"contrast"];
    [archiver encodeDouble: [mExposureSlider doubleValue]  forKey: @"exposure"];
    [archiver encodeDouble: [mSaturationSlider doubleValue]  forKey: @"saturation"];

    [archiver encodeDouble: [mMuSlider doubleValue]  forKey: @"mu"];
    [archiver encodeDouble: [mSigmaSlider doubleValue]  forKey: @"sigma"];

    [archiver encodeDouble: [mContrastWindowSizeTextField doubleValue]  forKey: @"windowsize"];
    [archiver encodeDouble: [mMinCurvatureTextField doubleValue]  forKey: @"mincurvature"];

    [archiver finishEncoding];

    return ([data autorelease]);

} 

- (BOOL) readFromData: (NSData *) data
              ofType: (NSString *) typeName
{
    NSKeyedUnarchiver *archiver;
    archiver = [[NSKeyedUnarchiver alloc]
                   initForReadingWithData: data];

    //stitches = [archiver decodeObjectForKey: @"stitches"];

    return (YES);

} 

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo {
	NSLog(@"error: %@", errorInfo);
	int result;
        result = NSRunAlertPanel([[NSProcessInfo processInfo] processName],
                @"file operation error",@"Continue", @"Cancel", NULL,
                [errorInfo objectForKey:@"Error"],
                [errorInfo objectForKey:@"Path"]);

        if (result == NSAlertDefaultReturn)
                return YES;
        else
                return NO;
}


- (void) applicationWillTerminate: (NSNotification *)note 
{ 
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSLog(@"%s",__PRETTY_FUNCTION__);
	//NSData* data = [self dataOfType:@"xml"];
	//[data writeToFile:@"/tmp/test.xml" atomically:YES ];
		NSDictionary* obj=nil;
	NSEnumerator *enumerator = [images objectEnumerator];
	
	while ( nil != (obj = [enumerator nextObject]) ) {
		//NSLog(@"removing : %@",[obj valueForKey:@"thumbfile"]);		
		[defaultManager removeFileAtPath:[obj valueForKey:@"thumbfile"] handler:self];
	}	
	// [self saveSettings];
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
	//NSLog(@"%s icount: %d",__PRETTY_FUNCTION__,[images count]);
	
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
		   
		   [self setOutputfile:outputfile];
		   [self setTempfile:[self tempfilename:[[mOutFormat titleOfSelectedItem] lowercaseString]]];
		   NSLog(@"files are : (%@) %@,%@",outputfile,[self outputfile],[self tempfile]);

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
		   //NSLog(@"icc : %@",[defaults boolForKey:@"useCIECAM02"]);
		   if ([defaults boolForKey:@"useCIECAM"]) { // ICC profile
			   NSLog(@"%s use ICC !",__PRETTY_FUNCTION__);
			   //[args addObject:@"-c"];
		   }
		   
		   [args addObject:@"-o"];
		   [args addObject:[self tempfile]];
		   
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
		   
		   [mProgressIndicator setDoubleValue:0.0];
		   [mProgressIndicator setMaxValue:(1+4*[images count])];
		
		   enfuseTask=[[TaskWrapper alloc] initWithController:self arguments:args];
		   // kick off the process asynchronously
		   int status = [enfuseTask startProcess];
		   if (status != 0) {
			NSRunAlertPanel (NULL, @"running error", @"OK", NULL, NULL);
		   }
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
	
	[mMuSlider setFloatValue:0.5]; // mu (0 <= MEAN <= 1).  Default: 0.5
	[self takeMu:mMuSlider];
	
	[mSigmaSlider setFloatValue:0.2]; // sigma (SIGMA > 0).  Default: 0.2
	[self takeSigma:mSigmaSlider];
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

- (IBAction) openPresets: (IBOutlet)sender;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
}

- (IBAction) savePresets: (IBOutlet)sender;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	NSData* data = [self dataOfType:@"xml"];
	[data writeToFile:@"/tmp/test.xml" atomically:YES ];
}

#pragma mark -
#pragma mark TaskWrapper

// This callback is implemented as part of conforming to the ProcessController protocol.
// It will be called whenever there is output from the TaskWrapper.
- (void)appendOutput:(NSString *)output
{
    // add the string (a chunk of the results from locate) to the NSTextView's
    // backing store, in the form of an attributed string
    NSLog(@"%d output is : [%@]",value, output);
	[mProgressIndicator incrementBy:1.0];
#ifndef GNUSTEP
	[myBadge badgeApplicationDockIconWithProgress:((360*value)/(1+4*[images count])) insetX:2 y:3];
#endif
	value+=1;
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
	[mProgressIndicator startAnimation:self];
	value = 0;
}

// A callback that gets called when a TaskWrapper is completed, allowing us to do any cleanup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processFinished:(int)status
{
    [mProgressIndicator stopAnimation:self];
    [mProgressIndicator setDoubleValue:0];
	
    findRunning=NO;
    // change the button's title back for the next search
    //[mEnfuseButton setTitle:@"Enfuse"];
    [mEnfuseButton setEnabled:YES];

    if (status == 0) {	
    if([mCopyMeta state]==NSOnState)  {
		[self copyExifFrom:[[images objectAtIndex:0] valueForKey:@"file"] to:[self outputfile] with:[self tempfile]];
    } else {
		NSFileManager *fm = [NSFileManager defaultManager];
		if ([fm fileExistsAtPath:([self tempfile])]){
			BOOL result = [fm movePath:[self tempfile] toPath:[self outputfile] handler:nil];
		} else {
			NSString *alert = [[self tempfile] stringByAppendingString: @" do not exist!\nCan't rename"];
			NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
		}
    }
	
    [self openFile:[self outputfile]];
    } else {
	NSLog(@"%s task error=%d",__PRETTY_FUNCTION__,status);
	NSRunAlertPanel (NULL, @"running error", @"OK", NULL, NULL);
    }
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
	//return [images count];
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
		
		NSImage* image;
		NSString *text;
#ifdef GNUSTEP
		// create and configure a new Image
		image =[[NSImage alloc] initWithContentsOfFile:fileName];
		// create a meaning full info ...

		NSBitmapImageRep *rep =[image bestRepresentationForDevice:nil];
		NSMutableDictionary *exifDict =  [rep valueForProperty:@"NSImageEXIFData"];
#else
		
		CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:fileName], NULL);
		if(source != nil) {
			NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
				(id)kCFBooleanTrue, (id)kCGImageSourceShouldCache,
				(id)kCFBooleanTrue, (id)kCGImageSourceShouldAllowFloat,
				NULL];
			
			// get Exif from source?
			NSDictionary* properties =  (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, (CFDictionaryRef)options);
			//NSLog(@"props: %@", [properties description]);
			NSDictionary *exif = [properties objectForKey:(NSString *)kCGImagePropertyExifDictionary];
			if(exif) { /* kCGImagePropertyIPTCDictionary kCGImagePropertyExifAuxDictionary */
				NSString *focalLengthStr, *fNumberStr, *exposureTimeStr,*exposureBiasStr;
				//NSLog(@"the exif data is: %@", [exif description]);
				NSNumber *focalLengthObj = [exif objectForKey:(NSString *)kCGImagePropertyExifFocalLength];
				if (focalLengthObj) {
					focalLengthStr = [NSString stringWithFormat:@"%@mm", [focalLengthObj stringValue]];
				}
				NSNumber *fNumberObj = [exif objectForKey:(NSString *)kCGImagePropertyExifFNumber];
				if (fNumberObj) {
					fNumberStr = [NSString stringWithFormat:@"F%@", [fNumberObj stringValue]];
				}
				NSNumber *exposureTimeObj = (NSNumber *)[exif objectForKey:(NSString *)kCGImagePropertyExifExposureTime];
				if (exposureTimeObj) {
					exposureTimeStr = [NSString stringWithFormat:@"1/%.0f", (1/[exposureTimeObj floatValue])];
				}
				NSNumber *exposureBiasObj = (NSNumber *)[exif objectForKey:(NSString *)kCGImagePropertyExifExposureBiasValue];
				if (exposureBiasObj) {
					exposureBiasStr = [NSString stringWithFormat:@"Bias:%@", [exposureBiasObj stringValue]];
				}
				
				text = [NSString stringWithFormat:@"%@\n%@ / %@ @ %@ bias : %@", [fileName lastPathComponent],
					focalLengthStr,exposureTimeStr,fNumberStr,exposureBiasObj];
			} /* kCGImagePropertyExifFocalLength kCGImagePropertyExifExposureTime kCGImagePropertyExifExposureTime */
			image = [self createThumbnail:source];
			CFRelease(source);
			CFRelease(properties);
		} else {
			text = [fileName lastPathComponent];
		}        
#endif
#ifdef GNUSTEP		
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
#endif
		
		NSData *thumbData = [image  TIFFRepresentation];
		NSString *thumbname = [self previewfilename:[fileName lastPathComponent]];
		[thumbData writeToFile:thumbname atomically:YES];
		
		NSNumber *enable = [NSNumber numberWithBool: YES];
		// [NSString stringWithFormat: 
		NSMutableDictionary *newImage = [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",fileName,@"file",text,@"text",image,@"thumb",thumbname,@"thumbfile",nil]; 
#ifdef GNUSTEP
		[images addObject:newImage];
		[mTableImage reloadData];
        	//[mTableImage scrollRowToVisible:[mTableImage numberOfRows]-1];

#else
		[mImageArrayCtrl addObject:newImage];
#endif
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

-(NSString*)tempfile;
{
	return _tmpfile;
}

-(void)setTempfile:(NSString *)file;
{
	if (_tmpfile != file) {
		[_tmpfile release];
        _tmpfile = [file copy];
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

@implementation enfuseController (Private)

// return a somewhat globally unique filename ...
// 
-(NSString*)previewfilename:(NSString *)file
{
      NSString *tempFilename = NSTemporaryDirectory();
    
      return [[NSString stringWithFormat:@"%@/thumb_%@",tempFilename,file] retain];
}

#ifndef GNUSTEP
// create a thumbnail using imageio framework
- (NSImage*) createThumbnail:(CGImageSourceRef)imsource
{
	CGImageRef _thumbnail = nil;
	
	if (imsource) {		
		// Ask ImageIO to create a thumbnail from the file's image data, if it can't find a suitable existing thumbnail image in the file.  
		// We could comment out the following line if only existing thumbnails were desired for some reason
		//  (maybe to favor performance over being guaranteed a complete set of thumbnails).
		NSDictionary* thumbOpts = [NSDictionary dictionaryWithObjectsAndKeys:
			(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
			(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageIfAbsent, // kCGImageSourceCreateThumbnailFromImageAlways
			[NSNumber numberWithInt:160], (id)kCGImageSourceThumbnailMaxPixelSize, 
			nil];
		
		// make image thumbnail
		_thumbnail = CGImageSourceCreateThumbnailAtIndex(imsource, 0, (CFDictionaryRef)thumbOpts);
		//NSImage *image = [[NSImage alloc] initWithCGImage:_thumbnail];
		NSImage *image = [NSImage gt_imageWithCGImage:_thumbnail];	
		
	
	
		CFRelease(_thumbnail);
		return image;
	}
	return NULL;
}
#endif

-(void)copyExifFrom:(NSString*)sourcePath to:(NSString*)outputfile with:(NSString*)tempfile;
{
	NSMutableDictionary* newExif;
	NSLog(@"%s",__PRETTY_FUNCTION__);
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#ifndef GNUSTEP
	
	// create the source 
	NSURL *_url = [NSURL fileURLWithPath:sourcePath]; // for exif
	NSURL *_outurl = [NSURL fileURLWithPath:outputfile]; // dest
	NSURL *_tmpurl = [NSURL fileURLWithPath:tempfile]; // for image
	CGImageSourceRef exifsrc = CGImageSourceCreateWithURL((CFURLRef)_url, NULL);
	CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)_tmpurl, NULL);
	if(source != nil) {
		// get Exif from source?
		NSDictionary* properties = (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(exifsrc, 0, NULL);
		//NSLog(@"props: %@", [(NSDictionary *)properties description]);
		NSDictionary *exif = (NSDictionary *)[properties objectForKey:(NSString *)kCGImagePropertyExifDictionary];
		if(exif) { /* kCGImagePropertyIPTCDictionary kCGImagePropertyExifAuxDictionary */
			//NSLog(@"the exif data is: %@", [exif description]);
			newExif = [NSMutableDictionary dictionaryWithDictionary:exif];

			if ([mCopyShutter state]==NSOnState) {
				NSLog(@"%s removing shutter speed",__PRETTY_FUNCTION__);
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifExposureTime];
			}
			if ([mCopyAperture state]==NSOnState) {
				NSLog(@"%s removing aperture",__PRETTY_FUNCTION__);
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifFNumber];
			}
			if ([mCopyFocal state]==NSOnState) {
				NSLog(@"%s removing focal length",__PRETTY_FUNCTION__);
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifFocalLength];
			}
		} /* kCGImagePropertyExifFocalLength kCGImagePropertyExifExposureTime kCGImagePropertyExifExposureTime */
		
		// create the destination
		CGImageDestinationRef destination = CGImageDestinationCreateWithURL((CFURLRef)_outurl,
				CGImageSourceGetType(source),
				CGImageSourceGetCount(source),
				NULL);
	
		//CGImageDestinationSetProperties(destination, (CFDictionaryRef)exif);	
		

		// copy data from temporary image ...
		int imageCount = CGImageSourceGetCount(source);
		int i;
		for (i = 0; i < imageCount; i++) {
				//NSLog(@"imgs  : %d",i);
				CGImageDestinationAddImageFromSource(destination,
						     source,
						     i,
						     (CFDictionaryRef)newExif);
		}
    
		CGImageDestinationFinalize(destination);
    
		CFRelease(destination);
		CFRelease(source); 
		CFRelease(properties);
		CFRelease(exifsrc); 
	} else {
		NSRunInformationalAlertPanel(@"Copying Exif error!",
									 @"Unable to add Exif to Image.",
									 @"OK",
									 nil,
									 nil,
									 nil);
	}
	NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:(tempfile)]){
		[fm removeFileAtPath:tempfile handler:self];
	}
#else
	NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:(tempfile)]){
              BOOL result = [fm movePath:tempfile toPath:outputfile handler:nil];
        } else {
              NSString *alert = [tempfile stringByAppendingString: @" do not exist!\nCan't rename"];
              NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
        }
#endif
	[pool release];
}


@end
