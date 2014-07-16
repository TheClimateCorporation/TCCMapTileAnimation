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

    /* Debug information */
    UIGraphicsPushContext(context);

    CGRect rect = [self rectForMapRect: mapRect];
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRect:CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
    [[UIColor blackColor] setStroke];
    bezierPath.lineWidth = 10000.0 * 14/(zoomLevel * 3);
    [bezierPath stroke];
    if (tile) {
        NSString *tileCoordinates = [NSString stringWithFormat:@"(%d, %d, %d)", tile.xCoordinate, tile.yCoordinate, tile.zCoordinate];
        [tileCoordinates drawInRect:rect withAttributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:200000 * 14/(zoomLevel * 3)] }];
    }
    
    UIGraphicsPopContext();
    
    NSSet *tiles = [mapOverlay mapTilesInMapRect:mapRect zoomScale:zoomScale];
    // TODO: draw these tiles!!!!
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

@end
