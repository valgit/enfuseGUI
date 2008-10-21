//
//  exportOptions.h
//  enfuseGUI
//
//  Created by valery brasseur on 10/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface exportOptions : NSObject {

    BOOL _ImportInAperture;
    BOOL _stackWithOriginal;
    BOOL _AddKeyword;
    NSString* _Keyword;
}

-(id)init;
-(void)dealloc;

-(BOOL)importInAperture;
-(void)setImportInAperture:(BOOL)state;

-(BOOL)stackWithOriginal;
-(void)setStackWithOriginal:(BOOL)state;

-(BOOL)addKeyword;
-(void)setAddKeyword:(BOOL)state;

-(NSString*)keyword;
-(void)setKeyword:(NSString*)keyword;

@end
