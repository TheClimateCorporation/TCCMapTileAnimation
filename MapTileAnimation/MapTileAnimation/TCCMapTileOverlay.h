//
//  TCCMapTileOverlay.h
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface TCCMapTileOverlay : NSObject <MKOverlay>

@property (readwrite, strong) NSArray *mapTiles;

- (id) initWithTileArray: (NSArray *)anArray;

- (void) updateWithTileArray: (NSArray *)aTileArray;

@end
