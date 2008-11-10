
/* we need imageio */
#ifndef GNUSTEP
#import <ApplicationServices/ApplicationServices.h>
#import "NSImage+GTImageConversion.h"
#else
#import "NSImage-ProportionalScaling.h"
#endif
#import "MLog.h"
#import "enfuseController.h"
#import "NSFileManager-Extensions.h"
#import "TaskProgressInfo.h"

#include <math.h>

// Categories : private methods
@interface enfuseController (Private)
#ifndef GNUSTEP
- (NSImage*) createThumbnail:(CGImageSourceRef)imsource;
#endif
-(void)copyExifFrom:(NSString*)sourcePath to:(NSString*)outputfile with:(NSString*)tempfile;
-(NSString*)previewfilename:(NSString *)file;

-(void)setDefaults;
-(void)getDefaults;

-(NSString *)initTempDirectory;

- (void) checkBeta;

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
    [self checkBeta];
	
    findRunning=NO;
    //enfuseTask=nil;
#if 1
	NSString *path = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],
		@"/align_image_stack"];
	
	// check for enfuse binaries...
	if([[NSFileManager defaultManager] isExecutableFileAtPath:path]==NO){
		NSString *alert = [path stringByAppendingString: @" is not executable!"];
		NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
		[NSApp terminate:nil];
	}
	
	path = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],
		@"/enfuse"];
	
	// check for enfuse binaries...
	if([[NSFileManager defaultManager] isExecutableFileAtPath:path]==NO){
		NSString *alert = [path stringByAppendingString: @" is not executable!"];
		NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
		[NSApp terminate:nil];
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
	[self getDefaults];
#endif
	//[self setTempPath:NSTemporaryDirectory()]; // TODO better
	[self setTempPath:[self initTempDirectory]];
}

- (id)init
{
	if ( ! [super init])
        return nil;
	
	images = [[NSMutableArray alloc] init];
	aligntask = nil;
	//options = [[exportOptions alloc] init];
	useroptions = [[NSMutableDictionary alloc] initWithCapacity:5];
	
	return self;
}

- (void)dealloc
{
	
	[images release];
	if (aligntask != nil)
		[aligntask release];
	
	if (enfusetask != nil)
		[enfusetask release];

	if (exportOptionsSheetController != nil)
		[exportOptionsSheetController release];
		
	if (useroptions != nil)
		[useroptions dealloc];
		
    [super dealloc];
}


- (NSString *)nextUniqueNameUsing:(NSString *)templatier withFormat:(NSString *)format appending:(NSString *)append
{
    static int unique = 1;
    NSString *tempName = nil;
	
    if ([format isEqualToString:@""])
		format = [templatier pathExtension];
	
    MLogString(1 ,@"format is %@",format);
	
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
	MLogString(1 ,@"tag: %d file : %@",[[mDoAfter selectedCell] tag],file);
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
	MLogString(1 ,@"error: %@", errorInfo);
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
	MLogString(1 ,@"");
	//NSData* data = [self dataOfType:@"xml"];
	//[data writeToFile:@"/tmp/test.xml" atomically:YES ];
		NSDictionary* obj=nil;
	NSEnumerator *enumerator = [images objectEnumerator];
	
	while ( nil != (obj = [enumerator nextObject]) ) {
		//NSLog(@"removing : %@",[obj valueForKey:@"thumbfile"]);		
		[defaultManager removeFileAtPath:[obj valueForKey:@"thumbfile"] handler:self];
	}	
	NSString *filename;
	enumerator = [[defaultManager directoryContentsAtPath: [self temppath] ] objectEnumerator];
		while (nil != (filename = [enumerator nextObject]) ) {
			//NSLog(@"file : %@",[filename lastPathComponent]);
			if ([[filename lastPathComponent] hasPrefix:@"align"]) {				
				[defaultManager removeFileAtPath:[NSString stringWithFormat:@"%@/%@",[self temppath],filename] handler:self];
			}
		}

	// remove tempdir ...
	[defaultManager removeFileAtPath:[self temppath] handler:self];
	// [self saveSettings];
	[self setDefaults];
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
	
	MLogString(1 ,@"for: %d",index);
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
	MLogString(1 ,@"obj is : %@",obj);
	[images insertObject: obj  atIndex: index];
}

