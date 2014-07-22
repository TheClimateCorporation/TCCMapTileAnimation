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

@interface MKOverzoomTileOverlayRenderer ()
@property (strong, nonatomic) NSMutableSet *tileSet;
@end

@implementation MKOverzoomTileOverlayRenderer

#pragma mark - Lifecycle

- (id) initWithOverlay:(id<MKOverlay>)overlay
{
	self = [super initWithOverlay:overlay];
    if (self) {
        _tileSet = [NSMutableSet set];
    }
	return self;
}

#pragma mark - Public methods

- (BOOL)canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale
{
    
    // get map overlay
    MKTileOverlay *mapOverlay = (MKTileOverlay *)self.overlay;
    
    // get zoom level
    NSUInteger aZoomLevel = [self zoomLevelForZoomScale: zoomScale];
    NSUInteger oldZoomLevel = [self zoomLevelForZoomScale: zoomScale];

    // cap aZoomLevel
    if(aZoomLevel > mapOverlay.maximumZ) {
        aZoomLevel = mapOverlay.maximumZ;
    }
    if(aZoomLevel < mapOverlay.minimumZ) {
        aZoomLevel = mapOverlay.minimumZ;
    }

    // empty tileDict if new zoom level is different than last zoom level
    if(aZoomLevel != self.lastZoomLevel) {
        [self.tileSet removeAllObjects];
        
        // set zoom level property
        self.lastZoomLevel = aZoomLevel;
    }
    
    // Create coord struct with proper values of x, y, z at zoom level
    MATTileCoordinate coord = [self tileCoordinateForMapRect:mapRect zoomLevel:aZoomLevel];
    
    // Store path for tile in struct for MKTileOverlay
    MKTileOverlayPath coordPaths;
    coordPaths.x = coord.x;
    coordPaths.y = coord.y;
    coordPaths.z = coord.z;
    
    // create tile, passed x, y, and capped z
    MATAnimationTile *tile = [[MATAnimationTile alloc] initWithFrame:mapRect x:coordPaths.x y:coordPaths.y z:oldZoomLevel];

    // check if tile is in dictionary, if so we return YES to render it with drawMapRect
    if([self.tileSet containsObject:tile]) {
        return YES;
    }
    
    // else, return NO and go and fetch tile data with loadTileAtPath and store in tilesDict.
    // grab main thread and call setNeedsDisplay to render tile on screen with drawMapRect
    else {
        [mapOverlay loadTileAtPath:coordPaths result:^(NSData *tileData, NSError *error) {
            
            tile.tileImage = [UIImage imageWithData:tileData];
            [self.tileSet addObject:tile];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self setNeedsDisplayInMapRect:mapRect zoomScale:zoomScale];
            });
            
        }];
        return NO;
 
    }
    
}

/*
 even though this renderer and associated overlay are *NOT* tiled, drawMapRect gets called multilple times with each mapRect being a tiled region within the visibleMapRect. So MKMapKit drawing is tiled by design even though setNeedsDisplay is only called once.
 */
-(void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
{

    // get map overlay
    MATAnimatedTileOverlay *mapOverlay = (MATAnimatedTileOverlay *)self.overlay;
    
    // get zoom level
    NSUInteger aZoomLevel = [self zoomLevelForZoomScale: zoomScale];
    
    // overzoom is 1 by default, get zoom level from zoom scale
    NSInteger overZoom = 1;
    
    // calculate amount of overzoom
    if (aZoomLevel > mapOverlay.maximumZ) {
        overZoom = pow(2, (aZoomLevel - mapOverlay.maximumZ));
        aZoomLevel = mapOverlay.maximumZ;
    }
    
    // cap zoom level
    if(aZoomLevel < mapOverlay.minimumZ) {
        aZoomLevel = mapOverlay.minimumZ;
    }
    if(aZoomLevel > mapOverlay.maximumZ) {
        aZoomLevel = mapOverlay.maximumZ;
    }
    
    // get x ,y, z coords for tile
    CGPoint mercatorPoint = [self mercatorTileOriginForMapRect: mapRect];
    int x = floor(mercatorPoint.x * [self worldTileWidthForZoomLevel:aZoomLevel]);
    int y = floor(mercatorPoint.y * [self worldTileWidthForZoomLevel:aZoomLevel]);
    int z = aZoomLevel;
    
    // grab tile from set
    MATAnimationTile *tile;
    for (MATAnimationTile *tileInd in self.tileSet) {
        if (x == tileInd.x && y == tileInd.y && z == tileInd.z) {
            tile = tileInd;
        }
    }

    // if no overzoom
    if (overZoom == 1) {
        
        CGRect rect = [self rectForMapRect: mapRect];
        UIImage *image = tile.tileImage;
        UIGraphicsPushContext(context);
        [image drawInRect:rect blendMode:kCGBlendModeNormal alpha:0.75];
        UIGraphicsPopContext();
        
    }

    // map is overzoomed
    else {
        
        CGRect rect = [self rectForMapRect:tile.mapRectFrame];
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
        
        // OverZoom mode - 1 when using tiles as is, 2, 4, 8 etc when overzoomed.
        CGContextScaleCTM(context, overZoom/zoomScale, overZoom/zoomScale);
        CGContextTranslateCTM(context, 0, tile.tileImage.size.height);
        CGContextScaleCTM(context, 1, -1);
        CGContextDrawImage(context, CGRectMake(0, 0, tile.tileImage.size.width, tile.tileImage.size.height), [tile.tileImage CGImage]);
        CGContextRestoreGState(context);
        
        
        UIGraphicsPushContext(context);
        NSString *tileCoordinates = [NSString stringWithFormat:@"(%d, %d, %d)", tile.x, tile.y, tile.z];
        [tileCoordinates drawInRect:rect withAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:CGRectGetHeight(rect) * .1] }];
        
        UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRect:CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
        [[UIColor blueColor] setStroke];
        bezierPath.lineWidth = CGRectGetHeight(rect) / 256;
        [bezierPath stroke];
        
        UIGraphicsPopContext();
        
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

- (MATTileCoordinate)tileCoordinateForMapRect:(MKMapRect)aMapRect zoomLevel:(NSInteger)zoomLevel
{
	MATTileCoordinate coord = {0, 0, 0};
	
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
