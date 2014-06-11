//
//  TCCMapTileProvider.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapTileProvider.h"
#import "TCCMapTile.h"

@interface TCCMapTileProvider ()

@property (nonatomic, readwrite, strong) NSOperationQueue *operationQueue;

- (void) fetchTimeStampsAtURL: (NSURL *)aURL;

@end


@implementation TCCMapTileProvider

- (id) initWithTimeFrameURI: (NSString *)aTimeFrameURI delegate: (id)aDelegate
{
	self = [super init];
	if (self) {
		
		self.operationQueue = [[NSOperationQueue alloc] init];
		self.delegate = aDelegate;
		[self fetchTimeStampsAtURL: [NSURL URLWithString: aTimeFrameURI]];
	}
	return self;
}
//============================================================
- (void) fetchTimeStampsAtURL: (NSURL *)aURL
{
	[self.operationQueue addOperationWithBlock: ^{
		NSURLSession *session = [NSURLSession sharedSession];
		NSURLSessionTask *task = [session dataTaskWithURL: aURL completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
			
			NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)response;
			
			if (data) {
				
				if (urlResponse.statusCode == 200) {
					
					if ([self.delegate respondsToSelector: @selector(tileProvider:didFetchTimeFrameData:)])
						[self.delegate tileProvider: self didFetchTimeFrameData: data];
				}
			} else {
				NSLog(@"error = %@", error);
			}
			
		}];
		[task resume];
	}];
}
//============================================================

//============================================================

//============================================================

@end