-(void)removeObjectFromImagesAtIndex:(unsigned)index;
{
	MLogString(1 ,@"");
	[images removeObjectAtIndex: index];
}

-(void)replaceObjectInImagesAtIndex:(unsigned)index withObject:(id)obj;
{
	MLogString(1 ,@"");
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
	MLogString(1 ,@"");
	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	MLogString(1 ,@"");
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
	MLogString(1 ,@"");
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
	MLogString(1 ,@"");
	[ NSApp stopModal ];
	findRunning = NO;

#if 0
	if (findRunning) {
		//[enfuseTask stopProcess];
		// Release the memory for this wrapper object
		//[enfuseTask release];
		//enfuseTask=nil;
                //[enfuseTask cancelProcess];
		[mEnfuseButton setEnabled:YES];
		findRunning = NO;
	}
	if (enfusetask != nil) {
		NSLog(@"%s should cancel enfuse task !",__PRETTY_FUNCTION__);
		[enfusetask setCancel:YES];
	}
	if (aligntask != nil) {
		NSLog(@"%s should cancel aligning task !",__PRETTY_FUNCTION__);
		[aligntask setCancel:YES];
	}
#endif	
}

- (IBAction)enfuse:(id)sender
{
	MLogString(1 ,@"");	
	   if (findRunning) {
		   MLogString(1 ,@"already running, canceling");
		   // This stops the task and calls our callback (-processFinished)
		   //[enfuseTask stopProcess];
		   // Release the memory for this wrapper object
		   //[enfuseTask release];
		   //enfuseTask=nil;
		   findRunning = NO;
		   return;
	   } else {					   
		findRunning = YES;
			if (aligntask != nil) {
				MLogString(1 ,@"need to cleanup autoalign ?");
				[aligntask release];
				aligntask = nil;
			}
				
		   if ([mAutoalign state] == NSOnState) {
				MLogString(1 ,@"need to autoalign");
				aligntask = [[alignStackTask alloc] initWithPath:[self temppath]];
				[aligntask setGridSize:[mGridSize stringValue]];
				[aligntask setControlPoints:[mControlPoints stringValue]];

				NSDictionary* obj=nil;
				NSEnumerator *enumerator = [images objectEnumerator];
		   
				while ( nil != (obj = [enumerator nextObject]) ) {
					if ([[obj valueForKey:@"enable"] boolValue]){
						//NSLog(@"add enable : %@",[obj valueForKey:@"text"]);
						[aligntask addFile:[obj valueForKey:@"file"]]; // TODO : better !
					}
				}
				
				[mProgressIndicator setUsesThreadedAnimation:YES];
				//[mProgressIndicator setIndeterminate:YES];
				[mProgressIndicator setDoubleValue:0.0];
				[mProgressIndicator setMaxValue:(1+23*[images count])]; // TOTO : add enfuse step ?
				[mProgressIndicator startAnimation:self];
				[mProgressText setStringValue:@"Aligning..."];
				[aligntask setDelegate:self];
				[aligntask setProgress:mProgressIndicator]; // needed ?
				[NSThread detachNewThreadSelector:@selector(runAlign)
                         toTarget:aligntask
                       withObject:nil];
				//[mProgressIndicator stopAnimation:self];
				//[mProgressIndicator setIndeterminate:NO];
				// for now !
				//[mEnfuseButton setEnabled:NO];
	
				// show the progress sheet
			    [ NSApp beginSheet: mProgressPanel 
						modalForWindow: window modalDelegate: nil
						didEndSelector: nil contextInfo: nil ];
				[ NSApp runModalForWindow: mProgressPanel ];
				[ NSApp endSheet: mProgressPanel ];
				[ mProgressPanel orderOut: self ];
	
				[mEnfuseButton setTitle:@"Cancel"];
				return; // testing !
		   } else {
				MLogString(1 ,@"need to enfuse");
				[self doEnfuse];
		   }
			
		}
}

