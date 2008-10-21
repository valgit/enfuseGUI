//
//  exportOptions.m
//  enfuseGUI
//
//  Created by valery brasseur on 10/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "exportOptions.h"


@implementation exportOptions

-(id)init;
{
	if ( ! [super init])
        return nil;
		
	[self setImportInAperture:NO];
	[self setStackWithOriginal:NO];
	[self setAddKeyword:NO];
	[self setKeyword:nil];
	
	return self;
}

-(void)dealloc;
{
	if (_Keyword != nil)
		[_Keyword release];
	[super dealloc];
}

#pragma mark -

-(BOOL)importInAperture;
{
	return _ImportInAperture;
}

-(void)setImportInAperture:(BOOL)state;
{
	if (_ImportInAperture != state)
		_ImportInAperture = state;
}

-(BOOL)stackWithOriginal;
{
	return _stackWithOriginal;
}

-(void)setStackWithOriginal:(BOOL)state;
{
	if (_stackWithOriginal != state)
		_stackWithOriginal = state;
}

-(BOOL)addKeyword;
{
	return _AddKeyword;
}

-(void)setAddKeyword:(BOOL)state;
{
	if (_AddKeyword != state)
		_AddKeyword = state;
}

-(NSString*)keyword;
{
	return _Keyword;
}

-(void)setKeyword:(NSString*)keyword;
{
	if (_Keyword != keyword) {
		[_Keyword release];
        _Keyword = [keyword copy];
	}
}

@end
