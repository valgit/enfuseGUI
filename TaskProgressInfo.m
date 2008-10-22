/*
 * 
 */
#import "TaskProgressInfo.h"

@interface TaskProgressInfo (Private)

- (void)setDisplayText:(NSString*)text;
- (BOOL)continueOperation;
- (void)setProgressValue:(NSNumber *)value;
- (void)setTaskStatus:(NSError *)status;

@end

@implementation TaskProgressInfo

-  (NSString*)displayText;
{
    return [[displayText retain] autorelease];
}

- (NSNumber *)progressValue
{
    return [[progressValue retain] autorelease];
}

- (NSError *)taskStatus {
    return [[taskStatus retain] autorelease];
}

- (BOOL)continueOperation;
{
    return continueOperation;
}


- (void)dealloc
{
    [progressValue release];
    [taskStatus release];
    [displayText release];    
    [super dealloc];
}

@end

@implementation TaskProgressInfo (Private)

- (void)setDisplayText:(NSString*)text;
{
  if (displayText != text) {
        [displayText release];
        displayText = [text copy];
    }
}

- (void)setContinueOperation:(BOOL)value
{
    continueOperation = value;
}


- (void)setProgressValue:(NSNumber *)value
{
    if (progressValue != value) {
        [progressValue release];
        progressValue = [value copy];
    }
}

- (void)setTaskStatus:(NSError *)status
{
    if (taskStatus != status) {
        [taskStatus release];
        taskStatus = [status copy];
    }
}

@end


