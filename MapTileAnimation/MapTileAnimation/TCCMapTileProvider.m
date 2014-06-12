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
@property (nonatomic, readwrite, strong) NSCache *imageTileCache;


- (void) fetchTimeStampsAtURL: (NSURL *)aURL;
- (NSArray *) mapTilesInMapRect: (MKMapRect)aRect zoomScale: (MKZoomScale)aScale;
- (void) fetchTileImage: (TCCMapTile *)aMapTile baseURLString: (NSString *)aURLString;

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
		self.imageTileCache = [[NSCache alloc] init];
		self.imageTileCache.name = NSStringFromClass([TCCMapTileProvider class]);
		self.imageTileCache.countLimit = 450;
		
		[self fetchTimeStampsAtURL: [NSURL URLWithString: aTimeFrameURI]];
	}
	return self;
}
//============================================================
- (void) dealloc
{
	[self.imageTileCache removeAllObjects];
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
		[self fetchTileImage: tile baseURLString: baseURI];
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
- (void) fetchTileImage: (TCCMapTile *)aMapTile baseURLString: (NSString *)aURLString;
{
	__block TCCMapTile *mapTile = aMapTile;
	__block TCCMapTileProvider *provider = self;
	
	[self.operationQueue addOperationWithBlock: ^{
		dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
		
		NSString *cacheKey = nil;
		
		if ([provider.delegate respondsToSelector: @selector(uniqueCacheKey)]) {
			NSString *key = [provider.delegate uniqueCacheKey];
			cacheKey = [NSString stringWithFormat: @"%@/%@", key, mapTile.tileCoordinate];
		} else {
			cacheKey = [NSString stringWithFormat: @"%@/%@", aURLString, mapTile.tileCoordinate];
		}
		
		NSData *cachedData = [provider.imageTileCache objectForKey: cacheKey];
		if (cachedData != nil)
		{
			NSLog(@"using cached data");
			UIImage *img = [[UIImage alloc] initWithData: cachedData];
			mapTile.imageTile = img;
			dispatch_semaphore_signal(semaphore);
		}
		else
		{
			NSString *urlString = [NSString stringWithFormat: @"%@/%@.png", aURLString, mapTile.tileCoordinate];
//			NSLog(@"derived->urlString = %@", urlString);
			
			NSURLSession *session = [NSURLSession sharedSession];
			NSURLSessionTask *task = [session dataTaskWithURL: [NSURL URLWithString: urlString] completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
				
				NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)response;
				
				if (data) {
					if (urlResponse.statusCode == 200) {
						
						[provider.imageTileCache setObject: data forKey: cacheKey];
						
						UIImage *img = [[UIImage alloc] initWithData: data];
						mapTile.imageTile = img;
					}
				} else {
					NSLog(@"error = %@", error);
				}
				
				dispatch_semaphore_signal(semaphore);
			}];
			[task resume];
		}

		// have the thread wait until the download task is done
		dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
	}];
}

//============================================================

@end
