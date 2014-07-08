//
//  MATTileOverlay.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 7/7/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "MATTileOverlay.h"
#import "MATAnimatedTileOverlay.h"

@interface MATTileOverlay ()

@property (nonatomic, readwrite, strong) NSOperationQueue *operationQueue;
@property (nonatomic, readwrite, weak) MATAnimatedTileOverlay *animatedTileOverlay;

@end

@implementation MATTileOverlay

- (instancetype)initWithAnimationTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay;
{
	NSString *templateURL = [animatedTileOverlay templateURLStringForFrameIndex: 0];
	
	self = [super initWithURLTemplate: templateURL];
	if (self)
	{
		self.operationQueue = [[NSOperationQueue alloc] init];
		self.minimumZ = 3;
		self.maximumZ = 9;
		self.animatedTileOverlay = animatedTileOverlay;
		self.animatedTileOverlay.minimumZ = self.minimumZ;
		self.animatedTileOverlay.maximumZ = self.maximumZ;
	}
	return self;
}

- (void) loadTileAtPath: (MKTileOverlayPath)path result:(void (^)(NSData *data, NSError *error))result
{
	
    if (!result) {
        return;
    }
	
//	__block MATTileOverlay *weakself = self;
//	
//	NSString *tilePath = [[self URLForTilePath: path] absoluteString];
//	
//	NSLog(@"url %@", tilePath);
	
	NSURLRequest *request = [NSURLRequest requestWithURL: [self URLForTilePath: path]];
	[NSURLConnection sendAsynchronousRequest: request queue: self.operationQueue completionHandler: ^(NSURLResponse *response, NSData *data, NSError *connectionError) {
		result(data, connectionError);
	}];
}

@end
