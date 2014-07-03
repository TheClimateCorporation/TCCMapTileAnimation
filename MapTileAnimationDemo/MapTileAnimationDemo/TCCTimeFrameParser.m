//
//  TCCTimeFrameParser.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCTimeFrameParser.h"

#define TIMEFRAME_TEMPLATE_STRING "http://climate.com/assets/wdt-future-radar/%@/%@/{z}/{x}/{y}.png"
#define TIMEFRAME_URI "http://climate.com/assets/wdt-future-radar/%@/%@"

@interface TCCTimeFrameParser ()

@property (nonatomic, readwrite, strong) NSOperationQueue *operationQueue;
@property (readwrite, strong) NSDictionary *timeStampsBackingDictionary;

- (void) fetchTimeStampsAtURL: (NSURL *)aURL;

@end

@implementation TCCTimeFrameParser
{
	NSArray *_templateFrameTimeURLs;
	NSArray *_timeFrameURLs;
}

- (id) initWithURLString: (NSString *)aURLString delegate: (id)aDelegate
{
	self = [super init];
	if (self) {
		self.operationQueue = [[NSOperationQueue alloc] init];
		self.delegate = aDelegate;
		[self fetchTimeStampsAtURL: [NSURL URLWithString: aURLString]];
		
	}
	return self;
}

- (void) fetchTimeStampsAtURL: (NSURL *)aURL
{
	TCCTimeFrameParser __weak *parser = self;
	
	[self.operationQueue addOperationWithBlock: ^{
		NSURLSession *session = [NSURLSession sharedSession];
		NSURLSessionTask *task = [session dataTaskWithURL: aURL completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
			
			NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)response;
			
			if (data) {
				if (urlResponse.statusCode == 200) {
					parser.timeStampsBackingDictionary = [NSJSONSerialization JSONObjectWithData: data options: 0 error: nil];
					dispatch_async(dispatch_get_main_queue(), ^{
						[parser.delegate didLoadTimeStampData];
					});
				} else {
					NSLog(@"%s status code %ld", __PRETTY_FUNCTION__, (long)urlResponse.statusCode);
				}
			} else {
				NSLog(@"error = %@", error);
			}
			
		}];
		[task resume];
	}];
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
- (NSUInteger) countOfTimeIndexes
{
	return [self timeFrameURLs].count;
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
