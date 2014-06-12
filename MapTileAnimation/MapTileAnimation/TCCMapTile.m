//
//  TCCMapTile.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapTile.h"

@implementation TCCMapTile
//=================================================================================
- (id) initWithFrame:(MKMapRect)aTileFrame tileCoordinate:(NSString *)aTileCoordinate
{
    self = [super init];
	if (self) {
		self.tileCoordinate = aTileCoordinate;
        self.mapRectFrame = aTileFrame;
		self.imageTile = nil;
    }
    return self;
}
//=================================================================================

//=================================================================================

//=================================================================================

@end
