//
//  MATAnimatedTileOverlay.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//


#import "MATAnimatedTileOverlay.h"
#import "MATAnimationTile.h"
#import "MATAnimatedTileOverlayDelegate.h"

#define Z_INDEX "{z}"
#define X_INDEX "{x}"
#define Y_INDEX "{y}"

@interface MATAnimatedTileOverlay ()

@property (nonatomic, readwrite, strong) NSOperationQueue *fetchOperationQueue;
@property (nonatomic, readwrite, strong) NSOperationQueue *downLoadOperationQueue;

@property (nonatomic, readwrite, strong) NSMutableDictionary *tileDict;
//@property (nonatomic, readwrite, strong) NSLock *cacheLock;

@property (nonatomic, readwrite, strong) NSArray *templateURLs;
@property (nonatomic, readwrite) NSInteger numberOfAnimationFrames;
@property (nonatomic, assign) NSTimeInterval frameDuration;
@property (nonatomic, readwrite, strong) NSTimer *playBackTimer;
@property (readwrite, assign) MATAnimatingState currentAnimatingState;
@property (strong, nonatomic) NSSet *mapTiles;
@property (nonatomic) NSInteger tileSize;

- (NSString *) URLStringForX: (NSInteger)xValue Y: (NSInteger)yValue Z: (NSInteger)zValue timeIndex: (NSInteger)aTimeIndex;
- (NSSet *) mapTilesInMapRect: (MKMapRect)aRect zoomScale: (MKZoomScale)aScale;
- (void) fetchAndCacheImageTileAtURL: (NSString *)aUrlString;
- (MATTileCoordinate)tileCoordinateForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;
- (void)cancelAllOperations;

@end

@implementation MATAnimatedTileOverlay

{
    dispatch_queue_t _lockedQueue;
}

- (id) initWithTemplateURLs: (NSArray *)templateURLs frameDuration:(NSTimeInterval)frameDuration
{
    
    //Initialize network caching settings
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                         diskCapacity:20 * 1024 * 1024
                                                             diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];
    
	self = [super init];
	if (self)
	{
		NSString *queueName = [NSString stringWithFormat: @"com.%@.lockqueue", NSStringFromClass([self class])];
		_lockedQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_CONCURRENT);
        
		self.templateURLs = templateURLs;
		self.numberOfAnimationFrames = [templateURLs count];
		self.frameDuration = frameDuration;
		self.currentFrameIndex = 0;
		self.fetchOperationQueue = [[NSOperationQueue alloc] init];
		[self.fetchOperationQueue setMaxConcurrentOperationCount: 1];  //essentially a serial queue
		self.downLoadOperationQueue = [[NSOperationQueue alloc] init];
		[self.downLoadOperationQueue setMaxConcurrentOperationCount: 25];
		
		self.tileDict = [[NSMutableDictionary alloc] init];
        //		self.cache.name = NSStringFromClass([MATAnimatedTileOverlay class]);
        //		self.cache.countLimit = 2048;
        //		[self.cache setEvictsObjectsWithDiscardedContent: YES];
        //		[self.cache setTotalCostLimit: 2048];
        //      self.cacheLock = [[NSLock alloc] init];
        
		self.tileSize = 256;
		
		self.currentAnimatingState = MATAnimatingStateStopped;
		
	}
	return self;
}

- (void) dealloc
{
	[self.tileDict removeAllObjects];
}

