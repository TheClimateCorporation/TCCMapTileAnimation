//
//  TCCTileOverlayHelpers.h
//  MapTileAnimationDemo
//
//  Created by Matthew Sniff on 7/23/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "TCCAnimationTile.h"

@interface TCCMapKitHelpers : NSObject

/**
 Returns a zoom level that corresponds to a given zoom scale.
 */
+ (NSUInteger)zoomLevelForZoomScale:(MKZoomScale)zoomScale;

/**
 Returns the x, y, and z coordinates of a map tile for a given map rect and zoom level.
 */
+ (MKTileOverlayPath)tilePathForMapRect:(MKMapRect)aMapRect zoomLevel:(NSInteger)zoomLevel;

/**
 Returns a map rect for a given map tile's x, y, and z coordinates.
 */
+ (MKMapRect)mapRectForTilePath:(MKTileOverlayPath)path;

/**
 Returns the width of a tile when the map is at a given zoom level
 */
+ (NSUInteger)worldTileWidthForZoomLevel:(NSUInteger)zoomLevel;

+ (CGPoint)mercatorTileOriginForMapRect:(MKMapRect)mapRect;

/**
 Draws debug information for a tiles
 */
+ (void)drawDebugInfoForX:(NSInteger)x Y:(NSInteger)y Z:(NSInteger)z color:(UIColor *)color inRect:(CGRect)rect context:(CGContextRef)context;

@end
