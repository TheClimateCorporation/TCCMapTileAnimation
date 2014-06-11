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

@end
