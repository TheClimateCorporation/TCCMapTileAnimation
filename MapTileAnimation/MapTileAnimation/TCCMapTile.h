//
//  TCCMapTile.h
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface TCCMapTile : NSObject

@property (nonatomic, readwrite, strong) NSString *tileCoordinate;
@property (nonatomic, readwrite, assign) MKMapRect mapRectFrame;
@property (nonatomic, readwrite, strong) UIImage *imageTile;

- (id) initWithFrame:(MKMapRect)aTileFrame tileCoordinate:(NSString *)aTileCoordinate;

- (void) fetchImageOnQueue: (NSOperationQueue *)aQueue baseURLString: (NSString *)aURLString;

@end
