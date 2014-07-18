//
//  TCCMapTile.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "MATAnimationTile.h"

@implementation MATAnimationTile

- (id)initWithFrame:(MKMapRect)frame x:(NSInteger)x y:(NSInteger)y z:(NSInteger)z
{
    self = [super init];
	if (self) {
		_x = x;
		_y = y;
		_z = z;
        _mapRectFrame = frame;
    }
    return self;
}

#pragma mark - Public methods

- (NSString *)description
{
    return [NSString stringWithFormat:@"(%d, %d, %d). mapRectFrame origin: (%f, %f) size: (%f, %f)", self.x, self.y, self.z, self.mapRectFrame.origin.x, self.mapRectFrame.origin.y, self.mapRectFrame.size.width, self.mapRectFrame.size.height];
}

@end