//setter for currentAnimatingState
- (void) setCurrentAnimatingState:(MATAnimatingState)currentAnimatingState {
    //set new animating state if state different than old value
    if(currentAnimatingState != _currentAnimatingState){
        _currentAnimatingState = currentAnimatingState;
        //call the optional delegate method – ensure the delegate object actually implements an optional method before the method is called
        if ([self.delegate respondsToSelector:@selector(animatedTileOverlay:didChangeAnimationState:)]) {
            [self.delegate animatedTileOverlay:self didChangeAnimationState:_currentAnimatingState];
        }
    }
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

- (void) startAnimating;
{
	self.playBackTimer = [NSTimer scheduledTimerWithTimeInterval: self.frameDuration target: self selector: @selector(updateImageTileAnimation:) userInfo: nil repeats: YES];
	[self.playBackTimer fire];
    self.currentFrameIndex = self.currentPausedFrameIndex;
	self.currentAnimatingState = MATAnimatingStateAnimating;
    
}

- (void) pauseAnimating
{
	[self.playBackTimer invalidate];
	[self cancelAllOperations];
	self.playBackTimer = nil;
	self.currentAnimatingState = MATAnimatingStateStopped;
    self.currentPausedFrameIndex = self.currentFrameIndex;
}

- (void) cancelAllOperations
{
	[self.downLoadOperationQueue cancelAllOperations];
	[self.fetchOperationQueue cancelAllOperations];
}

/*
 will fetch all the tiles for a mapview's map rect and zoom scale.  Provides a download progres block and download completetion block
 */
- (void) fetchTilesForMapRect: (MKMapRect)aMapRect zoomScale: (MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, BOOL *stop))progressBlock completionBlock: (void (^)(BOOL success, NSError *error))completionBlock
{
    
	self.currentAnimatingState = MATAnimatingStateLoading;
    
	[self.fetchOperationQueue addOperationWithBlock:^{
		//calculate the tiles rects needed for a given mapRect and create the MATAnimationTile objects
		NSSet *mapTiles = [self mapTilesInMapRect: aMapRect zoomScale: aScale];
		
		//at this point we have a set of MATAnimationTiles we need to derive the urls for each tile, for each time index
		for (MATAnimationTile *tile in mapTiles) {
			
			NSMutableArray *array = [NSMutableArray arrayWithCapacity: self.numberOfAnimationFrames];
			
			for (NSUInteger timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
				NSString *tileURL = [self URLStringForX: tile.xCoordinate Y: tile.yCoordinate Z: tile.zCoordinate timeIndex: timeIndex];
				[array addObject: tileURL];
			}
			tile.tileURLs = [NSArray arrayWithArray: array];
		}
		
		//update the tile array with new tile objects
		self.mapTiles = mapTiles;
		//set and check a flag to see if the calling object has stopped tile loading
		__block BOOL didStopFlag = NO;
		//start downloading the tiles for a given time index, we want to download all the tiles for a time index
		//before we move onto the next time index
		for (NSUInteger timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
			if (didStopFlag == YES) {
				NSLog(@"User Stopped");
				[self.downLoadOperationQueue cancelAllOperations];
				self.currentAnimatingState = MATAnimatingStateStopped;
				break;
			}
			//loop over all the tiles for this time index
			for (MATAnimationTile *tile in self.mapTiles) {
				NSString *tileURL = [tile.tileURLs objectAtIndex: timeIndex];
				//this will return right away
				[self fetchAndCacheImageTileAtURL: tileURL];
			}
			//wait for all the tiles in this time index to download before proceeding the next time index
			[self.downLoadOperationQueue waitUntilAllOperationsAreFinished];
            
			dispatch_async(dispatch_get_main_queue(), ^{
				progressBlock(timeIndex, &didStopFlag);
			});
		}
		[self.downLoadOperationQueue waitUntilAllOperationsAreFinished];
        
		//set the current image to the first time index
		[self updateImageTilesToFrameIndex:self.currentFrameIndex];
		
		dispatch_async(dispatch_get_main_queue(), ^{
            
            completionBlock(!didStopFlag, nil);
            
		});
        
	}];
}
/*
 updates the currentFrameIndex property and updates the tiles to the current index.
*/
- (BOOL) updateToCurrentFrameIndex: (NSUInteger)currentFrameIndex
{
	if (self.currentFrameIndex > self.numberOfAnimationFrames - 1) {
		return NO;
	}

	self.currentFrameIndex = currentFrameIndex;
	[self updateImageTilesToFrameIndex: self.currentFrameIndex];
	return YES;
}

/*
 updates the MATAnimationTile tile image property to point to the tile image for the current time index
 */
