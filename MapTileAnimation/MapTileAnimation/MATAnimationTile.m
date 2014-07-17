//
//  TCCMapTile.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "MATAnimationTile.h"

@implementation MATAnimationTile
//=================================================================================
- (id) initWithFrame:(MKMapRect)aTileFrame xCord: (NSInteger)aXCord yCord: (NSInteger)aYCord zCord: (NSInteger)aZCord
{
    self = [super init];
	if (self) {
		self.tileCoordinate = nil;
		self.xCoordinate = aXCord;
		self.yCoordinate = aYCord;
		self.zCoordinate = aZCord;
        self.mapRectFrame = aTileFrame;
		self.currentImageTile = nil;
    }
    return self;
}

#pragma mark - Public methods

- (NSString *)description
{
    return [NSString stringWithFormat:@"(%d, %d, %d)", self.xCoordinate, self.yCoordinate, self.zCoordinate];
}

@end
