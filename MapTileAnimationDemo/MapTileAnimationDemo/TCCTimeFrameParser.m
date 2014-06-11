//
//  TCCTimeFrameParser.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCTimeFrameParser.h"

#define TIMEFRAME_TEMPLATE_STRING "http://qa1-twi.climate.com/assets/wdt-future-radar/%@/%@/{z}/{x}/{y}.png"
#define TIMEFRAME_URI "http://qa1-twi.climate.com/assets/wdt-future-radar/%@/%@"

@interface TCCTimeFrameParser ()

@property (readwrite, strong) NSDictionary *timeStampsBackingDictionary;

@end

@implementation TCCTimeFrameParser
{
	NSArray *_templateFrameTimeURLs;
	NSArray *_timeFrameURLs;
}

- (id) initWithData: (NSData *)timeStampData
{
	self = [super init];
	if (self) {
		self.timeStampsBackingDictionary = [NSJSONSerialization JSONObjectWithData: timeStampData options: 0 error: nil];
	}
	return self;
}
//=================================================================================
- (NSString *)ingestTimeStampString
{
	return [[self.timeStampsBackingDictionary allKeys] firstObject];
}
//=================================================================================
- (NSArray *)frameTimeStamps
{
	return [[self.timeStampsBackingDictionary objectForKey: self.ingestTimeStampString] objectForKey: @"succeeded"];
}
//=================================================================================
- (NSArray *)timeFrameURLs
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSMutableArray *array = [NSMutableArray array];
		
		for (NSString *timeStamp in self.frameTimeStamps)
		{
			NSString *urlString = [NSString stringWithFormat: @TIMEFRAME_URI, self.ingestTimeStampString, timeStamp];
			[array addObject: urlString];
		}
		
		_timeFrameURLs = [[NSArray alloc] initWithArray: array];
	});
	
	return _timeFrameURLs;
}
//=================================================================================
- (NSArray *)templateFrameTimeURLs
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSMutableArray *array = [NSMutableArray array];
		
		for (NSString *timeStamp in self.frameTimeStamps)
		{
			NSString *urlString = [NSString stringWithFormat: @TIMEFRAME_TEMPLATE_STRING, self.ingestTimeStampString, timeStamp];
			[array addObject: urlString];
		}
		
		_templateFrameTimeURLs = [[NSArray alloc] initWithArray: array];
	});
	
	return _templateFrameTimeURLs;
}
//=================================================================================

@end
