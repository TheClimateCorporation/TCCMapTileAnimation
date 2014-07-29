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
// Keeps track of which zoom level of tiles are in tileSet
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
    NSUInteger currentZoomLevel = [TCCMapKitHelpers zoomLevelForZoomScale:zoomScale];
    NSUInteger cappedZoomLevel = MIN(currentZoomLevel, mapOverlay.maximumZ);
    cappedZoomLevel = MAX(currentZoomLevel, mapOverlay.minimumZ);

    // empty tileSet if new zoom level is different than last zoom level
    if (currentZoomLevel != self.lastZoomLevel) {
        [self.tileSetLock lock];
        [self.tileSet removeAllObjects];
        [self.tileSetLock unlock];

        self.lastZoomLevel = currentZoomLevel;
    }
    
    TCCTileCoordinate coord = [TCCMapKitHelpers tileCoordinateForMapRect:mapRect zoomLevel:cappedZoomLevel];
    
    // Store path for tile in struct for MKTileOverlay
    MKTileOverlayPath coordPaths;
    coordPaths.x = coord.x;
    coordPaths.y = coord.y;
    coordPaths.z = coord.z;
    
    MKMapRect cappedMapRect = [TCCMapKitHelpers mapRectForTileCoordinate:coord];
    
    // create tile, passed x, y, and capped z
    TCCAnimationTile *tile = [[TCCAnimationTile alloc] initWithFrame:cappedMapRect x:coordPaths.x y:coordPaths.y z:cappedZoomLevel];

    // check if tile is in dictionary, if so we return YES to render it with drawMapRect
    [self.tileSetLock lock];
    if ([self.tileSet containsObject:tile]) return YES;
    [self.tileSetLock unlock];
    
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

- (void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
{
    TCCAnimationTileOverlay *mapOverlay = (TCCAnimationTileOverlay *)self.overlay;
    
    NSUInteger currentZoomLevel = [TCCMapKitHelpers zoomLevelForZoomScale:zoomScale];
    
    // Calculate amount of overzoom, which is the multiplier by which the tile image data
    // needs to be scaled up. Formula is 2^(zoom level delta), since each zoom level will
    // zoom by a factor of 2.
    NSInteger overZoom = 1;
    if (currentZoomLevel > mapOverlay.maximumZ) {
        overZoom = pow(2, (currentZoomLevel - mapOverlay.maximumZ));
    }
    NSInteger cappedZoomLevel = MIN(currentZoomLevel, mapOverlay.maximumZ);
    cappedZoomLevel = MAX(currentZoomLevel, mapOverlay.minimumZ);
    
    // Get the tile coordinate that needs to be drawn
    TCCTileCoordinate coord = [TCCMapKitHelpers tileCoordinateForMapRect:mapRect zoomLevel:cappedZoomLevel];
    
    // Use the tile coordinate to search self.tileSet for the tile image to draw
    TCCAnimationTile *tile;
    [self.tileSetLock lock];
    for (TCCAnimationTile *tileInd in self.tileSet) {
        if (coord.x == tileInd.x && coord.y == tileInd.y && coord.z == tileInd.z) {
            tile = tileInd;
            break;
        }
    }
    [self.tileSetLock unlock];

    if (overZoom == 1) {
        CGRect rect = [self rectForMapRect:mapRect];
        
        UIGraphicsPushContext(context);
        [tile.tileImage drawInRect:rect blendMode:kCGBlendModeNormal alpha:self.alpha];
        UIGraphicsPopContext();
    } else {
        CGRect rect = [self rectForMapRect:tile.mapRectFrame];
        
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
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
