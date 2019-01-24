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
    TCCAnimationStateAnimating,
    TCCAnimationStateScrubbing
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
@interface TCCAnimationTileOverlay : MKTileOverlay <MKOverlay>
/**
 The delegate for this overlay.
 */
@property (weak, nonatomic) id <TCCAnimationTileOverlayDelegate> delegate;
/**
 The current frame's index, from 0 to N-1, where N is the total number of frames.
 */
@property (nonatomic) NSInteger currentFrameIndex;
/**
 The total number of frames.
 */
@property (readonly, nonatomic) NSInteger numberOfAnimationFrames;
/**
 The current animation state of the overlay
 */
@property (readonly) TCCAnimationState currentAnimationState;
/**
 Array of @c NSString objects
 */
@property (strong, nonatomic) NSArray *templateURLs;

/**
 Designated initializer.
 @param templateURLs An array of @c NSString objects, one for each frame of animation. The strings
 are template URLs to the tile and should have @c {x}, @c {y}, and @c {z} to indicate the x, y, and
 z coordinates for the tile.
 @param frameDuration The number of seconds to display each frame of animation
 @param minimumZ The minimum zoom level of tiles supported by the tile server.
 @param maximumZ The maximum zoom level of tiles supported by the tile server.
 @param tileSize The @c CGSize that represents the size of the tile images from the tile server.
 */
- (instancetype)initWithTemplateURLs:(NSArray *)templateURLs
                       frameDuration:(NSTimeInterval)frameDuration
                            minimumZ:(NSInteger)minimumZ
                            maximumZ:(NSInteger)maximumZ
                            tileSize:(CGSize)tileSize;

/**
 Designated initializer.
 @param templateURLs An array of @c NSString objects, one for each frame of animation. The strings
 are template URLs to the tile and should have @c {x}, @c {y}, and @c {z} to indicate the x, y, and
 z coordinates for the tile.
 @param configuration The session configuration to use for tile calls, each tile image will be called with the headers supplied by the configuration.
 @param frameDuration The number of seconds to display each frame of animation
 @param minimumZ The minimum zoom level of tiles supported by the tile server.
 @param maximumZ The maximum zoom level of tiles supported by the tile server.
 @param tileSize The @c CGSize that represents the size of the tile images from the tile server.
 */
- (instancetype)initWithTemplateURLs:(NSArray *)templateURLs
                       configuration:(NSURLSessionConfiguration *)configuration
                       frameDuration:(NSTimeInterval)frameDuration
                            minimumZ:(NSInteger)minimumZ
                            maximumZ:(NSInteger)maximumZ
                            tileSize:(CGSize)tileSize;

/**
 Begins animating the tile overlay, starting from the current frame index.
 */
- (void)startAnimating;

/**
 Pauses animation at the current frame index.
 */
- (void)pauseAnimating;

/**
 Cancels any pending tile loading operations caused by @c
 fetchTileForMapRect:zoomLevel:progressHandler:completionBlock:.
 */
- (void)cancelLoading;

/**
 Moves the overlay's animated tile data to the given frame index, and calls the delegate method
 @c animationTileOverlay:didAnimateWithAnimationFrameIndex: afterwards.
 
 If it is currently animating, it pauses animation. If @c isContinuouslyMoving is @c YES, it
 sets the current animation state to @c TCCAnimationStateScrubbing. This is because the animation
 renderer uses two different method of retrieving tiles based on whether the current animation state
 of the overlay is stopped (uses static tiles with async loadTileAtPath) or scrubbing/animating
 (uses cached animation tiles synchronously). If we don't set this to scrubbing and let it
 be stopped, the rendering has a noticeable flicker due to the async nature of loading tiles.
 
 @param frameIndex The animation frame index to move to. Throws exception if out of bounds.
 @param isContinuouslyMoving A boolean flag to indicate whether the user is currently scrubbing
 through the animation frames. Passing @c YES changes the overlay to animation state
 @c TCCAnimationStateScrubbing.
 */
- (void)moveToFrameIndex:(NSInteger)frameIndex isContinuouslyMoving:(BOOL)isContinuouslyMoving;

/**
 Returns @c YES if the overlay has valid tile data ready to be animated for the current map
 rect and zoom level.
 */
- (BOOL)canAnimateForMapRect:(MKMapRect)rect zoomLevel:(NSInteger)zoomLevel;

/**
 Begins fetching the tiles from the tile server.
 
 @param mapRect The current visible rect of the map view.
 @param zoomLevel The zoom level of the tiles to fetch.
 @param progressHandler Invoked after each frame of animation has loaded. Set the @c stop boolean
 flag if you want to cancel the fetch operation. If you want the overlay to display updated tile
 data as it loads, you can call @c moveToFrameIndex from here.
 @param completionHandler Called when all the data has loaded. @c success is YES when the
 user has not cancelled loading. @c error is not currently used...
 */
- (void)fetchTilesForMapRect:(MKMapRect)mapRect
                   zoomLevel:(NSUInteger)zoomLevel
             progressHandler:(void(^)(NSUInteger loadedFrameIndex))progressHandler
           completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;

/**
 For a given map rect that corresponds to the area of a tile, this returns the @c MATAnimationTile
 object that contains the tile image data.
 
 Returns @c nil if a fetch operation has not executed for this map
 rect and zoom level.
 */
- (TCCAnimationTile *)animationTileForMapRect:(MKMapRect)mapRect zoomLevel:(NSUInteger)zoomLevel;

/**
 Returns a tile object for a given map rect and zoom level. Guaranteed
 not to be @c nil.The tile may have its @c tileImage property already set
 to a valid tile image if the tile has been retrieved previously, but
 this is not guaranteed, so please check the @c tileImage property for
 @c nil before using.
 */
- (TCCAnimationTile *)staticTileForMapRect:(MKMapRect)mapRect zoomLevel:(NSUInteger)zoomLevel;

/**
 Returns an array of @c TCCAnimationTile objects that have been fetched and cached for a given
 map rect. Should only be used to retrieve a collection of map tiles for
 use by the renderer to render overzoomed tiles.
 */
- (NSArray *)cachedTilesForMapRect:(MKMapRect)rect zoomLevel:(NSUInteger)zoomLevel;

/**
 Returns an array of @c TCCAnimationTile objects that have already
 been fetched and cached for a given map rect. Should only be used
 to retrieve a collection of map tiles for use by the renderer to
 render overzoomed tiles.
 */
- (NSArray *)cachedStaticTilesForMapRect:(MKMapRect)rect zoomLevel:(NSUInteger)zoomLevel;

@end


/**
 @protocol Delegate protocol for TCCAnimationTileOverlay to send back when significant events occur.
 */

@protocol TCCAnimationTileOverlayDelegate <NSObject>

@required

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didChangeFromAnimationState:(TCCAnimationState)previousAnimationState toAnimationState:(TCCAnimationState)currentAnimationState;

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex;

@optional

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didHaveError:(NSError *) error;

@end
