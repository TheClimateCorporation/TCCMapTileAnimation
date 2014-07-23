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
#import "TCCTileOverlayHelpers.h"

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
		[image drawInRect:rect blendMode:kCGBlendModeNormal alpha:0.75];
		UIGraphicsPopContext();
	}
    
    NSInteger zoomLevel = [TCCTileOverlayHelpers zoomLevelForZoomScale:zoomScale];
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
    TCCTileCoordinate c = [TCCTileOverlayHelpers tileCoordinateForMapRect:mapRect zoomLevel:zoomLevel];
    NSString *tileCoordinates = [NSString stringWithFormat:@"(%ld, %ld, %ld)", (long)c.x, (long)c.y, (long)c.z];
    [tileCoordinates drawInRect:rect withAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:CGRectGetHeight(rect) * .1] }];
    
    UIGraphicsPopContext();
    
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

@end