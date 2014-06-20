//
//  MATAnimatedTileOverlay.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface MATAnimatedTileOverlay : NSObject <MKOverlay>

@property (nonatomic, assign) NSInteger numberOfAnimationFrames;
@property (readwrite, assign) NSInteger currentTimeIndex;
@property (readwrite, assign) NSInteger tileSize;

@property (readwrite, strong) NSArray *mapTiles;

- (id) initWithTemplateURLs: (NSArray *)templateURLs numberOfAnimationFrames:(NSUInteger)numberOfAnimationFrames frameDuration:(NSTimeInterval)frameDuration;

- (void) cancelAllOperations;

- (void) fetchTilesForMapRect: (MKMapRect)aMapRect zoomScale: (MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, NSError *error))progressBlock completionBlock: (void (^)(BOOL success, NSError *error))completionBlock;

- (void) updateImageTilesToCurrentTimeIndex;

@end
