//
//  MyPrefsWindowController.m
//  ingest
//
//  Created by valery brasseur on 8/9/07.
//  Copyright 2007 Valery Brasseur. All rights reserved.
//

#import "MyPrefsWindowController.h"

@implementation MyPrefsWindowController

- (void)setupToolbar
{
  [self addView:generalPrefsView label:@"general" ];
  [self addView:updatePrefsView label:@"update"  ];
}

@end
