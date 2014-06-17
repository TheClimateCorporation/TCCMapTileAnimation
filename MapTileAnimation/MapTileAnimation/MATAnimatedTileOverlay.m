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
#define T_INDEX "{t}"


static NSInteger zoomScaleToZoomLevel(MKZoomScale scale, double overlaySize)
{
    // Conver an MKZoomScale to a zoom level where level 0 contains
    // four square tiles.
    double numberOfTilesAt1_0 = MKMapSizeWorld.width / overlaySize;
    
    //Add 1 to account for virtual tile
    NSInteger zoomLevelAt1_0 = log2(numberOfTilesAt1_0);
    NSInteger zoomLevel = MAX(0, zoomLevelAt1_0 + floor(log2f(scale) + 0.5));
    return zoomLevel;
}

@interface MATAnimatedTileOverlay ()

@property (nonatomic, readwrite, strong) NSOperationQueue *operationQueue;
@property (nonatomic, readwrite, strong) NSCache *imageTileCache;
@property (nonatomic, readwrite, strong) NSArray *templateURLs;
@property (nonatomic, assign) NSInteger numberOfAnimationFrames;
@property (nonatomic, assign) NSTimeInterval frameDuration;

- (NSString *) URLStringForX: (NSInteger)xValue Y: (NSInteger)yValue Z: (NSInteger)zValue;

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
		self.operationQueue = [[NSOperationQueue alloc] init];
		self.imageTileCache = [[NSCache alloc] init];
		self.imageTileCache.name = NSStringFromClass([MATAnimatedTileOverlay class]);
		self.imageTileCache.countLimit = 450;
		self.tileSize = 256;

	}
	return self;
}

- (void) dealloc
{
	[self.imageTileCache removeAllObjects];
}

- (void) updateWithTileArray: (NSArray *)aTileArray
{
	self.mapTiles = aTileArray;
}

- (void) cancelAllOperations
{
	[self.operationQueue cancelAllOperations];
}

- (NSString *) URLStringForX: (NSInteger)xValue Y: (NSInteger)yValue Z: (NSInteger)zValue
{
	NSString *currentTemplateURL = [self.templateURLs objectAtIndex: self.currentTimeIndex];
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

- (CLLocationCoordinate2D)coordinate
{
    return MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX([self boundingMapRect]), MKMapRectGetMidY([self boundingMapRect])));
}

- (MKMapRect)boundingMapRect
{
    return MKMapRectWorld;
}

- (void) fetchTilesForMapRect: (MKMapRect)aMapRect zoomScale: (MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, NSError *error))progressBlock completionBlock: (void (^)(BOOL success, NSError *error))completionBlock
{
	NSArray *mapTiles = [self mapTilesInMapRect: aMapRect zoomScale: aScale];
	NSInteger counter = 0;
	for (MATAnimationTile *tile in mapTiles) {
		
		NSString *tileURL = [self URLStringForX: tile.xCoordinate Y: tile.yCoordinate Z: tile.zCoordinate];
		[self fetchTileImage: tile URLString: tileURL];
		counter++;
	}
	
	[self.operationQueue waitUntilAllOperationsAreFinished];
	
	self.mapTiles = mapTiles;
	completionBlock(YES, nil);
}

- (NSArray *) mapTilesInMapRect: (MKMapRect)aRect zoomScale: (MKZoomScale)aScale
{
    NSInteger z = zoomScaleToZoomLevel(aScale, (double)self.tileSize);
    NSMutableArray *tiles = nil;
	
    // The number of tiles either wide or high.
	//	NSInteger zTiles = pow(2, z);
    
    NSInteger minX = floor((MKMapRectGetMinX(aRect) * aScale) / self.tileSize);
    NSInteger maxX = floor((MKMapRectGetMaxX(aRect) * aScale) / self.tileSize);
    NSInteger minY = floor((MKMapRectGetMinY(aRect) * aScale) / self.tileSize);
    NSInteger maxY = floor((MKMapRectGetMaxY(aRect) * aScale) / self.tileSize);
	
	for(NSInteger x = minX; x <= maxX; x++) {
        for(NSInteger y = minY; y <=maxY; y++) {
            // Flip the y index to properly reference overlay files.
			//			NSInteger flippedY = abs(y + 1 - zTiles);
//            NSString *tileCoord = [[NSString alloc] initWithFormat:@"%ld/%ld/%ld", (long)z, (long)x, (long)y];
			
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

- (void) fetchTileImage: (MATAnimationTile *)aMapTile URLString: (NSString *)aURLString;
{
	MATAnimationTile *mapTile = aMapTile;
	MATAnimatedTileOverlay *overlay = self;
	
	[self.operationQueue addOperationWithBlock: ^{
		dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
		
		NSString *cacheKey = aURLString;
		
		NSData *cachedData = [overlay.imageTileCache objectForKey: cacheKey];
		if (cachedData != nil)
		{
//			NSLog(@"using cached data");
			UIImage *img = [[UIImage alloc] initWithData: cachedData];
			mapTile.imageTile = img;
			dispatch_semaphore_signal(semaphore);
		}
		else
		{
//			NSString *urlString = [NSString stringWithFormat: @"%@/%@.png", aURLString, mapTile.tileCoordinate];
			//			NSLog(@"derived->urlString = %@", urlString);
			
			NSURLSession *session = [NSURLSession sharedSession];
			NSURLSessionTask *task = [session dataTaskWithURL: [NSURL URLWithString: aURLString] completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
				
				NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)response;
				//				NSLog(@"response %d %@", urlResponse.statusCode, error.localizedDescription);
				
				if (data) {
					if (urlResponse.statusCode == 200) {
						[overlay.imageTileCache setObject: data forKey: cacheKey];
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

@end
