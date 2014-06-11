//
//  TCCMapTileProvider.h
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

#import "TCCMapTileProviderProtocol.h"

@interface TCCMapTileProvider : NSObject

@property (nonatomic, readwrite, weak)id<TCCMapTileProviderProtocol>delegate;

- (id) initWithTimeFrameURI: (NSString *)aTimeFrameURI delegate: (id)aDelegate;

- (void) fetchTilesForMapRect: (MKMapRect)aMapRect zoomScale: (MKZoomScale)aScale timeIndex: (NSUInteger)aTimeIndex completionBlock: (void (^)(NSArray *tileArray))block;

@end