- (void)doEnfuse
{
	MLogString(1 ,@"");
	NSDictionary* file=nil;
	
	//
	// create the output file name 
	//
	file = [images objectAtIndex:0];
	NSString *filename = [[file valueForKey:@"file"] lastPathComponent ]; 
	
	// TODO [[mInputFile stringValue] lastPathComponent];
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
			MLogString(1 ,@"bad selected tag is %d",[[mOutputType selectedCell] tag]);
	}
	
	[self setOutputfile:outputfile];	
	
	// 
	// create the enfuse task
	if (enfusetask != nil) {
			MLogString(1 ,@"need to enfuse task");
				[enfusetask release];
				enfusetask = nil;
	}
	
	enfusetask = [[enfuseTask alloc] init];
	
	// temporary file for output
	[enfusetask setOutputfile:[self tempfilename:[[mOutFormat titleOfSelectedItem] lowercaseString]]];
	
	// TODO : check if align_image was run ...
	if ([mAutoalign state] == NSOnState) {
		MLogString(1 ,@"autoalign was run, get align data");
		// put filenames and full pathnames into the file array
		NSEnumerator *enumerator = [[[NSFileManager defaultManager] directoryContentsAtPath: [self temppath] ] objectEnumerator];
		while (nil != (filename = [enumerator nextObject])) {
			//NSLog(@"file : %@",[filename lastPathComponent]);
			if ([[filename lastPathComponent] hasPrefix:@"align"]) {				
				[enfusetask addFile:[NSString stringWithFormat:@"%@/%@",[self temppath],filename]];
			}
		}
		
	} else {
		NSDictionary* obj=nil;
		NSEnumerator *enumerator = [images objectEnumerator];
		
		while ( nil != (obj = [enumerator nextObject]) ) {
			if ([[obj valueForKey:@"enable"] boolValue]){
				//NSLog(@"add enable : %@",[obj valueForKey:@"text"]);
				[enfusetask addFile:[obj valueForKey:@"file"]]; // TODO : better !
			}
		}
	}		
	
	if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"JPEG"] ) {
		[enfusetask addArg:[NSString stringWithFormat:@"--compression=%@",[mOutQuality stringValue]]];
	} else if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"TIFF"] ) {
		[enfusetask addArg:@"--compression=LZW"]; // if jpeg !
	}
	
	
	[enfusetask addArg:[NSString stringWithFormat:@"--wExposure=%@",[mExposureSlider stringValue]]];
				
	[enfusetask addArg:[NSString stringWithFormat:@"--wSaturation=%@",[mSaturationSlider stringValue]]];
	[enfusetask addArg:[NSString stringWithFormat:@"--wContrast=%@",[mContrastSlider stringValue]]];
				
	[enfusetask addArg:[NSString stringWithFormat:@"--wMu=%@",[mMuSlider stringValue]]];
	[enfusetask addArg:[NSString stringWithFormat:@"--wSigma=%@",[mSigmaSlider stringValue]]];
	
	[mProgressIndicator setDoubleValue:0.0];
	[mProgressIndicator setMaxValue:(1+4*[images count])];
	[mProgressIndicator startAnimation:self];
	[enfusetask setDelegate:self];
	[enfusetask setProgress:mProgressIndicator]; // needed ?
	[NSThread detachNewThreadSelector:@selector(runEnfuse)
										 toTarget:enfusetask
									   withObject:nil];
				
	//[mEnfuseButton setEnabled:NO];
	
	// show the progress sheet
	[ NSApp beginSheet: mProgressPanel 
		modalForWindow: window modalDelegate: nil
		didEndSelector: nil contextInfo: nil ];
				[ NSApp runModalForWindow: mProgressPanel ];
				[ NSApp endSheet: mProgressPanel ];
				[ mProgressPanel orderOut: self ];
				
	[mEnfuseButton setTitle:@"Cancel"];
	return; // testing !				
}

