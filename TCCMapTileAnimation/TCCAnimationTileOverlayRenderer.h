//
//  TCCAnimationTileOverlayRenderer.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface TCCAnimationTileOverlayRenderer : MKOverlayRenderer

/**
 Zoom level of the currently rendered overlay tiles. Value ranges from 1-20.
 */
@property (nonatomic) NSUInteger renderedTileZoomLevel;

@property (nonatomic) BOOL drawDebugInfo;

@end
