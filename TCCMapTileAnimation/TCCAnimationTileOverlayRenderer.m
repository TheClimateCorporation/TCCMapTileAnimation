//
//  TCCAnimationTileOverlayRenderer.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCAnimationTileOverlayRenderer.h"
#import "TCCAnimationTileOverlay.h"
#import "TCCAnimationTile.h"
#import "TCCMapKitHelpers.h"

@implementation TCCAnimationTileOverlayRenderer

#pragma mark - Lifecycle

- (id) initWithOverlay:(id<MKOverlay>)overlay
{
	self = [super initWithOverlay:overlay];
	if (self)
	{
        if (![overlay isKindOfClass:[TCCAnimationTileOverlay class]]) {
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
    TCCAnimationTileOverlay *mapOverlay = (TCCAnimationTileOverlay *)self.overlay;
    TCCAnimationTile *tile = [mapOverlay tileForMapRect:mapRect zoomScale:zoomScale];
	if (tile) {
		CGRect rect = [self rectForMapRect: mapRect];
		UIImage *image = tile.tileImage;
		UIGraphicsPushContext(context);
        // TODO: make this alpha configurable
		[image drawInRect:rect blendMode:kCGBlendModeNormal alpha:self.alpha];
		UIGraphicsPopContext();
	}
    
    NSInteger zoomLevel = [TCCMapKitHelpers zoomLevelForZoomScale:zoomScale];
    NSInteger overZoom = 1;
    
    if (zoomLevel > mapOverlay.maximumZ) {
        overZoom = pow(2, (zoomLevel - mapOverlay.maximumZ));
        zoomLevel = mapOverlay.maximumZ;
    }
    
    
    if (self.drawDebugInfo) {
        TCCTileCoordinate c = [TCCMapKitHelpers tileCoordinateForMapRect:mapRect zoomLevel:[TCCMapKitHelpers zoomLevelForZoomScale:zoomScale]];
        [TCCMapKitHelpers drawDebugInfoForX:c.x Y:c.y Z:c.z color:[UIColor blackColor] inRect:[self rectForMapRect:mapRect] context:context];
    }
    
    if (overZoom == 1) return;
    
    NSArray *tiles = [mapOverlay cachedTilesForMapRect:mapRect];

    //tile drawing
    for (TCCAnimationTile *tile in tiles) {
        // For each image tile, draw it in its corresponding MKMapRect frame
        CGRect rect = [self rectForMapRect:tile.mapRectFrame];
        if (!MKMapRectIntersectsRect(mapRect, tile.mapRectFrame)) continue;
        
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