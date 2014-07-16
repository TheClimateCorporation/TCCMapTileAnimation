//
//  MATAnimatedTileOverlay.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "TCCMapViewController.h"

@class MATAnimationTile;

typedef NS_ENUM(NSUInteger, MATAnimatingState) {
	MATAnimatingStateStopped = 0,
	MATAnimatingStateLoading = 1,
	MATAnimatingStateAnimating = 2
};

typedef NS_ENUM(NSUInteger, MATAnimatingErrorCode) {
	MATAnimatingErrorInvalidZoomLevel = 1001,
	MATAnimatingErrorBadURLResponseCode,
	MATAnimatingErrorNoImageData
    
};

extern NSString *const MATAnimatedTileOverlayErrorDomain;

@protocol MATAnimatedTileOverlayDelegate;

@interface MATAnimatedTileOverlay : NSObject <MKOverlay>

//any object conforming to MATAnimatedTileOverlayDelegate protocol
@property (weak, nonatomic) id<MATAnimatedTileOverlayDelegate>delegate;
@property (nonatomic) NSInteger currentFrameIndex;
@property (readonly, nonatomic) NSInteger numberOfAnimationFrames;
@property (readonly, nonatomic) MATAnimatingState currentAnimatingState;
@property (nonatomic) NSInteger minimumZ;
@property (nonatomic) NSInteger maximumZ;

- (instancetype)initWithTemplateURLs:(NSArray *)templateURLs frameDuration:(NSTimeInterval)frameDuration mapView:(MKMapView *)mapView;

/**
 Begins animating the tile overlay, starting from the current frame index.
 */
- (void)startAnimating;

/**
 Pauses animation at the current frame index
 */
- (void)pauseAnimating;

/**
 Updates the overlay's underlying tile data to the given frame index. Throws exception if out of bounds.
 If the tile overlay is currently animating, it pauses animation.
 @param frameIndex The animation frame index to move to
 @param isContinuouslyMoving A boolean flag to indicate whether the user is currently scrubbing through
 the animation frames. Passing @c YES suppresses the switch to using the @c MKTileOverlay.
 */
- (void)moveToFrameIndex:(NSInteger)frameIndex isContinuouslyMoving:(BOOL)isContinuouslyMoving;

- (void)fetchTilesForMapRect:(MKMapRect)aMapRect
                   zoomScale:(MKZoomScale)aScale
               progressBlock:(void(^)(NSUInteger currentTimeIndex, BOOL *stop))progressBlock
             completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

- (MATAnimationTile *)tileForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;

- (NSSet *)mapTilesInMapRect:(MKMapRect)aRect zoomScale:(MKZoomScale)zoomScale;

@end
