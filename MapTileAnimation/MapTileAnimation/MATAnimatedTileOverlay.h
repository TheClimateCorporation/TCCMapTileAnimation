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

- (instancetype)initWithMapView:(MKMapView *)mapView templateURLs:(NSArray *)templateURLs frameDuration:(NSTimeInterval)frameDuration;

/**
 Begins animating the tile overlay, starting from the current frame index.
 */
- (void)startAnimating;

/**
 Pauses animation at the current frame index.
 */
- (void)pauseAnimating;

/**
 Moves the overlay's animated tile data to the given frame index. If it is currently animating,
 it pauses animation. Throws exception if out of bounds.
 
 @param frameIndex The animation frame index to move to
 @param isContinuouslyMoving A boolean flag to indicate whether the user is currently scrubbing
 through the animation frames. Passing @c YES suppresses the switch to using the @c MKTileOverlay.
 */
- (void)moveToFrameIndex:(NSInteger)frameIndex isContinuouslyMoving:(BOOL)isContinuouslyMoving;

/**
 Begins fetching the tiles from the tile server.
 
 @param mapRect The current visible rect of the map view.
 @param zoomScale The current zoom scale of the map view.
 @param progressHandler Invoked after each frame of animation has loaded. Set the @c stop boolean
 flag if you want to cancel the fetch operation. If you want the overlay to display updated tile
 data as it loads, you can call @c moveToFrameIndex from here.
 @param completionHandler Called when all the data has loaded. @c success is YES when the
 user has not cancelled loading. @c error is not currently used...
 */
- (void)fetchTilesForMapRect:(MKMapRect)mapRect
                   zoomScale:(MKZoomScale)zoomScale
             progressHandler:(void(^)(NSUInteger currentFrameIndex, BOOL *stop))progressHandler
           completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;

/**
 For a given map rect that corresponds to the area of a tile, this returns the @c MATAnimationTile
 object that contains the tile image data.
 
 Returns @c nil if a fetch operation has not executed for this tile.
 */
- (MATAnimationTile *)tileForMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)mapRect;

/**
 Returns an array of @c MATAnimationTile objects that have been fetched and cached for a given
 map rect.
 */
- (NSArray *)cachedTilesForMapRect:(MKMapRect)rect;

@end
