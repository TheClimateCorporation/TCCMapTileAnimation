//
//  TCCAnimationTileOverlayRenderer.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface TCCAnimationTileOverlayRenderer : MKOverlayRenderer

@property (nonatomic) MKZoomScale zoomScale;
@property (nonatomic) BOOL drawDebugInfo;

@end