- (void)runEnfuse
{
		      // If the task is still sitting around from the last run, release it
		   //if (enfuseTask!=nil)
			 //  [enfuseTask release];
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
				   MLogString(1 ,@"bad selected tag is %d",[[mOutputType selectedCell] tag]);
		   }
		   
		   [self setOutputfile:outputfile];
		   [self setTempfile:[self tempfilename:[[mOutFormat titleOfSelectedItem] lowercaseString]]];
		   MLogString(1 ,@"files are : (%@) %@,%@",outputfile,[self outputfile],[self tempfile]);

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
			   //NSLog(@"%s use ICC !",__PRETTY_FUNCTION__);
			   [args addObject:@"-c"];
		   }
		  	
		   NSString *cachesize = [defaults stringForKey:@"cachesize"];
		   if (![cachesize isEqualToString:@"default" ]) {
			   [args addObject:@"-m"];
			   [args addObject:cachesize];
		   }
		   NSString *blocksize = [defaults stringForKey:@"blocksize"];
		   if (![blocksize isEqualToString:@"default" ]) {
			   [args addObject:@"-b"];
			   [args addObject:blocksize];
		   }

		   [args addObject:@"-o"];
		   [args addObject:[self tempfile]];
		   
		   //[args addObject:@"-restore"];	
		   //[args addObject:[mInputFile stringValue]];
		   NSDictionary* obj=nil;
		   NSEnumerator *enumerator = [images objectEnumerator];
		   
		   while ( nil != (obj = [enumerator nextObject]) ) {
			   if ([[obj valueForKey:@"enable"] boolValue]){
				   //NSLog(@"add enable : %@",[obj valueForKey:@"text"]);
				   [args addObject:[obj valueForKey:@"file"]]; // TODO : better !
			   }
		   }
		   
		   
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
		
		   //enfuseTask=[[TaskWrapper alloc] initWithController:self arguments:args];
		   // kick off the process asynchronously
		   //[enfuseTask startProcess];
}
	   
	   


