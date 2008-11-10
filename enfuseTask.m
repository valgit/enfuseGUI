//
//  enfuseTask.m
//  enfuseGUI
//
//  Created by valery brasseur on 10/16/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "MLog.h"
#import "enfuseTask.h"

@implementation enfuseTask
-(id)init {
	self = [super init];
	if (self) {
		//NSLog(@"%s",__PRETTY_FUNCTION__);
		//lock = [[NSConditionLock alloc] initWithCondition:0];
		progress = nil;
		mProgressInfo  = [[TaskProgressInfo alloc ] init];
		cancel =NO;
		enfusingTask = nil;
		args = [[NSMutableArray array] retain];
		enfuse_path = [[NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],
			@"/enfuse"] retain];
		[args addObject:enfuse_path];
			
		  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		   //NSLog(@"icc : %@",[defaults boolForKey:@"useCIECAM02"]);
		   if ([defaults boolForKey:@"useCIECAM"]) { // ICC profile
			   MLogString(1 ,@"use ICC !");
			   [args addObject:@"-c"];
		   }

		MLogString(1 ,@"will run with : << %@ >>",
			   args);
		
	}
	return self;
}

-(void)dealloc;
{
	MLogString(1 ,@"");
	//[lock release];
	[args release];
	[enfuse_path release];
	[mProgressInfo release];

	if (enfusingTask != nil)
		[enfusingTask release];
	[super dealloc];
}

- (id)delegate;
{
	return _delegate;
}

- (void)setDelegate:(id)new_delegate;
{
	_delegate = new_delegate;
}

#pragma mark -

- (void)addArg:(NSString*)arg;
{
	[args addObject:arg];
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
	[args addObject:@"-o"];
	[args addObject:file];
}


- (void)addFile:(NSString*)file;
{
	[args addObject:file];
}

- (void)setProgress:(NSProgressIndicator *)mProgressIndicator;
{
	progress = mProgressIndicator;
}

-(void)setCancel:(BOOL)state;
{  
	if (state == YES) {
		[enfusingTask cancelProcess];
        }
	if (state != cancel)
		cancel = state;
}

- (BOOL)cancel;
{
	return cancel;
}

#pragma mark -

/*
 * run the process until exit ...
 */
-(void)runEnfuse;
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	MLogString(1 ,@"will run with : << %@ >>",
		   args);
	if (findRunning) {
		MLogString(1 ,@"already running");
		return;
	   } else {
		   // If the task is still sitting around from the last run, release it
		   if (enfusingTask!=nil)
			   [enfusingTask release];
		   
		   enfusingTask=[[TaskWrapper alloc] initWithController:self arguments:args];
		   int status = [enfusingTask startProcess];
		   [mProgressInfo setProgressValue:[NSNumber numberWithInt:0]];
                   [mProgressInfo setDisplayText:NSLocalizedString(@"Enfusing...",@"")];

		   if (status == 0) {		
			   [enfusingTask waitUntilExit];
		   } else {
               NSRunAlertPanel (NSLocalizedString(@"Fatal Error",@""), @"running error", @"OK", NULL, NULL);
		   }	   
	   }
	[pool release];
	[NSThread exit];
}

// run on main thread (UI)
- (void) updateProgressBar
{
    //[progressIndicator setDoubleValue: [aNumber doubleValue]]];
    [progress incrementBy:1.0];
        //NSLog(@"%s thread is : %@",__PRETTY_FUNCTION__,[NSThread currentThread]);
}

- (void)appendOutput:(NSString *)output;
{
	//NSLog(@"%s output is : [%@]",__PRETTY_FUNCTION__,output);
	if ([output hasPrefix:@"Generating"] || [output hasPrefix:@"Collapsing"]  ||
        [output hasPrefix: @"Loading next image"] || [output hasPrefix: @"Using"] ) {
        // UI should be on main thread !
        //[self performSelectorOnMainThread: @selector(updateProgressBar)
         //       withObject:nil waitUntilDone:NO];
        //[mProgessIndicator incrementBy:1.0];
	[mProgressInfo setProgressValue:[NSNumber numberWithInt:
                ([[mProgressInfo progressValue] intValue]+1)]];
        //NSLog(@"%d output is : [%@]",value, output);
    } /* else {
        MLogString(1 ,@"%d output is : [%@]",value, output);
    } */

   // call on main thread ...
   if (_delegate && [_delegate respondsToSelector:@selector(shouldContinueOperationWithProgressInfo:)])
                [_delegate performSelectorOnMainThread: @selector(shouldContinueOperationWithProgressInfo:)
                withObject:mProgressInfo waitUntilDone:YES];

    // check if we should continue !
    if ([mProgressInfo continueOperation] == NO)
                [self setCancel:YES];
}


- (void)processStarted;
{
	findRunning=YES;
	MLogString(1 ,@"");
}

#pragma mark -

-(void)finishedEnfusing:(NSNumber *)status
{
	
	if (_delegate && [_delegate respondsToSelector:@selector(enfuseFinish:)]) 
        [_delegate enfuseFinish:[status intValue]];
	MLogString(1 ,@"status %@",status);
}

- (void)processFinished:(int)status;
{
	
	findRunning=NO;
	
	[self performSelectorOnMainThread:
      @selector(finishedEnfusing:) withObject:[NSNumber numberWithInt:status]
						waitUntilDone:NO];
	MLogString(1 ,@"status %d",status);
}


@end
