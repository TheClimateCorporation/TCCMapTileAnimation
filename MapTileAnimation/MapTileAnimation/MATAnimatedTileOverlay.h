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


@interface MATAnimatedTileOverlay : NSObject <MKOverlay>

@property (weak, nonatomic) id<MATAnimatedTileOverlayDelegate>delegate;
@property (nonatomic) NSInteger currentFrameIndex;
@property (readonly, nonatomic) NSInteger numberOfAnimationFrames;
@property (readonly, nonatomic) MATAnimatingState currentAnimatingState;
@property (readonly) NSString *currentFrameTemplateURL;

- (instancetype) initWithTemplateURLs: (NSArray *)templateURLs frameDuration:(NSTimeInterval)frameDuration delegate: (id)aDelegate;
- (void)startAnimating;
- (void)stopAnimating;
- (void)fetchTilesForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, BOOL *stop))progressBlock completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

- (BOOL) updateToCurrentFrameIndex: (NSUInteger)currentFrameIndex;

- (void)updateImageTilesToFrameIndex: (NSUInteger)animationFrameIndex;
- (MATAnimationTile *)tileForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;

- (NSString *)templateURLStringForFrameIndex:(NSUInteger)animationFrameIndex;

@end
