//
//  TCCMapTileRenderer.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "MATAnimatedTileOverlayRenderer.h"
#import "MATAnimatedTileOverlay.h"
#import "MATAnimationTile.h"

@implementation MATAnimatedTileOverlayRenderer

#pragma mark - Lifecycle

- (id) initWithOverlay:(id<MKOverlay>)overlay
{
	self = [super initWithOverlay:overlay];
	if (self)
	{
        if (![overlay isKindOfClass:[MATAnimatedTileOverlay class]]) {
            [NSException raise:@"Unsupported overlay type" format:@"Must be MATAnimatedTileOverlay"];
        }
	}
	return self;
}

#pragma mark - Public methods

- (BOOL)canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale
{
    self.zoomScale = zoomScale;
    // We can ALWAYS draw a tile, even if the zoom scale/level is not supported by the tile server.
    // That's because we will draw a scaled version of the minimum/maximum supported tile.
    return YES;
}

/*
 even though this renderer and associated overlay are *NOT* tiled, drawMapRect gets called multilple times with each mapRect being a tiled region within the visibleMapRect. So MKMapKit drawing is tiled by design even though setNeedsDisplay is only called once.
 */
-(void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
{
    MATAnimatedTileOverlay *mapOverlay = (MATAnimatedTileOverlay *)self.overlay;
    MATAnimationTile *tile = [mapOverlay tileForMapRect:mapRect zoomScale:zoomScale];
	if (tile) {
		CGRect rect = [self rectForMapRect: mapRect];
		UIImage *image = tile.currentImageTile;
		UIGraphicsPushContext(context);
		[image drawInRect:rect blendMode:kCGBlendModeNormal alpha:0.75];
		UIGraphicsPopContext();
	}
    
    NSInteger zoomLevel = [self zoomLevelForZoomScale:zoomScale];
    NSInteger overZoom = 1;
    
    if (zoomLevel > mapOverlay.maximumZ) {
        overZoom = pow(2, (zoomLevel - mapOverlay.maximumZ));
        zoomLevel = mapOverlay.maximumZ;
    }
    
    /* Debug information */
    UIGraphicsPushContext(context);

    CGRect rect = [self rectForMapRect: mapRect];
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRect:CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
    [[UIColor blackColor] setStroke];
    bezierPath.lineWidth = CGRectGetHeight(rect) / 256;
    [bezierPath stroke];

    // Draw the tile coordinates in the upper left of the tile
    MATTileCoordinate c = [self tileCoordinateForMapRect:mapRect zoomScale:zoomScale];
    NSString *tileCoordinates = [NSString stringWithFormat:@"(%d, %d, %d)", c.xCoordinate, c.yCoordinate, c.zCoordinate];
    [tileCoordinates drawInRect:rect withAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:CGRectGetHeight(rect) * .1] }];
    
    UIGraphicsPopContext();
    
    if (overZoom == 1) return;
    
    NSArray *tiles = [mapOverlay tilesForMapRect:mapRect zoomScale:zoomScale];

    //tile drawing
    for (MATAnimationTile *tile in tiles) {
        // For each image tile, draw it in its corresponding MKMapRect frame
        CGRect rect = [self rectForMapRect:tile.mapRectFrame];
        if (!MKMapRectIntersectsRect(mapRect, tile.mapRectFrame)) continue;
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
        
        // OverZoom mode - 1 when using tiles as is, 2, 4, 8 etc when overzoomed.
        CGContextScaleCTM(context, overZoom/zoomScale, overZoom/zoomScale);
        CGContextTranslateCTM(context, 0, tile.currentImageTile.size.height);
        CGContextScaleCTM(context, 1, -1);
        CGContextDrawImage(context, CGRectMake(0, 0, tile.currentImageTile.size.width, tile.currentImageTile.size.height), [tile.currentImageTile CGImage]);
        
        // TODO: burn debug info into image!
        NSString *tileCoordinates = [NSString stringWithFormat:@"(%d, %d, %d)", tile.xCoordinate, tile.yCoordinate, tile.zCoordinate];
        [tileCoordinates drawInRect:rect withAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:100000] }];
        
        CGContextRestoreGState(context);
    }
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
    
	coord.xCoordinate = tilex;
	coord.yCoordinate = tiley;
	coord.zCoordinate = zoomLevel;
	
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
