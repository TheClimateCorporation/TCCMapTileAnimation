//
//  TCCAnimationTileOverlay.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>

@class TCCAnimationTile;

typedef NS_ENUM(NSUInteger, TCCAnimationState) {
	TCCAnimationStateStopped = 0,
	TCCAnimationStateLoading,
	TCCAnimationStateAnimating
};

typedef NS_ENUM(NSUInteger, TCCAnimationTileOverlayError) {
	TCCAnimationTileOverlayErrorInvalidZoomLevel = 1001,
	TCCAnimationTileOverlayErrorBadURLResponseCode,
	TCCAnimationTileOverlayErrorNoImageData,
    TCCAnimationTileOverlayErrorNoFrames
};

extern NSString *const TCCAnimationTileOverlayErrorDomain;

@protocol TCCAnimationTileOverlayDelegate;


/**
 A map overlay class that adheres to the @c MKOverlay protocol.
 */

@interface TCCAnimationTileOverlay : NSObject <MKOverlay>

@property (weak, nonatomic) id <TCCAnimationTileOverlayDelegate> delegate;
@property (nonatomic) NSInteger currentFrameIndex;
@property (readonly, nonatomic) NSInteger numberOfAnimationFrames;
@property (readonly, nonatomic) TCCAnimationState currentAnimationState;
@property (nonatomic) NSInteger minimumZ;
@property (nonatomic) NSInteger maximumZ;
@property (nonatomic) NSInteger tileSize;

- (instancetype)initWithMapView:(MKMapView *)mapView templateURLs:(NSArray *)templateURLs frameDuration:(NSTimeInterval)frameDuration;

/**
 Begins animating the tile overlay, starting from the current frame index.
 */
- (void)startAnimating;

/**
 Pauses animation at the current frame index.
 */
- (void)pauseAnimating;

- (void)cancelLoading;

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
             progressHandler:(void(^)(NSUInteger currentFrameIndex))progressHandler
           completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;

/**
 For a given map rect that corresponds to the area of a tile, this returns the @c MATAnimationTile
 object that contains the tile image data.
 
 Returns @c nil if a fetch operation has not executed for this tile.
 */
- (TCCAnimationTile *)tileForMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)mapRect;

/**
 Returns an array of @c MATAnimationTile objects that have been fetched and cached for a given
 map rect.
 */
- (NSArray *)cachedTilesForMapRect:(MKMapRect)rect;

@end


/**
 @protocol Delegate protocol for TCCAnimationTileOverlay to send back when significant events occur.
 */

@protocol TCCAnimationTileOverlayDelegate <NSObject>

@required

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didChangeFromAnimationState:(TCCAnimationState)previousAnimationState toAnimationState:(TCCAnimationState)currentAnimationState;

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex;

@optional

// Does not stop the fetching of other images, could have multiple errors
- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didHaveError:(NSError *) error;

@end
