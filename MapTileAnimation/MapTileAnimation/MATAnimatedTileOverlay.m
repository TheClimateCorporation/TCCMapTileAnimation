//
//  MATAnimatedTileOverlay.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#define Z_INDEX "{z}"
#define X_INDEX "{x}"
#define Y_INDEX "{y}"
#define T_INDEX "{t}"

#import "MATAnimatedTileOverlay.h"

@interface MATAnimatedTileOverlay ()

@property (nonatomic, readwrite, copy) NSString *templateURLString;
@property (nonatomic, assign) NSInteger numberOfAnimationFrames;
@property (nonatomic, assign) NSTimeInterval frameDuration;

- (NSString *) URLStringForX: (NSString *)xString Y: (NSString *)yString Z: (NSString *)zString T: (NSString *)tString;

@end

@implementation MATAnimatedTileOverlay

- (id) initWithTemplateURL: (NSString *)aTemplateURLstring numberOfAnimationFrames:(NSUInteger)numberOfAnimationFrames frameDuration:(NSTimeInterval)frameDuration
{
	self = [super init];
	if (self)
	{
		self.templateURLString = aTemplateURLstring;
		self.numberOfAnimationFrames = numberOfAnimationFrames;
		self.frameDuration = frameDuration;
	}
	return self;
}

- (id) initWithTileArray: (NSArray *)anArray
{
	self = [super init];
	if (self) {
		self.mapTiles = anArray;
	}
	return self;
}

- (void) updateWithTileArray: (NSArray *)aTileArray
{
	self.mapTiles = aTileArray;
}

- (NSString *) URLStringForX: (NSString *)xString Y: (NSString *)yString Z: (NSString *)zString T: (NSString *)tString
{
	NSString *returnString = nil;
	

	NSString *replaceX = [self.templateURLString stringByReplacingOccurrencesOfString: @X_INDEX withString: xString];
	NSString *replaceY = [replaceX stringByReplacingOccurrencesOfString: @Y_INDEX withString: yString];
	NSString *replaceZ = [replaceY stringByReplacingOccurrencesOfString: @Z_INDEX withString: zString];
	NSString *replaceT = [replaceZ stringByReplacingOccurrencesOfString: @T_INDEX withString: tString];
	
	if (replaceT)
		returnString = replaceT;
	else
		returnString = replaceZ;
	
	return returnString;
}

- (CLLocationCoordinate2D)coordinate
{
    return MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX([self boundingMapRect]), MKMapRectGetMidY([self boundingMapRect])));
}

- (MKMapRect)boundingMapRect
{
    return MKMapRectWorld;
}

@end
