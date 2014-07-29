//
//  TCCTileOverlayHelpers.m
//  MapTileAnimationDemo
//
//  Created by Matthew Sniff on 7/23/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapKitHelpers.h"

@implementation TCCMapKitHelpers

+ (NSUInteger)zoomLevelForZoomScale:(MKZoomScale)zoomScale
{
    CGFloat realScale = zoomScale / [[UIScreen mainScreen] scale];
    NSUInteger z = (NSUInteger)(log(realScale)/log(2.0)+20.0);
	
    z += ([[UIScreen mainScreen] scale] - 1.0);
    return z;
}

+ (MKTileOverlayPath)tilePathForMapRect:(MKMapRect)aMapRect zoomLevel:(NSInteger)zoomLevel
{
    CGPoint mercatorPoint = [self mercatorTileOriginForMapRect:aMapRect];
    NSUInteger x = floor(mercatorPoint.x * [self worldTileWidthForZoomLevel:zoomLevel]);
    NSUInteger y = floor(mercatorPoint.y * [self worldTileWidthForZoomLevel:zoomLevel]);
    return (MKTileOverlayPath){x, y, zoomLevel};
}

+ (MKMapRect)mapRectForTilePath:(MKTileOverlayPath)path
{
    CGFloat xScale = (double)path.x / [self worldTileWidthForZoomLevel:path.z];
    CGFloat yScale = (double)path.y / [self worldTileWidthForZoomLevel:path.z];
    MKMapRect world = MKMapRectWorld;
    return MKMapRectMake(world.size.width * xScale,
                         world.size.height * yScale,
                         world.size.width / [self worldTileWidthForZoomLevel:path.z],
                         world.size.height / [self worldTileWidthForZoomLevel:path.z]);
}

/*
 Determine the number of tiles wide *or tall* the world is, at the given zoomLevel.
 (In the Spherical Mercator projection, the poles are cut off so that the resulting 2D map is "square".)
 */
+ (NSUInteger)worldTileWidthForZoomLevel:(NSUInteger)zoomLevel
{
    return (NSUInteger)(pow(2,zoomLevel));
}

/**
 * Given a MKMapRect, this reprojects the center of the mapRect
 * into the Mercator projection and calculates the rect's top-left point
 * (so that we can later figure out the tile coordinate).
 *
 * See http://wiki.openstreetmap.org/wiki/Slippy_map_tilenames#Derivation_of_tile_names
 */
+ (CGPoint)mercatorTileOriginForMapRect:(MKMapRect)mapRect
{
    MKCoordinateRegion region = MKCoordinateRegionForMapRect(mapRect);
    
    // Convert lat/lon to radians
    CGFloat x = (region.center.longitude) * (M_PI/180.0); // Convert lon to radians
    CGFloat y = (region.center.latitude) * (M_PI/180.0); // Convert lat to radians
    y = log(tan(y)+1.0/cos(y));
    
    // X and Y should actually be the top-left of the rect (the values above represent
    // the center of the rect)
    x = (1.0 + (x/M_PI)) / 2.0;
    y = (1.0 - (y/M_PI)) / 2.0;
	
    return CGPointMake(x, y);
}

+ (void)drawDebugInfoForX:(NSInteger)x Y:(NSInteger)y Z:(NSInteger)z color:(UIColor *)color inRect:(CGRect)rect context:(CGContextRef)context
{
    UIGraphicsPushContext(context);
    
    NSString *tileCoordinates = [NSString stringWithFormat:@"(%ld, %ld, %ld)", (long)x, (long)y, (long)z];
    [tileCoordinates drawInRect:rect withAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:CGRectGetHeight(rect) * .1], NSForegroundColorAttributeName : color }];
    
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRect:CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
    [color setStroke];
    // TODO: Should be divided by the tile size
    bezierPath.lineWidth = CGRectGetHeight(rect) / 256;
    [bezierPath stroke];
    
    UIGraphicsPopContext();
}

@end