- (void) updateImageTilesToFrameIndex:(NSUInteger)animationFrameIndex
{
	for (MATAnimationTile *tile in self.mapTiles) {
   		NSString *cacheKey = [tile.tileURLs objectAtIndex: animationFrameIndex];
		// Load the image from cache.
		//[self.cacheLock lock];
		NSData *cachedData = [[self imageTileCache] objectForKey: cacheKey];
		//[self.cacheLock unlock];
		if (cachedData) {
			UIImage *img = [[UIImage alloc] initWithData: cachedData];
			tile.currentImageTile = img;
		} else {
			tile.currentImageTile = nil;
		}
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate animatedTileOverlay: self didAnimateWithAnimationFrameIndex: self.currentFrameIndex];
	});

}

- (MATTileCoordinate) tileCoordinateForMapRect: (MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale
{
	MATTileCoordinate coord = {0 , 0, 0};
	
	NSUInteger zoomLevel = [self zoomLevelForZoomScale: aZoomScale];
    CGPoint mercatorPoint = [self mercatorTileOriginForMapRect: aMapRect];
    NSUInteger tilex = floor(mercatorPoint.x * [self worldTileWidthForZoomLevel:zoomLevel]);
    NSUInteger tiley = floor(mercatorPoint.y * [self worldTileWidthForZoomLevel:zoomLevel]);
    
	coord.xCoordinate = tilex;
	coord.yCoordinate = tiley;
	coord.zCoordiante = zoomLevel;
	
	return coord;
}

- (MATAnimationTile *) tileForMapRect: (MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;
{
	if (self.mapTiles) {
		MATTileCoordinate coord = [self tileCoordinateForMapRect: aMapRect zoomScale: aZoomScale];
		for (MATAnimationTile *tile in self.mapTiles) {
			if (coord.xCoordinate == tile.xCoordinate && coord.yCoordinate == tile.yCoordinate && coord.zCoordiante == tile.zCoordinate) {
				return tile;
			}
		}
	}
	
	return nil;
}

- (NSString *)templateURLStringForFrameIndex: (NSUInteger)animationFrameIndex
{
	NSString *returnURL = nil;
	if (self.templateURLs) {
		returnURL = [self.templateURLs objectAtIndex: animationFrameIndex];
	}
	return returnURL;
}

#pragma  mark - Private
/*
 called from the animation timer on a periodic basis
 */
- (void) updateImageTileAnimation: (NSTimer *)aTimer
{
	[self.fetchOperationQueue addOperationWithBlock:^{
		
		self.currentFrameIndex++;
//        NSLog(@"frame: %@", @(self.currentFrameIndex).stringValue);
		//reset the index counter if we have rolled over
		if (self.currentFrameIndex > self.numberOfAnimationFrames - 1) {
			self.currentFrameIndex = 0;
		}
        
		[self updateImageTilesToFrameIndex:self.currentFrameIndex];
	}];
}
/*
 locks access to the cache so that only one thread at a time can read/write to the cache
 */
- (NSMutableDictionary *)imageTileCache
{
	__block NSMutableDictionary *value;
	dispatch_sync(_lockedQueue, ^{
		value = _tileDict;
	});
	return value;
}
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
- (NSSet *) mapTilesInMapRect: (MKMapRect)aRect zoomScale: (MKZoomScale)aScale
{
    NSInteger z = [self zoomLevelForZoomScale: aScale];//zoomScaleToZoomLevel(aScale, (double)self.tileSize);
    NSMutableSet *tiles = nil;
	
    NSInteger minX = floor((MKMapRectGetMinX(aRect) * aScale) / self.tileSize);
    NSInteger maxX = ceil((MKMapRectGetMaxX(aRect) * aScale) / self.tileSize);
    NSInteger minY = floor((MKMapRectGetMinY(aRect) * aScale) / self.tileSize);
    NSInteger maxY = ceil((MKMapRectGetMaxY(aRect) * aScale) / self.tileSize);
	
	for(NSInteger x = minX; x <= maxX; x++) {
        for(NSInteger y = minY; y <=maxY; y++) {
			
			if (!tiles) {
				tiles = [NSMutableSet set];
			}
			MKMapRect frame = MKMapRectMake((double)(x * self.tileSize) / aScale, (double)(y * self.tileSize) / aScale, self.tileSize / aScale, self.tileSize / aScale);
			MATAnimationTile *tile = [[MATAnimationTile alloc] initWithFrame: frame xCord: x yCord: y zCord: z];
			[tiles addObject:tile];
        }
    }
    return [NSSet setWithSet: tiles];
}
/*
 will fetch a tile image and cache it to NSCache.  The cache key is the url string itself
 */
- (void) fetchAndCacheImageTileAtURL: (NSString *)aUrlString
{
	MATAnimatedTileOverlay *overlay = self;
    
	[self.downLoadOperationQueue addOperationWithBlock: ^{
		
		NSString *urlString = [aUrlString copy];
		
		//[overlay.cacheLock lock];
		NSData *cachedData = [[overlay imageTileCache] objectForKey: urlString];
		//[overlay.cacheLock unlock];
		if (cachedData) {
			//do we want to do anything if we already have the cached tile data?
		} else {
			dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            // Exploring caching in NSURLSession
            // Open questions:
            //   1. How do you configure the caching options for NSURLSession? (max size?)
            //   2. Can you tell before performing the request with the NSURLSession whether
            //      a cached copy exists?
            //   3. Is the eviction policy for this cache "deterministic"? We want newer tiles
            //      to stay in the cache longer than older tiles.
            //   4. What's the best compromise between cache size vs. performance? How many
            //      tiles do we really need?
			NSURLSession *session = [NSURLSession sharedSession];
			NSURLSessionTask *task = [session dataTaskWithURL: [NSURL URLWithString: urlString] completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
				
				NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)response;
				
				if (data) {
					if (urlResponse.statusCode == 200) {
						//[overlay.cacheLock lock];
						[[overlay imageTileCache] setObject: data forKey: urlString];
						//[overlay.cacheLock unlock];
					} else {
						NSLog(@"%s response status = %ld", __PRETTY_FUNCTION__, (long)urlResponse.statusCode);
					}
				} else {
					NSLog(@"error = %@", error);
				}
				dispatch_semaphore_signal(semaphore);
			}];
			[task resume];
			// have the thread wait until the download task is done
			dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 60)); //timeout is 10 secs.
		}
	}];
}
/*
 Determine the number of tiles wide *or tall* the world is, at the given zoomLevel.
 (In the Spherical Mercator projection, the poles are cut off so that the resulting 2D map is "square".)
 */
