//
//  MATAnimatedTileOverlay.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "MATAnimatedTileOverlayDelegate.h"

@class MATAnimationTile;

// TODO: rename to use proper enum convention
typedef NS_ENUM(NSUInteger, MATAnimatingState) {
	MATAnimatingState_stopped = 0,
	MATAnimatingState_loading = 1,
	MATAnimatingState_animating = 2
};

@interface MATAnimatedTileOverlay : NSObject <MKOverlay>

@property (weak, nonatomic) id<MATAnimatedTileOverlayDelegate>delegate;
@property (readonly, nonatomic) NSInteger numberOfAnimationFrames;
@property (nonatomic) NSInteger currentFrameIndex;
@property (readonly, nonatomic) MATAnimatingState currentAnimatingState;

// TODO: remove numberOfAnimationFrames, have it be populated by templareURLs.count inside this initializer
- (instancetype)initWithTemplateURLs: (NSArray *)templateURLs numberOfAnimationFrames:(NSUInteger)numberOfAnimationFrames frameDuration:(NSTimeInterval)frameDuration;
- (void)startAnimating;
- (void)stopAnimating;
// TODO: What is the purpose of this?
- (void)flushTileCache;
- (void)fetchTilesForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, BOOL *stop))progressBlock completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;
// TODO: make this accept a animation frame index as a parameter, i.e. - (void)updateTilesToFrameIndex:(NSUInteger)animationFrameIndex;
- (void)updateImageTilesToCurrentTimeIndex;
- (MATAnimationTile *)tileForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;

@end
