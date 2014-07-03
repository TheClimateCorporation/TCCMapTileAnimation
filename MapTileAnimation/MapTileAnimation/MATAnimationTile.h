//
//  TCCMapTile.h
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

// TODO: fix this up
typedef struct
{
	NSUInteger xCoordinate;
	NSUInteger yCoordinate;
	NSUInteger zCoordiante;
} MATTileCoordinate;

@interface MATAnimationTile : NSObject

@property (nonatomic, readwrite, assign) NSInteger xCoordinate;
@property (nonatomic, readwrite, assign) NSInteger yCoordinate;
@property (nonatomic, readwrite, assign) NSInteger zCoordinate;

@property (nonatomic, readwrite, strong) NSString *tileCoordinate;
@property (nonatomic, readwrite, assign) MKMapRect mapRectFrame;
@property (nonatomic, readwrite, strong) UIImage *currentImageTile;

@property (nonatomic, readwrite, strong) NSArray *tileURLs;

- (id) initWithFrame:(MKMapRect)aTileFrame xCord: (NSInteger)aXCord yCord: (NSInteger)aYCord zCord: (NSInteger)aZCord;


@end
