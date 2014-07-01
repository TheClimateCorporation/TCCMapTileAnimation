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

typedef struct
{
	NSUInteger xCoordinate;
	NSUInteger yCoordinate;
	NSUInteger zCoordiante;
} MATTileCoordinate;

typedef NS_ENUM(BOOL, MATAnimating) {
	kIsAnimating = YES,
	kStopped = NO
};

@interface MATAnimatedTileOverlay : NSObject <MKOverlay>

@property (nonatomic, weak) id<MATAnimatedTileOverlayDelegate>delegate;
@property (nonatomic, assign) NSInteger numberOfAnimationFrames;
@property (readwrite, assign) NSInteger currentTimeIndex;
@property (readwrite, assign) NSInteger tileSize;

@property (readwrite, strong) NSSet *mapTiles;
@property (readonly) MATAnimating animating;

- (id) initWithTemplateURLs: (NSArray *)templateURLs numberOfAnimationFrames:(NSUInteger)numberOfAnimationFrames frameDuration:(NSTimeInterval)frameDuration;

- (void) startAnimating;
- (void) stopAnimating;

- (void) flushTileCache;
- (void) cancelAllOperations;

- (void) fetchTilesForMapRect: (MKMapRect)aMapRect zoomScale: (MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, BOOL *stop))progressBlock completionBlock: (void (^)(BOOL success, NSError *error))completionBlock;

- (void) updateImageTilesToCurrentTimeIndex;

- (MATTileCoordinate) tileCoordianteForMapRect: (MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;

- (MATAnimationTile *) tileForMapRect: (MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;
@end
