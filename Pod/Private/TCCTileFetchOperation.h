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
 The tile image if the operation finishes successfully,
 */
@property (strong, nonatomic) UIImage *tileImage;

@end
