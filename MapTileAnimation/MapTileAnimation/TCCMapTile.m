//
//  TCCMapTile.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapTile.h"

@implementation TCCMapTile
//=================================================================================
- (id) initWithFrame:(MKMapRect)aTileFrame tileCoordinate:(NSString *)aTileCoordinate
{
    self = [super init];
	if (self) {
		self.tileCoordinate = aTileCoordinate;
        self.mapRectFrame = aTileFrame;
		self.imageTile = nil;
    }
    return self;
}
//=================================================================================
- (void) fetchImageOnQueue: (NSOperationQueue *)aQueue baseURLString: (NSString *)aURLString
{
	__block TCCMapTile *mapTile = self;
	[aQueue addOperationWithBlock: ^{
		
		dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
		NSString *urlString = [NSString stringWithFormat: @"%@/%@.png", aURLString, mapTile.tileCoordinate];
		NSLog(@"derived->urlString = %@", urlString);
		
		NSURLSession *session = [NSURLSession sharedSession];
		NSURLSessionTask *task = [session dataTaskWithURL: [NSURL URLWithString: urlString] completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
			
			NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)response;
			
			if (data) {
				if (urlResponse.statusCode == 200) {
					UIImage *img = [[UIImage alloc] initWithData: data];
					mapTile.imageTile = img;
				}
			} else {
				NSLog(@"error = %@", error);
			}
			
			dispatch_semaphore_signal(semaphore);
		}];
		[task resume];
		// have the thread wait until the download task is done
		dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
	}];
}
//=================================================================================

//=================================================================================

@end