- (NSUInteger)worldTileWidthForZoomLevel:(NSUInteger)zoomLevel
{
    return (NSUInteger)(pow(2,zoomLevel));
}

/**
 * Similar to above, but uses a MKZoomScale to determine the
 * Mercator zoomLevel. (MKZoomScale is a ratio of screen points to
 * map points.)
 */
- (NSUInteger)zoomLevelForZoomScale:(MKZoomScale)zoomScale
{
    CGFloat realScale = zoomScale / [[UIScreen mainScreen] scale];
    NSUInteger z = (NSUInteger)(log(realScale)/log(2.0)+20.0);
	
    z += ([[UIScreen mainScreen] scale] - 1.0);
    return z;
}

/**
 * Given a MKMapRect, this reprojects the center of the mapRect
 * into the Mercator projection and calculates the rect's top-left point
 * (so that we can later figure out the tile coordinate).
 *
 * See http://wiki.openstreetmap.org/wiki/Slippy_map_tilenames#Derivation_of_tile_names
 */
- (CGPoint)mercatorTileOriginForMapRect:(MKMapRect)mapRect
{
    MKCoordinateRegion region = MKCoordinateRegionForMapRect(mapRect);
    
    // Convert lat/lon to radians
    CGFloat x = (region.center.longitude) * (M_PI/180.0); // Convert lon to radians
    CGFloat y = (region.center.latitude) * (M_PI/180.0); // Convert lat to radians
    y = log(tan(y)+1.0/cos(y));
    
    // X and Y should actually be the top-left of the rect (the values above represent
    // the center of the rect)
    x = (1.0 + (x/M_PI)) / 2.0;
    y = (1.0 - (y/M_PI)) / 2.0;
	
    return CGPointMake(x, y);
}

@end
