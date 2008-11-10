/*
 * interface to taskwrapper for align_stack_process
 */
#import <Cocoa/Cocoa.h>
#import "MLog.h"
#import "alignStackTask.h"

@implementation alignStackTask
    
-(id)initWithPath:(NSString*)tmp_path {
  self = [super init];
  if (self) {
    //NSLog(@"%s",__PRETTY_FUNCTION__);
    //lock = [[NSConditionLock alloc] initWithCondition:0];
	progress = nil;
	mProgressInfo  = [[TaskProgressInfo alloc ] init];
	cancel =NO;
	args = [[NSMutableArray array] retain];
	align_path = [[NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],
			   @"/align_image_stack"] retain];
	[args addObject:align_path];
	[args addObject:@"-a"];
	
	NSString *tempDirectoryPath = [NSString stringWithFormat:@"%@/align", tmp_path];
	
	[args addObject:tempDirectoryPath];
	
	MLogString(1 ,@"will run with : << %@ >>",
		args);
    filename = nil;
  }
  return self;
}

-(void)dealloc;
{
  MLogString(1 ,@"");
  //[lock release];
  [args release];
  [align_path release];
  [alignTask release];
  [mProgressInfo release];
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

- (void)setGridSize:(NSString*)gridsize;
{
	[args addObject:@"-g"];
	[args addObject:gridsize];
}

- (void)setControlPoints:(NSString*)controls;
{
	[args addObject:@"-c"];
	[args addObject:controls];
}

- (void)addFile:(NSString*)file;
{
	[args addObject:file];
}

- (void)setProgress:(NSProgressIndicator *)mProgressIndicator;
{
	progress = mProgressIndicator;
}

-(void)setCancel:(BOOL)nstate;
{
	if (nstate == YES) {
		[alignTask cancelProcess];
	} 
	if ( nstate != cancel) {
		cancel = nstate;
	}

}

- (BOOL)cancel;
{
	return cancel;
}

#pragma mark -

/*
 * run the process until exit ...
 */
-(void)runAlign;
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	MLogString(1 ,@"will run with : << %@ >>",
		 args);
	if (findRunning) {
		   NSLog(@"already running");
		   return;
	   } else {
		   // If the task is still sitting around from the last run, release it
		   if (alignTask!=nil)
			   [alignTask release];
			   
		   [mProgressInfo setProgressValue:[NSNumber numberWithInt:0]];
		   [mProgressInfo setDisplayText:@""];
		   alignTask=[[TaskWrapper alloc] initWithController:self arguments:args];
		   int status = [alignTask startProcess];
		   if (status == 0) {		
				state = 0;
				[alignTask waitUntilExit];
		   }	   
	   }
	[pool release];
	[NSThread exit];
}

- (void)appendOutput:(NSString *)output;
{
	//NSLog(@"%s output is : [%@]",__PRETTY_FUNCTION__,output);
	//[mProgressInfo setDisplayText:@""];
	if ([output rangeOfString:@"loading"].location != NSNotFound) {
		if (state != 1) {
		//	NSLog(@"load");
		NSArray *listItems = [output componentsSeparatedByString:@" "];
		//NSLog(@"%s load : %d >>> [%@]",__PRETTY_FUNCTION__,
		//	[listItems count], [listItems objectAtIndex:13]);
		[filename release];
		filename = [[listItems objectAtIndex:13] copy];
		[mProgressInfo setDisplayText:[NSString stringWithFormat:@"Align : loading %@",filename]];
		[mProgressInfo setProgressValue:[NSNumber numberWithInt:
			([[mProgressInfo progressValue] intValue]+1)]];
			state = 1;
		}
	} else
	if ([output rangeOfString:@"saving"].location != NSNotFound)  {
		if (state != 2) {
		//	NSLog(@"save");
		[mProgressInfo setDisplayText:[NSString stringWithFormat:@"Align : saving %@",filename]];
			state = 2;
		[mProgressInfo setProgressValue:[NSNumber numberWithInt:
			([[mProgressInfo progressValue] intValue]+1)]];
		}
	} else
	if ([output rangeOfString:@"remapping"].location != NSNotFound) {
		if (state != 3) {
		//	NSLog(@"remap");
		[mProgressInfo setDisplayText:[NSString stringWithFormat:@"Align : remapping %@",filename]];
			state = 3;
		[mProgressInfo setProgressValue:[NSNumber numberWithInt:
			([[mProgressInfo progressValue] intValue]+1)]];
		}
	}  else
	if (([output rangeOfString:@"Optimizing"].location != NSNotFound)|| 
	   ([output rangeOfString:@"Strategy"].location != NSNotFound) ) {
		if (state != 4) {
		//	NSLog(@"optim");
		[mProgressInfo setDisplayText:@"Align : optimizing"];
		[mProgressInfo setProgressValue:[NSNumber numberWithInt:
			([[mProgressInfo progressValue] intValue]+1)]];
			state = 4;
		}
	}  else
	if ([output rangeOfString:@"Remapping:"].location != NSNotFound) {
	   //NSLog(@"%s (last state %d) output is : [%@]",__PRETTY_FUNCTION__,state,output);
		[mProgressInfo setProgressValue:[NSNumber numberWithInt:
			([[mProgressInfo progressValue] intValue]+1)]];
	}

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

-(void)finishedAligning:(NSNumber *)status
{
	
	if (_delegate && [_delegate respondsToSelector:@selector(alignFinish:)]) 
        [_delegate alignFinish:[status intValue]];
	MLogString(1 ,@"status %@",status);
}

- (void)processFinished:(int)status;
{
	
	findRunning=NO;
	
	[self performSelectorOnMainThread:
      @selector(finishedAligning:) withObject:[NSNumber numberWithInt:status]
      waitUntilDone:NO];
	MLogString(1 ,@"status %d",status);
}

@end
