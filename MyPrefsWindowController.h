//
//  MyPrefsWindowController.h
//  ingest
//
//  Created by valery brasseur on 8/9/07.
//  Copyright 2007 Valery Brasseur. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DBPrefsWindowController.h"

@interface MyPrefsWindowController : DBPrefsWindowController {
  IBOutlet NSView *generalPrefsView;
  IBOutlet NSView *updatePrefsView;}

//- (void)chooseDestDir: (NSButton *)sender;

@end
