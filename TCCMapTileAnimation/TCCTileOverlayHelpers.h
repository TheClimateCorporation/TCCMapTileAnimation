//
//  TCCTileOverlayHelpers.h
//  MapTileAnimationDemo
//
//  Created by Matthew Sniff on 7/23/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "TCCAnimationTile.h"

@interface TCCTileOverlayHelpers : MKTileOverlayRenderer

+ (NSUInteger)zoomLevelForZoomScale:(MKZoomScale)zoomScale;
+ (TCCTileCoordinate)tileCoordinateForMapRect:(MKMapRect)aMapRect zoomLevel:(NSInteger)zoomLevel;
+ (MKMapRect)mapRectForTileCoordinate:(TCCTileCoordinate)coordinate;
+ (NSUInteger)worldTileWidthForZoomLevel:(NSUInteger)zoomLevel;
+ (CGPoint)mercatorTileOriginForMapRect:(MKMapRect)mapRect;

@end
