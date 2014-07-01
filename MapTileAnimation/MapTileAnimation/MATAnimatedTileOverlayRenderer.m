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

- (id) initWithOverlay:(id<MKOverlay>)overlay
{
	self = [super initWithOverlay: overlay];
	if (self)
	{
		
	}
	return self;
}

- (BOOL)canDrawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale
{
	self.zoomScale = zoomScale;

    MATAnimatedTileOverlay *mapOverlay = (MATAnimatedTileOverlay *)self.overlay;
    MATAnimationTile *tile = [mapOverlay tileForMapRect: mapRect zoomScale: zoomScale];
	if (tile) {
		return YES;
	}
	
	return NO;
}

/*
 even though this renderer and associated overlay are *NOT* tiled, drawMapRect gets called multilple times with each mapRect being a tiled region within the visibleMapRect.  So MKMapKit drawing is tiled by design even though setNeedsDisplay is only called once.
 */
-(void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
{
    MATAnimatedTileOverlay *mapOverlay = (MATAnimatedTileOverlay *)self.overlay;
    MATAnimationTile *tile = [mapOverlay tileForMapRect: mapRect zoomScale: zoomScale];
	if (tile) {
		// draw each tile in its frame
		CGRect rect = [self rectForMapRect: mapRect];
		
		UIImage *image = tile.currentImageTile;
		UIGraphicsPushContext(context);
		[image drawInRect: rect
				blendMode: kCGBlendModeNormal
					alpha: 0.75];
		UIGraphicsPopContext();
	}
	
//	NSSet *rectTiles = mapOverlay.mapTiles;
//    for (MATAnimationTile *tile in rectTiles)
//    {
//		if (tile.currentImageTile == nil)
//			continue;
//
//		CGRect rect = [self rectForMapRect: tile.mapRectFrame];
//
//		UIImage *image = tile.currentImageTile;
//		UIGraphicsPushContext(context);
//		[image drawInRect: rect
//				blendMode: kCGBlendModeNormal
//					alpha: 0.75];
//		UIGraphicsPopContext();
//
//	}

}

@end
