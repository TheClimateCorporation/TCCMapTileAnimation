//
//  MATTileOverlay.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 7/7/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>

@class MATAnimatedTileOverlay;

@interface MATTileOverlay : MKTileOverlay

- (instancetype)initWithAnimationTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay;

@end
