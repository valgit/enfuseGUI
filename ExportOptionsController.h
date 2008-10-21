/*
 *
 */
#import <Cocoa/Cocoa.h>

@interface ExportOptionsController : NSWindowController
{
    IBOutlet NSWindow* window;
    IBOutlet id okButton;
    IBOutlet id cancelButton;

    IBOutlet NSButton* mImportInAperture;
    IBOutlet NSButton* mstackWithOriginal;
    IBOutlet NSButton* mAddKeyword;
    IBOutlet NSTextField* mKeywordField;

    SEL _selector;
    id _target;
}

- (IBAction)okAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

- (void)runSheet:(NSWindow*)parentWindow selector:(SEL)sel target:(id)target;

- (NSString*)keyword;
- (void)setKeyword:(NSString*)newkey;

@end

