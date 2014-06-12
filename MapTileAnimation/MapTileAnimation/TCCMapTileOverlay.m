//
//  TCCMapTileOverlay.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapTileOverlay.h"

@implementation TCCMapTileOverlay

- (id) initWithTileArray: (NSArray *)anArray
{
	self = [super init];
	if (self) {
		self.mapTiles = anArray;
	}
	return self;
}

- (CLLocationCoordinate2D)coordinate
{
    return MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX([self boundingMapRect]), MKMapRectGetMidY([self boundingMapRect])));
}

- (MKMapRect)boundingMapRect
{
    return MKMapRectWorld;
}

@end