- (IBAction)reset:(id)sender
{
	MLogString(1 ,@"");
	
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
	MLogString(1 ,@"");
#if 0
// Method to load the .nib file for the info panel.
    if (!infoPanel) {
        if (![NSBundle loadNibNamed:@"InfoPanel" owner:self])  {
            NSLog(@"Failed to load InfoPanel.nib");
            NSBeep();
            return;
        }
        [infoPanel center];
    }
    [infoPanel makeKeyAndOrderFront:nil];
#endif
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

	NSString *outputDirectory;
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        if ([standardUserDefaults stringForKey:@"outputDirectory"]) {
                outputDirectory = [standardUserDefaults stringForKey:@"outputDirectory"];
        } else {
                outputDirectory = NSHomeDirectory();
                outputDirectory = [outputDirectory stringByAppendingPathComponent:@"Pictures"];
        }

	// Display the dialog.  If the OK button was pressed,
	// process the files.
	//      if ( [oPanel runModalForDirectory:nil file:nil types:fileTypes]
	if ( [oPanel runModalForDirectory:outputDirectory file:nil types:nil]
		 == NSOKButton )
	{
		// Get an array containing the full filenames of all
		// files and directories selected.
		NSArray* files = [oPanel filenames];
		
		NSString* fileName = [files objectAtIndex:0];
		MLogString(1 ,@"%@",fileName);
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
	MLogString(1 ,@"");
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

- (void) openPresetsDidEnd:(NSOpenPanel *)panel
             returnCode:(int)returnCode
            contextInfo:(void  *)contextInfo
{
	MLogString(1 ,@"");

  //Did they choose open?
  if(returnCode == NSOKButton) {
	NSData* data = [NSData dataWithContentsOfFile:[panel filename]];
	[self readFromData:data ofType:@"xml"];
	[data release];
  }
}

- (IBAction) openPresets: (IBOutlet)sender;
{
	MLogString(1 ,@"");
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	  [panel setCanChooseDirectories:NO];
	  [panel setCanChooseFiles:YES];
	  [panel setCanCreateDirectories:NO];
	  [panel setAllowsMultipleSelection:NO];
	  [panel setAlphaValue:0.95];
	  [panel setTitle:@"Select preset"];

	  [panel beginSheetForDirectory: nil
		 file:nil
		 types:nil
		 modalForWindow: window // [self window ]
		 modalDelegate:self
		 didEndSelector:
		   @selector(openPresetsDidEnd:returnCode:contextInfo:)
		 contextInfo:nil];
}

- (void) savePresetsDidEnd:(NSSavePanel *)panel
             returnCode:(int)returnCode
            contextInfo:(void  *)contextInfo
{
	MLogString(1 ,@"");

  //Did they choose open?
  if(returnCode == NSOKButton) {

    NSData* data = [self dataOfType:@"xml"];
    [data writeToFile:[panel filename] atomically:YES ];
  }
}

- (IBAction) savePresets: (IBOutlet)sender;
{
	MLogString(1 ,@"");
	NSSavePanel *panel = [NSSavePanel savePanel];

	  //[panel setCanCreateDirectories:YES];
	  //[panel setAllowsMultipleSelection:NO];
	  [panel setAlphaValue:0.95];
	  [panel setTitle:@"Save preset"];

	  [panel beginSheetForDirectory: nil
		 file:@"default.preset" // default filename
		 modalForWindow: window // [self window ]
		 modalDelegate:self
		 didEndSelector:
		   @selector(savePresetsDidEnd:returnCode:contextInfo:)
		 contextInfo:nil];
}

#pragma mark -
#pragma mark TaskWrapper

// This callback is implemented as part of conforming to the ProcessController protocol.
// It will be called whenever there is output from the TaskWrapper.
- (void)appendOutput:(NSString *)output
{
    // add the string (a chunk of the results from locate) to the NSTextView's
    // backing store, in the form of an attributed string
    if ([output hasPrefix:@"Generating"] || [output hasPrefix:@"Collapsing"]  ||
	[output hasPrefix: @"Loading next image"] || [output hasPrefix: @"Using"] ) {
	[mProgressIndicator incrementBy:1.0];
	value+=1;
	//NSLog(@"%d output is : [%@]",value, output);
	#ifndef GNUSTEP
	[myBadge badgeApplicationDockIconWithProgress:((value)/(2+4*[images count])) insetX:2 y:3];
#endif
    } /* else {
	MLogString(1 ,@"%d output is : [%@]",value, output);
    } */

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
    //[mEnfuseButton setEnabled:NO];
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
	
    if([mCopyMeta state]==NSOnState)  {
		[self copyExifFrom:[[images objectAtIndex:0] valueForKey:@"file"] to:[self outputfile] with:[self tempfile]];
    } else {
		NSFileManager *fm = [NSFileManager defaultManager];
		if ([fm fileExistsAtPath:([self tempfile])]){
			BOOL result = [fm movePath:[self tempfile] toPath:[self outputfile] handler:self];
		} else {
			NSString *alert = [[self tempfile] stringByAppendingString: @" do not exist!\nCan't rename"];
			NSRunAlertPanel (NSLocalizedString(@"Fatal Error",@""),
				 alert, NSLocalizedString(@"OK",nil), NULL, NULL);
		}
    }
	
    [self openFile:[self outputfile]];
}

// If the user closes the search window, let's just quit
-(BOOL)windowShouldClose:(id)sender
{
    if (findRunning == YES) {
		//[enfuseTask stopProcess];
		// Release the memory for this wrapper object
		//[enfuseTask release];
		//enfuseTask=nil;
    }
	
    [NSApp terminate:nil];
    return YES;
}

#pragma mark -
- (BOOL)shouldContinueOperationWithProgressInfo:(TaskProgressInfo*)inProgressInfo;
{
        //NSLog(@"%s thread is : %@",__PRETTY_FUNCTION__,[NSThread currentThread]);
        //NSLog(@"%s text is : %@",__PRETTY_FUNCTION__,[inProgressInfo displayText]);
	[mProgressText setStringValue:[inProgressInfo displayText]];
	[mProgressIndicator setDoubleValue:[[inProgressInfo progressValue] doubleValue]];

	// TODO : should check !
	[inProgressInfo setContinueOperation:findRunning];
	return findRunning;
}

//
// delegate for align_task thread
-(void)alignFinish:(int)status;
{
	MLogString(1 ,@"status %d",status);
        [mProgressIndicator setDoubleValue:0];
	[mProgressIndicator stopAnimation:self];
	[mProgressText setStringValue:@""];
	int canceled = [aligntask cancel];
	//[aligntask release];
	//aligntask = nil;
	[ NSApp stopModal ];
	if (status == 0 && canceled != YES) {
		[self doEnfuse];
	} else {
		[mEnfuseButton setTitle:@"Enfuse"];
		// [mEnfuseButton setEnabled:YES];
	}
}

//
// delegate for enfuse task thread 
-(void)enfuseFinish:(int)status;
{
	MLogString(1 ,@"status %d",status);
	[mProgressIndicator stopAnimation:self];
        [mProgressIndicator setDoubleValue:0];
	[mProgressText setStringValue:@""];
	
    findRunning=NO;
    // change the button's title back for the next search
    //[mEnfuseButton setTitle:@"Enfuse"];
    //[mEnfuseButton setEnabled:YES];
	int canceled = [enfusetask cancel];
	[ NSApp stopModal ];
	if (status  == 0 && canceled != YES) {
		if([mCopyMeta state]==NSOnState)  {
			[mProgressText setStringValue:@"Copying Exif values..."];
			[self copyExifFrom:[[images objectAtIndex:0] valueForKey:@"file"] 
				to:[self outputfile] with:[enfusetask outputfile]];
		} else {
			NSFileManager *fm = [NSFileManager defaultManager];
			if ([fm fileExistsAtPath:([enfusetask outputfile])]){
				BOOL result = [fm movePath:[enfusetask outputfile] toPath:[self outputfile] handler:self];
			} else {
				NSString *alert;
				NSString *file = [enfusetask outputfile];
				if (file != nil)
					alert = [file stringByAppendingString: @" do not exist!\nCan't rename"];
				else
					alert = @"no file name !";
				NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
			}
		}
		
		[self openFile:[self outputfile]];
	}
	[mProgressText setStringValue:@""];
        [mEnfuseButton setTitle:@"Enfuse"];
	//[mEnfuseButton setEnabled:YES];
}

#pragma mark -
#pragma mark tableview delegate

//
// tableview delegate and datasources ...
//

// return the number of row int the table
- (int)numberOfRowsInTableView: (NSTableView *)aTable
{
	MLogString(1 ,@"");
	//return [images count];
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	MLogString(1 ,@"");
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
		MLogString(1 ,@"%@",fileName);
		
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
				//MLogString(1 ,@"the exif data is: %@", [exif description]);
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
				NSNumber *exposureBiasObj = (NSNumber *)[exif objectForKey:@"ExposureBiasValue"];
				if (exposureBiasObj) {
					exposureBiasStr = [NSString stringWithFormat:@"Exposure Comp. : %+0.1f EV", [exposureBiasObj floatValue]];
				} else 
					exposureBiasStr = @"";
				
				text = [NSString stringWithFormat:@"%@\n%@ / %@ @ %@\n%@", [fileName lastPathComponent],
					focalLengthStr,exposureTimeStr,fNumberStr,exposureBiasStr];
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

-(NSString*)temppath;
{
        return _tmppath;
}

-(void)setTempPath:(NSString *)file;
{
        if (_tmppath != file) {
                [_tmppath release];
        _tmppath = [file copy];
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

- (IBAction)preferencesSaving:(id)sender;
{
	MLogString(1 ,@"");
#if 0
	[options setAddKeyword:[exportOptionsSheetController AddKeyword]];
	[options setImportInAperture:[exportOptionsSheetController ImportInAperture]];
	[options setStackWithOriginal:[exportOptionsSheetController stackWithOriginal]];
	if ([options addKeyword] == YES)
		[options setKeyword:[exportOptionsSheetController keyword]];
	else 
		[options setKeyword:nil];
#else
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	[useroptions setValue:[NSNumber numberWithBool:[exportOptionsSheetController AddKeyword]]
		forKey:@"addKeyword"];
	[useroptions setValue:[NSNumber numberWithBool:[exportOptionsSheetController ImportInAperture]] 
		forKey:@"importInAperture"];
	[useroptions setValue:[NSNumber numberWithBool:[exportOptionsSheetController stackWithOriginal]]
		forKey:@"stackWithOriginal"];
	if ([exportOptionsSheetController AddKeyword])
		[useroptions setObject:[exportOptionsSheetController keyword]
			 forKey:@"keyword"];
	else
		[useroptions removeObjectForKey:@"keyword"];
#endif
}

- (IBAction)openPreferences:(id)sender
{
	MLogString(1 ,@"");
#if 1
	[[MyPrefsWindowController sharedPrefsWindowController] showWindow:nil];
	(void)sender;
#else
	if (exportOptionsSheetController == nil) 
		exportOptionsSheetController = [[ExportOptionsController alloc] init ];
#if 0
    [exportOptionsSheetController setImportInAperture:[options importInAperture]];
	[exportOptionsSheetController setAddKeyword:[options addKeyword]];
	[exportOptionsSheetController stackWithOriginal:[options stackWithOriginal]];
	if ([options addKeyword])
		[exportOptionsSheetController setKeyword:[options keyword]];
#else
    [exportOptionsSheetController setImportInAperture:
		[[useroptions valueForKey:@"importInAperture"] boolValue]];
    [exportOptionsSheetController stackWithOriginal:
		[[useroptions valueForKey:@"stackWithOriginal"] boolValue]];
    [exportOptionsSheetController setAddKeyword:
		[[useroptions valueForKey:@"addKeyword"] boolValue]];
    if ([[useroptions valueForKey:@"addKeyword"] boolValue])
	[exportOptionsSheetController setKeyword:
		[useroptions valueForKey:@"keyword"]];

#endif		
	[exportOptionsSheetController runSheet:window selector:@selector(preferencesSaving:) target:self];
#endif
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
      NSString *tempFilename = [self temppath]; // NSTemporaryDirectory();
    
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
	MLogString(1 ,@"");
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
		NSDictionary* metadata = (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(exifsrc, 0, NULL);
		//make the metadata dictionary mutable so we can add properties to it
		NSMutableDictionary *metadataAsMutable = [[metadata mutableCopy]autorelease];
		[metadata release];
	
		//NSLog(@"props: %@", [(NSDictionary *)properties description]);
		 NSMutableDictionary *newExif = [[[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary]mutableCopy]autorelease];
    
		if(!newExif) {
			//if the image does not have an EXIF dictionary (not all images do), then create one for us to use
			newExif = [NSMutableDictionary dictionary];
		}
	
		//NSDictionary *exif = (NSDictionary *)[properties objectForKey:(NSString *)kCGImagePropertyExifDictionary];
		if(newExif) { /* kCGImagePropertyIPTCDictionary kCGImagePropertyExifAuxDictionary */
			//NSLog(@"the exif data is: %@", [exif description]);
			//newExif = [NSMutableDictionary dictionaryWithDictionary:exif];

			if ([mCopyShutter state]==NSOnState) {
				MLogString(1 ,@"removing shutter speed");
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifExposureTime];
			}
			if ([mCopyAperture state]==NSOnState) {
				MLogString(1 ,@"removing aperture");
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifFNumber];
			}
			if ([mCopyFocal state]==NSOnState) {
				MLogString(1 ,@"removing focal length");
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifFocalLength];
			}
		} /* kCGImagePropertyExifFocalLength kCGImagePropertyExifExposureTime kCGImagePropertyExifExposureTime */
		
		//add our modified EXIF data back into the imageÕs metadata
		[metadataAsMutable setObject:newExif forKey:(NSString *)kCGImagePropertyExifDictionary];
		
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
						     (CFDictionaryRef)metadataAsMutable);
		}
    
		CGImageDestinationFinalize(destination);
    
		CFRelease(destination);
		CFRelease(source); 
		//CFRelease(properties);
		//CFRelease(exifsrc); 
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
              NSRunAlertPanel (NSLocalizedString(@"Fatal Error",@""), alert, @"OK", NULL, NULL);
        }
#endif
	[pool release];
}

