//
//  MATAnimatedTileOverlayDelegate.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/30/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "MATAnimatedTileOverlay.h"

typedef NS_ENUM(NSUInteger, MATAnimatingErrorCode) {
	MATAnimatingErrorInvalidZoomLevel = 1001,
	MATAnimatingErrorBadURLResponseCode = 1003,
	MATAnimatingErrorNoImageData = 1003

};

@class MATAnimatedTileOverlay;

@protocol MATAnimatedTileOverlayDelegate <NSObject>

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didChangeAnimationState:(MATAnimatingState)currentAnimationState;
- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex;
// Does not stop the fetching of other images, could have multiple errors
- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didHaveError:(NSError *) error;


@end