//
//  TCCOverzoomTileOverlayRenderer.m
//  MapTileAnimationDemo
//
//  Created by Matthew Sniff on 7/18/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCOverzoomTileOverlayRenderer.h"
#import "TCCAnimationTileOverlay.h"
#import "TCCAnimationTile.h"
#import "TCCMapKitHelpers.h"

@interface TCCOverzoomTileOverlayRenderer ()
@property (nonatomic) NSUInteger lastZoomLevel;
@property (strong, nonatomic) NSMutableSet *tileSet;
@property (strong, nonatomic) NSLock *tileSetLock;
@end

@implementation TCCOverzoomTileOverlayRenderer

#pragma mark - Lifecycle

- (id) initWithOverlay:(id<MKOverlay>)overlay
{
	self = [super initWithOverlay:overlay];
    if (self) {
        _tileSet = [NSMutableSet set];
        _tileSetLock = [[NSLock alloc] init];
    }
	return self;
}

#pragma mark - Public methods

- (BOOL)canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale
{
    MKTileOverlay *mapOverlay = (MKTileOverlay *)self.overlay;
    
    // Get current zoom level, and cap if necessary
    NSUInteger currentZoomLevel = [TCCMapKitHelpers zoomLevelForZoomScale: zoomScale];
    if (currentZoomLevel > mapOverlay.maximumZ) {
        currentZoomLevel = mapOverlay.maximumZ;
    }
    if (currentZoomLevel < mapOverlay.minimumZ) {
        currentZoomLevel = mapOverlay.minimumZ;
    }

    // empty tileSet if new zoom level is different than last zoom level
    if (currentZoomLevel != self.lastZoomLevel) {
        [self.tileSetLock lock];
        [self.tileSet removeAllObjects];
        [self.tileSetLock unlock];
        
        // set zoom level property
        self.lastZoomLevel = currentZoomLevel;
    }
    
    // Create coord struct with proper values of x, y, z at zoom level
//    MATTileCoordinate coord = [self tileCoordinateForMapRect:mapRect zoomLevel:oldZoomLevel];
//    NSLog(@"Uncapped MATTileCoordinate is (%d, %d, %d)", coord.x, coord.y, coord.z);
    TCCTileCoordinate coord = [TCCMapKitHelpers tileCoordinateForMapRect:mapRect zoomLevel:currentZoomLevel];
//    NSLog(@"Capped MATTileCoordinate is (%d, %d, %d)", coord.x, coord.y, coord.z);

    
    // Store path for tile in struct for MKTileOverlay
    MKTileOverlayPath coordPaths;
    coordPaths.x = coord.x;
    coordPaths.y = coord.y;
    coordPaths.z = coord.z;
    
    MKMapRect cappedMapRect = [TCCMapKitHelpers mapRectForTileCoordinate:coord];
//    NSLog(@"Capped map rect is (%f, %f), (%f, %f)", cappedMapRect.origin.x, cappedMapRect.origin.y, cappedMapRect.size.width, cappedMapRect.size.height);
    
    // create tile, passed x, y, and capped z
    TCCAnimationTile *tile = [[TCCAnimationTile alloc] initWithFrame:cappedMapRect x:coordPaths.x y:coordPaths.y z:currentZoomLevel];

    // check if tile is in dictionary, if so we return YES to render it with drawMapRect
    [self.tileSetLock lock];
    BOOL tileSetHasTile = [self.tileSet containsObject:tile];
    [self.tileSetLock unlock];
    if (tileSetHasTile) {
        return YES;
    }
    
    // else, return NO and go and fetch tile data with loadTileAtPath and store in tilesDict.
    // grab main thread and call setNeedsDisplay to render tile on screen with drawMapRect
    [mapOverlay loadTileAtPath:coordPaths result:^(NSData *tileData, NSError *error) {
        if (tile.z != self.lastZoomLevel) return;

        tile.tileImage = [UIImage imageWithData:tileData];
        [self.tileSetLock lock];
        [self.tileSet addObject:tile];
        [self.tileSetLock unlock];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNeedsDisplayInMapRect:mapRect zoomScale:zoomScale];
        });
    }];
    return NO;
}

/*
 even though this renderer and associated overlay are *NOT* tiled, drawMapRect gets called multilple times with each mapRect being a tiled region within the visibleMapRect. So MKMapKit drawing is tiled by design even though setNeedsDisplay is only called once.
 */
-(void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
{
    // get map overlay
    TCCAnimationTileOverlay *mapOverlay = (TCCAnimationTileOverlay *)self.overlay;
    
    // get zoom level
    NSUInteger currentZoomLevel = [TCCMapKitHelpers zoomLevelForZoomScale: zoomScale];
    
    // overzoom is 1 by default, get zoom level from zoom scale
    NSInteger overZoom = 1;
    
    // calculate amount of overzoom
    if (currentZoomLevel > mapOverlay.maximumZ) {
        overZoom = pow(2, (currentZoomLevel - mapOverlay.maximumZ));
        currentZoomLevel = mapOverlay.maximumZ;
    }
    // cap zoom level
    if(currentZoomLevel < mapOverlay.minimumZ) {
        currentZoomLevel = mapOverlay.minimumZ;
    }
    if(currentZoomLevel > mapOverlay.maximumZ) {
        currentZoomLevel = mapOverlay.maximumZ;
    }
    
    // get x ,y, z coords for tile
    CGPoint mercatorPoint = [TCCMapKitHelpers mercatorTileOriginForMapRect: mapRect];
    NSInteger x = floor(mercatorPoint.x * [TCCMapKitHelpers worldTileWidthForZoomLevel:currentZoomLevel]);
    NSInteger y = floor(mercatorPoint.y * [TCCMapKitHelpers worldTileWidthForZoomLevel:currentZoomLevel]);
    NSInteger z = currentZoomLevel;
    
    // grab tile from set
    TCCAnimationTile *tile;
    [self.tileSetLock lock];
    for (TCCAnimationTile *tileInd in self.tileSet) {
        if (x == tileInd.x && y == tileInd.y && z == tileInd.z) {
            tile = tileInd;
            break;
        }
    }
    [self.tileSetLock unlock];

    // if no overzoom
    if (overZoom == 1) {
        CGRect rect = [self rectForMapRect:mapRect];
        UIImage *image = tile.tileImage;
        UIGraphicsPushContext(context);
        [image drawInRect:rect blendMode:kCGBlendModeNormal alpha:self.alpha];
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
        
        if (self.drawDebugInfo) {
            [TCCMapKitHelpers drawDebugInfoForX:tile.x Y:tile.y Z:tile.z color:[UIColor blueColor] inRect:rect context:context];
        }
    }
}

@end