// write back the defaults ...
-(void)setDefaults;
{
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];

        if (standardUserDefaults) {
			
              [standardUserDefaults setObject:[mOuputFile stringValue] forKey:@"outputDirectory"];
              [standardUserDefaults setObject:[mOutFile stringValue] forKey:@"outputFile"];
              [standardUserDefaults setObject:[mAppendTo stringValue] forKey:@"outputAppendTo"];
              [standardUserDefaults setObject:[mOutQuality stringValue] forKey:@"outputQuality"];
	
	  id obj = [useroptions valueForKey:@"importInAperture"];
	  if (obj != nil)
	  [standardUserDefaults setObject:obj
					forKey:@"importInAperture"];

	  obj = [useroptions valueForKey:@"stackWithOriginal"];
	  if (obj != nil)
	  [standardUserDefaults setObject:obj
					 forKey:@"stackWithOriginal"];

	  obj = [useroptions valueForKey:@"addKeyword"];
	  if (obj != nil) {
		  [standardUserDefaults setObject:obj
					 forKey:@"addKeyword"];
		  if ([obj boolValue])
			[standardUserDefaults setObject:[useroptions valueForKey:@"keyword"]
					 forKey:@"keyword"];
			 
	   } 
              [standardUserDefaults synchronize];
        }
}

