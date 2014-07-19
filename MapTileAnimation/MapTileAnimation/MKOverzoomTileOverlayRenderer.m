//
//  MKOverzoomTileOverlayRenderer.m
//  MapTileAnimationDemo
//
//  Created by Matthew Sniff on 7/18/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "MKOverzoomTileOverlayRenderer.h"
#import "MATAnimatedTileOverlay.h"
#import "MATAnimationTile.h"

@implementation MKOverzoomTileOverlayRenderer

#pragma mark - Lifecycle

- (id) initWithOverlay:(id<MKOverlay>)overlay
{
	self = [super initWithOverlay:overlay];
	return self;
}

#pragma mark - Public methods

- (BOOL)canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale
{
    // We can ALWAYS draw a tile, even if the zoom scale/level is not supported by the tile server.
    // That's because we will draw a scaled version of the minimum/maximum supported tile.
    return YES;
}

/*
 even though this renderer and associated overlay are *NOT* tiled, drawMapRect gets called multilple times with each mapRect being a tiled region within the visibleMapRect. So MKMapKit drawing is tiled by design even though setNeedsDisplay is only called once.
 */
-(void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
{
    MKTileOverlay *mapOverlay = (MKTileOverlay *)self.overlay;
    
    //get x,y,z for tile
    NSUInteger aZoomLevel = [self zoomLevelForZoomScale: zoomScale];
    CGPoint mercatorPoint = [self mercatorTileOriginForMapRect: mapRect];
    int x,y,z = 0;
    x = floor(mercatorPoint.x * [self worldTileWidthForZoomLevel:aZoomLevel]);
    y = floor(mercatorPoint.y * [self worldTileWidthForZoomLevel:aZoomLevel]);
    z = aZoomLevel;
    
    //Store path for tile in struct for MKTileOverlay
    MKTileOverlayPath coordPaths;
    coordPaths.x = x;
    coordPaths.y = y;
    coordPaths.z = z;

    [mapOverlay loadTileAtPath:coordPaths result:^(NSData *tileData, NSError *error) {
        UIImage *image = [UIImage imageWithData:tileData];
        NSLog(@"test! %zd", image);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image) {
                CGRect rect = [self rectForMapRect: mapRect];
                UIGraphicsPushContext(context);
                [image drawInRect:rect blendMode:kCGBlendModeNormal alpha:0.75];
                UIGraphicsPopContext();
            }
        });
        
    }];
    
   /*
    NSInteger overZoom = 1;
    
    if (aZoomLevel > mapOverlay.maximumZ) {
        overZoom = pow(2, (aZoomLevel - mapOverlay.maximumZ));
        aZoomLevel = mapOverlay.maximumZ;
    }
    
    UIGraphicsPushContext(context);
    
    CGRect rect = [self rectForMapRect: mapRect];
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRect:CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
    [[UIColor blackColor] setStroke];
    bezierPath.lineWidth = CGRectGetHeight(rect) / 256;
    [bezierPath stroke];
    
    // Draw the tile coordinates in the upper left of the tile
    MATTileCoordinate c = [self tileCoordinateForMapRect:mapRect zoomScale:zoomScale];
    NSString *tileCoordinates = [NSString stringWithFormat:@"(%d, %d, %d)", c.x, c.y, c.z];
    [tileCoordinates drawInRect:rect withAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:CGRectGetHeight(rect) * .1] }];
    
    UIGraphicsPopContext();
    
    if (overZoom == 1) return;
     */
     
}

#pragma mark - Debug methods

/**
 * Similar to above, but uses a MKZoomScale to determine the
 * Mercator zoomLevel. (MKZoomScale is a ratio of screen points to
 * map points.)
 */
- (NSUInteger)zoomLevelForZoomScale:(MKZoomScale)zoomScale
{
    CGFloat realScale = zoomScale / [[UIScreen mainScreen] scale];
    NSUInteger z = (NSUInteger)(log(realScale)/log(2.0)+20.0);
	
    z += ([[UIScreen mainScreen] scale] - 1.0);
    return z;
}

- (MATTileCoordinate)tileCoordinateForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale
{
	MATTileCoordinate coord = {0, 0, 0};
	
	NSUInteger zoomLevel = [self zoomLevelForZoomScale: aZoomScale];
    CGPoint mercatorPoint = [self mercatorTileOriginForMapRect: aMapRect];
    NSUInteger tilex = floor(mercatorPoint.x * [self worldTileWidthForZoomLevel:zoomLevel]);
    NSUInteger tiley = floor(mercatorPoint.y * [self worldTileWidthForZoomLevel:zoomLevel]);
    
	coord.x = tilex;
	coord.y = tiley;
	coord.z = zoomLevel;
	
	return coord;
}

/*
 Determine the number of tiles wide *or tall* the world is, at the given zoomLevel.
 (In the Spherical Mercator projection, the poles are cut off so that the resulting 2D map is "square".)
 */
- (NSUInteger)worldTileWidthForZoomLevel:(NSUInteger)zoomLevel
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
- (CGPoint)mercatorTileOriginForMapRect:(MKMapRect)mapRect
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

@end
