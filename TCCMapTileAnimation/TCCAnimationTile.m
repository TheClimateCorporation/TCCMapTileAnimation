//
//  TCCAnimationTile.h
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCAnimationTile.h"

@implementation TCCAnimationTile

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
    return [NSString stringWithFormat:@"(%d, %d, %d) mapRectFrame origin: (%f, %f) size: (%f, %f)", self.x, self.y, self.z, self.mapRectFrame.origin.x, self.mapRectFrame.origin.y, self.mapRectFrame.size.width, self.mapRectFrame.size.height];
}

#pragma mark - Overridden methods

//checks to see if hashCoords is equal on the two tiles being compared
- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TCCAnimationTile class]]) return NO;
    
    TCCAnimationTile *other = (TCCAnimationTile *)object;
    return [self hash] == [other hash] &&
            self.x == other.x &&
            self.y == other.y &&
            self.z == other.z;
}

//custom hash to identify tiles by their x/y/z (their hashCoords)
- (NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%d/%d/%d", self.x, self.y, self.z] hash];
}

@end