// read back the defaults ...
-(void)getDefaults;
{
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];

        if (standardUserDefaults) {
			  NSString *temp;
			  
			  temp = [standardUserDefaults objectForKey:@"outputDirectory"];
			  if (temp != nil)
				[mOuputFile setStringValue:temp];
			  
			  temp = [standardUserDefaults objectForKey:@"outputFile"];
			  if (temp != nil)
				[mOutFile setStringValue:temp];
			  
			  temp = [standardUserDefaults objectForKey:@"outputAppendTo"];
			  if (temp != nil)
				[mAppendTo setStringValue:temp];
				
			  temp = [standardUserDefaults objectForKey:@"outputQuality"];
			  if (temp != nil)
				[mOutQuality setStringValue:temp];
				
			[useroptions setValue:[standardUserDefaults objectForKey:@"importInAperture"]
				forKey:@"importInAperture"];
			[useroptions setValue:[standardUserDefaults objectForKey:@"stackWithOriginal"]
				forKey:@"stackWithOriginal"];
			[useroptions setValue:[standardUserDefaults objectForKey:@"addKeyword"]
				forKey:@"addKeyword"];
			if ([[useroptions valueForKey:@"addKeyword"] boolValue])
				[useroptions setValue:[standardUserDefaults objectForKey:@"keyword"]
					forKey:@"keyword"];
        }
}

