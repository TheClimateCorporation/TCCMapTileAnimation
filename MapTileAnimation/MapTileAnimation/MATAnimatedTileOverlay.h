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

@protocol MATAnimatedTileOverlayDelegate;

@interface MATAnimatedTileOverlay : NSObject <MKOverlay>

//any object conforming to MATAnimatedTileOverlayDelegate protocol
@property (weak, nonatomic) id<MATAnimatedTileOverlayDelegate>delegate;
@property (nonatomic) NSInteger currentFrameIndex;
@property (nonatomic) NSInteger currentPausedFrameIndex;
@property (readonly, nonatomic) NSInteger numberOfAnimationFrames;
@property (readonly, nonatomic) MATAnimatingState currentAnimatingState;
@property (nonatomic, readwrite, assign) NSInteger minimumZ;
@property (nonatomic, readwrite, assign) NSInteger maximumZ;

- (instancetype)initWithTemplateURLs:(NSArray *)templateURLs frameDuration:(NSTimeInterval)frameDuration;

- (void)startAnimating;

- (void)pauseAnimating;

- (void)fetchTilesForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, BOOL *stop))progressBlock completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

- (void)updateImageTilesToFrameIndex: (NSUInteger)animationFrameIndex;

- (MATAnimationTile *)tileForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;

- (NSString *)templateURLStringForFrameIndex: (NSUInteger)animationFrameIndex;

@end
