//
//  TCCTileFetchOperation.h
//  MapTileAnimationDemo
//
//  Created by Richard Shin on 8/1/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TCCAnimationTile;

@interface TCCTileFetchOperation : NSOperation

/**
 Designated initializer.
 */
- (instancetype)initWithTile:(TCCAnimationTile *)tile frameIndex:(NSUInteger)frameIndex;

/**
 Set the @c NSURLSession object that this fetch operation should use, or nil if it should use
 the @c sharedSession singleton.
 */
@property (strong, nonatomic) NSURLSession *session;

/**
 Returns image if fetch was successful, @c nil otherwise.
 */
@property (copy, nonatomic) void (^completionHandler)(UIImage *image);

@end