-(NSString *)initTempDirectory;
{
        // Create our temporary directory
                NSString* tempDirectoryPath = [NSString stringWithFormat:@"%@/enfuseGUI", 
				NSTemporaryDirectory()];

                // If it doesn't exist, create it
                NSFileManager *fileManager = [NSFileManager defaultManager];
                BOOL isDirectory;
                if (![fileManager fileExistsAtPath:tempDirectoryPath isDirectory:&isDirectory])
                {
                        [fileManager createDirectoryAtPath:tempDirectoryPath attributes:nil];
                }
                else if (isDirectory) // If a folder already exists, empty it.
                {
                        NSArray *contents = [fileManager directoryContentsAtPath:tempDirectoryPath];
                        int i;
                        for (i = 0; i < [contents count]; i++)
                        {
                                NSString *tempFilePath = [NSString stringWithFormat:@"%@/%@", 
					tempDirectoryPath, [contents objectAtIndex:i]];
                                [fileManager removeFileAtPath:tempFilePath handler:nil];
                        }
                }
                else // Delete the old file and create a new directory
                {
                        [fileManager removeFileAtPath:tempDirectoryPath handler:nil];
                        [fileManager createDirectoryAtPath:tempDirectoryPath attributes:nil];
                }
		return tempDirectoryPath;
}

//
// check if this beta version has expired !
- (void) checkBeta;
{
	NSDate *expirationDate = 
	[[NSDate dateWithNaturalLanguageString:
		[NSString stringWithCString:__DATE__]] 
            addTimeInterval:(60*60*24*30/*30 days*/)];
	
    if( [expirationDate earlierDate:[NSDate date]] 
		== expirationDate )
    {
        int result = NSRunAlertPanel(@"Beta Expired", 
									 @"This beta has expired, please visit "
									 "http://vald70.free.fr/ to grab"
									 "the latest version.", 
									 @"Take Me There", @"Exit", nil);
		
        if( result == NSAlertDefaultReturn )
        {
            [[NSWorkspace sharedWorkspace] openURL:
				[NSURL URLWithString:
							  @"http://vald70.free.fr/"]];
        }
        [[NSApplication sharedApplication] terminate:self];
    }
}

@end
