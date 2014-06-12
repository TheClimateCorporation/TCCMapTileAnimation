//
//  MKMapView+Extras.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface MKMapView (Extras)

- (MKZoomScale) currentZoomScale;

- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(NSUInteger)zoomLevel animated:(BOOL)animated;
-(MKCoordinateRegion)coordinateRegionWithMapView:(MKMapView *)mapView centerCoordinate:(CLLocationCoordinate2D)centerCoordinate andZoomLevel:(NSUInteger)zoomLevel;
- (NSUInteger)zoomLevel;

@end
