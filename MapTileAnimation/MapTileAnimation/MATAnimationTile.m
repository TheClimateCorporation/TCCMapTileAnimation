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
        self.hashCoords = [NSString stringWithFormat:@"%d/%d/%d", self.xCoordinate, self.yCoordinate, self.zCoordinate];
    }
    return self;
}

#pragma mark - Public methods

- (NSString *)description
{
    return [NSString stringWithFormat:@"(%d, %d, %d). mapRectFrame origin: (%f, %f) size: (%f, %f)", self.xCoordinate, self.yCoordinate, self.zCoordinate, self.mapRectFrame.origin.x, self.mapRectFrame.origin.y, self.mapRectFrame.size.width, self.mapRectFrame.size.height];
}

#pragma mark - Overridden methods

//checks to see if hashCoords is equal on the two tiles being compared
- (BOOL)isEqual:(id)object
{
    //NSLog(@"object checked! %@", [object hashCoords]);
    return [self.hashCoords isEqual:[object hashCoords]];
    
}

//custom hash to identify tiles by their x/y/z (their hashCoords)
- (NSUInteger)hash
{
    //NSLog(@"object hashed! %@", self.hashCoords);
    return [self.hashCoords hash];
}

@end
