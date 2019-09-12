//
//  TCCMapTile.h
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface TCCAnimationTile : NSObject

@property (nonatomic) NSInteger x;
@property (nonatomic) NSInteger y;
@property (nonatomic) NSInteger z;
@property (nonatomic, nonnull) NSURLSessionConfiguration * configuration;

/**
 The @c MKMapRect that corresponds to the x, y, and z coordinates of this animation tile object.
 */
@property (nonatomic) MKMapRect mapRectFrame;

/**
 A place to store image data for a tile. This is mostly a convenience so that the
 @c MATAnimatedTileOverlay doesn't have to directly manage the storing and retrieval of images.
 */
@property (strong, nonatomic, nullable) UIImage *tileImage;

/**
 The frame index of the @c UIImage stored in the @c tileImage property.
 */
@property NSInteger tileImageIndex;

/**
 An array of @c NSString objects that represent the URL at which the tile image asset can be
 fetched. The URLs maintain the order in which the tile images should be animated.
 */
@property (copy, nonatomic, nullable) NSArray *templateURLs;

/**
 Flag to indicate that a fetch for this tile has previously failed
 */
@property BOOL failedToFetch;

- (nullable id)initWithFrame:(MKMapRect)frame x:(NSInteger)x y:(NSInteger)y z:(NSInteger)z;
- (nullable id)initWithFrame:(MKMapRect)frame configuringURLSession: (NSURLSessionConfiguration* _Nonnull)configuration x:(NSInteger)x y:(NSInteger)y z:(NSInteger)z;

- (void)fetchTileForFrameIndex:(NSInteger)frameIndex session:(NSURLSession *)session completionHandler:(void (^)(NSData * date, NSURLResponse * response, NSError * error))completionBlock;

@end
