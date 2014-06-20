//
//  MATAnimatedTileOverlay.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//


#import "MATAnimatedTileOverlay.h"
#import "MATAnimationTile.h"

#define Z_INDEX "{z}"
#define X_INDEX "{x}"
#define Y_INDEX "{y}"


static NSInteger zoomScaleToZoomLevel(MKZoomScale scale, double overlaySize)
{
    // Convert an MKZoomScale to a zoom level where level 0 contains
    // four square tiles.
    double numberOfTilesAt1_0 = MKMapSizeWorld.width / overlaySize;
    //Add 1 to account for virtual tile
    NSInteger zoomLevelAt1_0 = log2(numberOfTilesAt1_0);
    NSInteger zoomLevel = MAX(0, zoomLevelAt1_0 + floor(log2f(scale) + 0.5));
    return zoomLevel;
}

@interface MATAnimatedTileOverlay ()

@property (nonatomic, readwrite, strong) NSOperationQueue *fetchOperationQueue;
@property (nonatomic, readwrite, strong) NSOperationQueue *downLoadOperationQueue;
@property (nonatomic, readwrite, strong) NSCache *imageTileCache;
@property (nonatomic, readwrite, strong) NSArray *templateURLs;
@property (nonatomic, assign) NSTimeInterval frameDuration;

- (NSString *) URLStringForX: (NSInteger)xValue Y: (NSInteger)yValue Z: (NSInteger)zValue timeIndex: (NSInteger)aTimeIndex;
- (NSArray *) mapTilesInMapRect: (MKMapRect)aRect zoomScale: (MKZoomScale)aScale;
- (void) fetchAndCacheImageTileAtURL: (NSString *)aUrlString;

@end

@implementation MATAnimatedTileOverlay

- (id) initWithTemplateURLs: (NSArray *)templateURLs numberOfAnimationFrames:(NSUInteger)numberOfAnimationFrames frameDuration:(NSTimeInterval)frameDuration
{
	self = [super init];
	if (self)
	{
		self.templateURLs = templateURLs;
		self.numberOfAnimationFrames = numberOfAnimationFrames;
		self.frameDuration = frameDuration;
		self.currentTimeIndex = 0;
		self.fetchOperationQueue = [[NSOperationQueue alloc] init];
		self.downLoadOperationQueue = [[NSOperationQueue alloc] init];
		self.imageTileCache = [[NSCache alloc] init];
		self.imageTileCache.name = NSStringFromClass([MATAnimatedTileOverlay class]);
		self.imageTileCache.countLimit = 512;
		self.tileSize = 256;
	}
	return self;
}

- (void) dealloc
{
	[self.imageTileCache removeAllObjects];
}

#pragma mark - MKOverlay protocol

- (CLLocationCoordinate2D)coordinate
{
    return MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX([self boundingMapRect]), MKMapRectGetMidY([self boundingMapRect])));
}

- (MKMapRect)boundingMapRect
{
    return MKMapRectWorld;
}

#pragma mark - Public

- (void) cancelAllOperations
{
	[self.fetchOperationQueue cancelAllOperations];
	[self.downLoadOperationQueue cancelAllOperations];
}
/*
 will fetch all the tiles for a mapview's map rect and zoom scale.  Provides a download progres block and download completetion block
 */
- (void) fetchTilesForMapRect: (MKMapRect)aMapRect zoomScale: (MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, NSError *error))progressBlock completionBlock: (void (^)(BOOL success, NSError *error))completionBlock
{
	[self.fetchOperationQueue addOperationWithBlock:^{
		//calculate the tiles rects needed for a given mapRect and create the MATAnimationTile objects
		NSArray *mapTiles = [self mapTilesInMapRect: aMapRect zoomScale: aScale];
		
		//at this point we have an array of MATAnimationTiles we need to derive the urls for each tile, for each time index
		for (MATAnimationTile *tile in mapTiles) {
			
			NSMutableArray *array = [NSMutableArray arrayWithCapacity: self.templateURLs.count];
			
			for (NSUInteger timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
				NSString *tileURL = [self URLStringForX: tile.xCoordinate Y: tile.yCoordinate Z: tile.zCoordinate timeIndex: timeIndex];
				[array addObject: tileURL];
			}
			tile.tileURLs = [NSArray arrayWithArray: array];
		}
		//start downloading the tiles for a given time index, we want to download all the tiles for a time index
		//before we move onto the next time index
		for (NSUInteger timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
			//loop over all the tiles for this time index
			for (MATAnimationTile *tile in mapTiles) {
				NSString *tileURL = [tile.tileURLs objectAtIndex: timeIndex];
				//this will return right away
				[self fetchAndCacheImageTileAtURL: tileURL];
			}
			//wait for all the tiles in this time index to download before proceeding the next time index
			[self.downLoadOperationQueue waitUntilAllOperationsAreFinished];
			dispatch_async(dispatch_get_main_queue(), ^{
				progressBlock(timeIndex, nil);
			});
		}
		//update the tile array with new tile objects
		self.mapTiles = mapTiles;
		//set the current image to the first time index
		[self updateImageTilesToCurrentTimeIndex];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			completionBlock(YES, nil);
		});
	}];
}
/*
 updates the MATAnimationTile tile image property to point to the tile image for the current time index
 */
