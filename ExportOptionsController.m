#import "ExportOptionsController.h"

@implementation ExportOptionsController

- (void)runSheet:(NSWindow*)parentWindow selector:(SEL)sel target:(id)target;
{
    _selector = sel;
    _target = target; // don't retain

    // init outlet here ...
    //[widthTextField setFloatValue:_initialSize.width];

    [NSApp beginSheet: window
       modalForWindow: parentWindow
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:)
          contextInfo: nil];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet close];
}

#pragma mark -

- (IBAction)cancelAction:(id)sender
{
    [NSApp endSheet: window returnCode:NSCancelButton];
}

- (IBAction)okAction:(id)sender
{
    [NSApp endSheet: window returnCode:NSOKButton];

    // call the sheet is done action
    if (_selector && _target)
            [_target performSelector:_selector withObject:self];
}

#pragma mark -

- (NSString*)keyword;
{
    return [mKeywordField stringValue];
}

- (void)setKeyword:(NSString*)newkey;
{
    [mKeywordField setStringValue:newkey];
}


@end

