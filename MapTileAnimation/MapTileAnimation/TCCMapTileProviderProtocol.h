//
//  TCCMapTileProviderProtocol.h
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TCCMapTileProvider;

@protocol TCCMapTileProviderProtocol <NSObject>

- (void) tileProvider: (TCCMapTileProvider *)aProvider didFetchTimeFrameData: (NSData *)theTimeFrameData;

// called by the tile provider to get a base URI (without tile coordinates) for a given time index
- (NSString *)baseURIForTimeIndex: (NSUInteger)aTimeIndex;

@optional
// called to get a unique cache name key
- (NSString *)uniqueCacheKey;

@end
