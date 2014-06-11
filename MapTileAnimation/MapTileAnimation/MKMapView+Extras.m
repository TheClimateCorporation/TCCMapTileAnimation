//
//  MKMapView+Extras.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "MKMapView+Extras.h"


@implementation MKMapView (Extras)

- (MKZoomScale) currentZoomScale
{
	return (self.bounds.size.width / self.visibleMapRect.size.width) * 2.0;
}

@end
