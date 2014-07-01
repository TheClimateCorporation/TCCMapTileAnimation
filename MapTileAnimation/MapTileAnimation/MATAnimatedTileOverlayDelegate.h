//
//  MATAnimatedTileOverlayDelegate.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/30/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

@class MATAnimatedTileOverlay;

@protocol MATAnimatedTileOverlayDelegate <NSObject>

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex;
- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didHaveError:(NSError *) error; // Does not stop the fetching of other images, could have multiple errors



@end