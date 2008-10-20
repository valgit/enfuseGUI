//
//  enfuseTask.m
//  enfuseGUI
//
//  Created by valery brasseur on 10/16/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "enfuseTask.h"


@implementation enfuseTask
-(id)init {
	self = [super init];
	if (self) {
		//NSLog(@"%s",__PRETTY_FUNCTION__);
		//lock = [[NSConditionLock alloc] initWithCondition:0];
		progress = nil;
		cancel =NO;
		enfusingTask = nil;
		args = [[NSMutableArray array] retain];
		enfuse_path = [[NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],
			@"/enfuse"] retain];
		[args addObject:enfuse_path];
			
		  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		   //NSLog(@"icc : %@",[defaults boolForKey:@"useCIECAM02"]);
		   if ([defaults boolForKey:@"useCIECAM"]) { // ICC profile
			   NSLog(@"%s use ICC !",__PRETTY_FUNCTION__);
			   [args addObject:@"-c"];
		   }

		NSLog(@"%s will run with : << %@ >>",
			  __PRETTY_FUNCTION__, args);
		
	}
	return self;
}

-(void)dealloc;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	//[lock release];
	[args release];
	[enfuse_path release];
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

-(void)setCancel;
{
	cancel = YES;
	[enfusingTask cancelProcess];
}

- (BOOL)isCancel;
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
	
	NSLog(@"%s will run with : << %@ >>",
		  __PRETTY_FUNCTION__, args);
	if (findRunning) {
		NSLog(@"already running");
		return;
	   } else {
		   // If the task is still sitting around from the last run, release it
		   if (enfusingTask!=nil)
			   [enfusingTask release];
		   
		   enfusingTask=[[TaskWrapper alloc] initWithController:self arguments:args];
		   int status = [enfusingTask startProcess];
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
        [self performSelectorOnMainThread: @selector(updateProgressBar)
                withObject:nil waitUntilDone:NO];
        //[mProgessIndicator incrementBy:1.0];
        //NSLog(@"%d output is : [%@]",value, output);
    } /* else {
        NSLog(@"%d output is : [%@]",value, output);
    } */

}


- (void)processStarted;
{
	findRunning=YES;
	NSLog(@"%s",__PRETTY_FUNCTION__);
}

#pragma mark -

-(void)finishedEnfusing:(NSNumber *)status
{
	
	if (_delegate && [_delegate respondsToSelector:@selector(enfuseFinish:)]) 
        [_delegate enfuseFinish:[status intValue]];
	NSLog(@"%s status %@",__PRETTY_FUNCTION__,status);
}

- (void)processFinished:(int)status;
{
	
	findRunning=NO;
	
	[self performSelectorOnMainThread:
      @selector(finishedEnfusing:) withObject:[NSNumber numberWithInt:status]
						waitUntilDone:NO];
	NSLog(@"%s status %d",__PRETTY_FUNCTION__,status);
}


@end
