//
//  MATTileOverlay.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 7/9/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "MATTileOverlay.h"
#import "MATAnimatedTileOverlay.h"

@interface MATTileOverlay ()

@property (nonatomic, readwrite, strong) NSOperationQueue *operationQueue;
@property (weak, nonatomic, readwrite) MATAnimatedTileOverlay *animatedTileOverlay;

@end

@implementation MATTileOverlay

- (id)initWithAnimationTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay
{
	NSString *templateURL = [animatedTileOverlay templateURLStringForFrameIndex:0];
	
	self = [super initWithURLTemplate: templateURL];
	if (self) {
		self.operationQueue = [[NSOperationQueue alloc] init];
		self.minimumZ = 3;
		self.maximumZ = 9;
		self.animatedTileOverlay = animatedTileOverlay;
		self.animatedTileOverlay.minimumZ = self.minimumZ;
		self.animatedTileOverlay.maximumZ = self.maximumZ;
	}

	return self;
}
@end
