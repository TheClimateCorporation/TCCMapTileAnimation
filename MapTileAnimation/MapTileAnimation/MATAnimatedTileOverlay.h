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

// TODO: put this into its own header file, have MATAnimationTile use this
typedef struct
{
	NSUInteger xCoordinate;
	NSUInteger yCoordinate;
	NSUInteger zCoordiante;
} MATTileCoordinate;

// TODO: rename to use proper enum convention
typedef NS_ENUM(NSUInteger, MATAnimatingState) {
	MATAnimatingState_stopped = 0,
	MATAnimatingState_loading = 1,
	MATAnimatingState_animating = 2
};

@interface MATAnimatedTileOverlay : NSObject <MKOverlay>

@property (weak, nonatomic) id<MATAnimatedTileOverlayDelegate>delegate;
@property (readonly, nonatomic) NSInteger numberOfAnimationFrames;
// TODO: make it currentFrameIndex
@property (nonatomic) NSInteger currentTimeIndex;
@property (readonly, nonatomic) MATAnimatingState currentAnimatingState;
// TODO: Make it private
@property (nonatomic) NSInteger tileSize;
// TODO: make it private
@property (strong, nonatomic) NSSet *mapTiles;

// TODO: remove numberOfAnimationFrames, have it be populated by templareURLs.count inside this initializer
- (instancetype)initWithTemplateURLs: (NSArray *)templateURLs numberOfAnimationFrames:(NSUInteger)numberOfAnimationFrames frameDuration:(NSTimeInterval)frameDuration;
- (void)startAnimating;
- (void)stopAnimating;
// TODO: What is the purpose of this?
- (void)flushTileCache;
// TODO: make this private
- (void)cancelAllOperations;
- (void)fetchTilesForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, BOOL *stop))progressBlock completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;
// TODO: make this accept a animation frame index as a parameter, i.e. - (void)updateTilesToFrameIndex:(NSUInteger)animationFrameIndex;
- (void)updateImageTilesToCurrentTimeIndex;
// TODO: make this private
- (MATTileCoordinate)tileCoordinateForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;
- (MATAnimationTile *)tileForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;

@end
