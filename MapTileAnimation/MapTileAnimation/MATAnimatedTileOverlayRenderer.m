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
}

@end
