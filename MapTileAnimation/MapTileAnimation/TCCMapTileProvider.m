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
- (NSArray *) mapTilesInMapRect: (MKMapRect)aRect zoomScale: (MKZoomScale)aScale;

@end

#define OVERLAY_SIZE 256.0


static NSInteger zoomScaleToZoomLevel(MKZoomScale scale)
{
    // Conver an MKZoomScale to a zoom level where level 0 contains
    // four square tiles.
    double numberOfTilesAt1_0 = MKMapSizeWorld.width / OVERLAY_SIZE;
    
    //Add 1 to account for virtual tile
    NSInteger zoomLevelAt1_0 = log2(numberOfTilesAt1_0);
    NSInteger zoomLevel = MAX(0, zoomLevelAt1_0 + floor(log2f(scale) + 0.5));
    return zoomLevel;
}

@implementation TCCMapTileProvider
//============================================================
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
- (void) fetchTilesForMapRect: (MKMapRect)aMapRect zoomScale: (MKZoomScale)aScale timeIndex: (NSUInteger)aTimeIndex completionBlock: (void (^)(NSArray *tileArray))block
{
	NSString *baseURI = [self.delegate baseURIForTimeIndex: aTimeIndex];
	NSArray *mapTiles = [self mapTilesInMapRect: aMapRect zoomScale: aScale];
	
	for (TCCMapTile *tile in mapTiles) {
		[tile fetchImageOnQueue: self.operationQueue baseURLString: baseURI];
	}
	
	[self.operationQueue waitUntilAllOperationsAreFinished];
	block([NSArray arrayWithArray: mapTiles]);
}
//============================================================
- (NSArray *) mapTilesInMapRect: (MKMapRect)aRect zoomScale: (MKZoomScale)aScale
{
    NSInteger z = zoomScaleToZoomLevel(aScale);
    NSMutableArray *tiles = nil;
	
    // The number of tiles either wide or high.
	//    NSInteger zTiles = pow(2, z);
    
    NSInteger minX = floor((MKMapRectGetMinX(aRect) * aScale) / OVERLAY_SIZE);
    NSInteger maxX = floor((MKMapRectGetMaxX(aRect) * aScale) / OVERLAY_SIZE);
    NSInteger minY = floor((MKMapRectGetMinY(aRect) * aScale) / OVERLAY_SIZE);
    NSInteger maxY = floor((MKMapRectGetMaxY(aRect) * aScale) / OVERLAY_SIZE);
	
	for(NSInteger x = minX; x <= maxX; x++) {
        for(NSInteger y = minY; y <=maxY; y++) {
            // Flip the y index to properly reference overlay files.
			//            NSInteger flippedY = abs(y + 1 - zTiles);
            NSString *tileCoord = [[NSString alloc] initWithFormat:@"%ld/%ld/%ld", (long)z, (long)x, (long)y];
			
			if (!tiles) {
				tiles = [NSMutableArray array];
			}
			MKMapRect frame = MKMapRectMake((double)(x * OVERLAY_SIZE) / aScale, (double)(y * OVERLAY_SIZE) / aScale, OVERLAY_SIZE / aScale, OVERLAY_SIZE / aScale);
			TCCMapTile *tile = [[TCCMapTile alloc] initWithFrame: frame tileCoordinate: tileCoord];
			[tiles addObject:tile];
        }
    }
    return [NSArray arrayWithArray: tiles];
}
//============================================================

//============================================================

@end