- (void) updateImageTilesToCurrentTimeIndex
{
	for (MATAnimationTile *tile in self.mapTiles) {
		
		NSString *cacheKey = [tile.tileURLs objectAtIndex: self.currentTimeIndex];
		NSData *cachedData = [self.imageTileCache objectForKey: cacheKey];
		if (cachedData) {
			UIImage *img = [[UIImage alloc] initWithData: cachedData];
			tile.currentImageTile = img;
		}
	}
}

#pragma  mark - Private
/*
 derives a URL string from the template URLs, needs tile coordinates and a time index
 */
- (NSString *) URLStringForX: (NSInteger)xValue Y: (NSInteger)yValue Z: (NSInteger)zValue timeIndex: (NSInteger)aTimeIndex
{
	NSString *currentTemplateURL = [self.templateURLs objectAtIndex: aTimeIndex];
	NSString *returnString = nil;
	NSString *xString = [NSString stringWithFormat: @"%ld", (long)xValue];
	NSString *yString = [NSString stringWithFormat: @"%ld", (long)yValue];
	NSString *zString = [NSString stringWithFormat: @"%ld", (long)zValue];
	
	NSString *replaceX = [currentTemplateURL stringByReplacingOccurrencesOfString: @X_INDEX withString: xString];
	NSString *replaceY = [replaceX stringByReplacingOccurrencesOfString: @Y_INDEX withString: yString];
	NSString *replaceZ = [replaceY stringByReplacingOccurrencesOfString: @Z_INDEX withString: zString];
	
	returnString = replaceZ;
	return returnString;
}
/*
 calculates the number of tiles, the tile coordinates and tile MapRect frame given a MapView's MapRect and zoom scale
 returns an array MATAnimationTile objects
 */
- (NSArray *) mapTilesInMapRect: (MKMapRect)aRect zoomScale: (MKZoomScale)aScale
{
    NSInteger z = zoomScaleToZoomLevel(aScale, (double)self.tileSize);
    NSMutableArray *tiles = nil;
	
    NSInteger minX = floor((MKMapRectGetMinX(aRect) * aScale) / self.tileSize);
    NSInteger maxX = floor((MKMapRectGetMaxX(aRect) * aScale) / self.tileSize);
    NSInteger minY = floor((MKMapRectGetMinY(aRect) * aScale) / self.tileSize);
    NSInteger maxY = floor((MKMapRectGetMaxY(aRect) * aScale) / self.tileSize);
	
	for(NSInteger x = minX; x <= maxX; x++) {
        for(NSInteger y = minY; y <=maxY; y++) {
			
			if (!tiles) {
				tiles = [NSMutableArray array];
			}
			MKMapRect frame = MKMapRectMake((double)(x * self.tileSize) / aScale, (double)(y * self.tileSize) / aScale, self.tileSize / aScale, self.tileSize / aScale);
			MATAnimationTile *tile = [[MATAnimationTile alloc] initWithFrame: frame xCord: x yCord: y zCord: z];
			[tiles addObject:tile];
        }
    }
    return [NSArray arrayWithArray: tiles];
}
/*
 will fetch a tile image and cache it to NSCache.  The cache key is the url string itself
 */
- (void) fetchAndCacheImageTileAtURL: (NSString *)aUrlString
{
	MATAnimatedTileOverlay *overlay = self;

	[self.downLoadOperationQueue addOperationWithBlock: ^{
		
		NSData *cachedData = [overlay.imageTileCache objectForKey: aUrlString];

		if (cachedData != nil) {
			//do we want to do anything if we already have the cached tile data?
		} else {
			dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
			
			NSURLSession *session = [NSURLSession sharedSession];
			NSURLSessionTask *task = [session dataTaskWithURL: [NSURL URLWithString: aUrlString] completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
				
				NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)response;
				
				if (data) {
					if (urlResponse.statusCode == 200) {
						[overlay.imageTileCache setObject: data forKey: aUrlString];
					}
				} else {
					NSLog(@"error = %@", error);
				}
				
				dispatch_semaphore_signal(semaphore);
			}];
			[task resume];
			// have the thread wait until the download task is done
			dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 10));
		}
	}];
}


@end
