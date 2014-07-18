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

// This should be documented as the expected format of the template URLs
#define Z_INDEX "{z}"
#define X_INDEX "{x}"
#define Y_INDEX "{y}"

NSString *const MATAnimatedTileOverlayErrorDomain = @"MATAnimatedTileOverlayError";

@interface MATAnimatedTileOverlay ()

@property (strong, nonatomic) NSOperationQueue *fetchQueue;
@property (strong, nonatomic) NSOperationQueue *downloadQueue;
@property (strong, nonatomic) NSArray *templateURLs;
@property (nonatomic) NSTimeInterval frameDuration;
@property (strong, nonatomic) NSTimer *timer;
@property (readwrite, nonatomic) MATAnimatingState currentAnimatingState;
@property (strong, nonatomic) NSSet *mapTiles;
@property (strong, nonatomic) NSMutableSet *failedMapTiles;
@property (nonatomic) NSInteger tileSize;
@property (strong, nonatomic) MKTileOverlay *tileOverlay;
@property (strong, nonatomic) MKMapView *mapView;

@end

// TODO: Purge NSURLCache on memory warnings

@implementation MATAnimatedTileOverlay

#pragma mark - Lifecycle

- (instancetype)initWithMapView:(MKMapView *)mapView templateURLs:(NSArray *)templateURLs frameDuration:(NSTimeInterval)frameDuration;
{
	self = [super init];
	if (self)
	{
        //Initialize network caching settings
        NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                             diskCapacity:32 * 1024 * 1024
                                                                 diskPath:nil];
        [NSURLCache setSharedURLCache:URLCache];
        
		_templateURLs = templateURLs;
		_numberOfAnimationFrames = [templateURLs count];
		_frameDuration = frameDuration;
		_currentFrameIndex = 0;
		_fetchQueue = [[NSOperationQueue alloc] init];
		[_fetchQueue setMaxConcurrentOperationCount: 1];  //essentially a serial queue
		_downloadQueue = [[NSOperationQueue alloc] init];
		[_downloadQueue setMaxConcurrentOperationCount: 25];
        _failedMapTiles = [NSMutableSet set];
		
		_currentAnimatingState = MATAnimatingStateStopped;
		
        // TODO: make this configurable
        self.tileSize = 256;
        self.minimumZ = 3;
		self.maximumZ = 9;

        _mapView = mapView;
        _tileOverlay = [[MKTileOverlay alloc] initWithURLTemplate:_templateURLs[0]];
        [_mapView addOverlay:_tileOverlay];
	}
	return self;
}

#pragma mark - Custom accessors

- (void)setCurrentAnimatingState:(MATAnimatingState)currentAnimatingState
{
    // Set new animating state if state different than old value
    if(currentAnimatingState != _currentAnimatingState){
        _currentAnimatingState = currentAnimatingState;
        if ([self.delegate respondsToSelector:@selector(animatedTileOverlay:didChangeAnimationState:)]) {
            [self.delegate animatedTileOverlay:self didChangeAnimationState:currentAnimatingState];
        }
    }
}

#pragma mark MKOverlay

- (CLLocationCoordinate2D)coordinate {
    return MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX([self boundingMapRect]), MKMapRectGetMidY([self boundingMapRect])));
}

- (MKMapRect)boundingMapRect {
    return MKMapRectWorld;
}

#pragma mark - IBActions

- (IBAction)updateImageTileAnimation:(NSTimer *)aTimer
{
	[self.fetchQueue addOperationWithBlock:^{
        self.currentFrameIndex = (self.currentFrameIndex + 1) % (self.numberOfAnimationFrames - 1);
        [self updateTilesToFrameIndex:self.currentFrameIndex];
	}];
}

#pragma mark - Public

- (void)startAnimating;
{
    [self.mapView removeOverlay:self.tileOverlay];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:self.frameDuration target:self selector:@selector(updateImageTileAnimation:) userInfo:nil repeats:YES];
	[self.timer fire];
	self.currentAnimatingState = MATAnimatingStateAnimating;
    
}

- (void)pauseAnimating
{
	[self.timer invalidate];
    [self.downloadQueue cancelAllOperations];
	[self.fetchQueue cancelAllOperations];
	self.timer = nil;
	self.currentAnimatingState = MATAnimatingStateStopped;
    self.tileOverlay = [[MKTileOverlay alloc] initWithURLTemplate:self.templateURLs[self.currentFrameIndex]];
    [self.mapView addOverlay:self.tileOverlay];
}

- (void)fetchTilesForMapRect:(MKMapRect)mapRect
                   zoomScale:(MKZoomScale)zoomScale
               progressHandler:(void(^)(NSUInteger currentFrameIndex, BOOL *stop))progressHandler
             completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
	NSUInteger zoomLevel = [self zoomLevelForZoomScale: zoomScale];
    NSLog(@"Actual zoom scale: %lf, zoom level: %d", zoomScale, zoomLevel);
    
    if(zoomLevel > self.maximumZ) {
        zoomLevel = self.maximumZ;
        NSLog(@"Capped zoom level at %d", zoomLevel);
    }
    if(zoomLevel < self.minimumZ) {
        zoomLevel = self.minimumZ;
        NSLog(@"Capped zoom level at %d", zoomLevel);
    }

	self.currentAnimatingState = MATAnimatingStateLoading;
    
	[self.fetchQueue addOperationWithBlock:^{
		NSSet *mapTiles = [self mapTilesInMapRect:mapRect zoomScale:zoomScale];
		
		for (MATAnimationTile *tile in mapTiles) {
			NSMutableArray *array = [NSMutableArray array];
			for (NSUInteger timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
				[array addObject:[self URLStringForX:tile.x Y:tile.y Z:tile.z timeIndex:timeIndex]];
			}
			tile.tileURLs = [array copy];
		}
		
		//update the tile array with new tile objects
		self.mapTiles = mapTiles;
		//set and check a flag to see if the calling object has stopped tile loading
		__block BOOL didStopFlag = NO;

		for (NSInteger frameIndex = 0; frameIndex < self.numberOfAnimationFrames; frameIndex++) {
			if (didStopFlag) {
				NSLog(@"User Stopped");
				[self.downloadQueue cancelAllOperations];
				self.currentAnimatingState = MATAnimatingStateStopped;
				break;
			}
            
            // Fetch and cache the tile data
			for (MATAnimationTile *tile in self.mapTiles) {
                BOOL isFailedTile = [self.failedMapTiles containsObject:tile];
                
                //if tile not in failedMapTiles, tile not bad -> go and fetch the tile
                if (!isFailedTile) {
                    [self enqueueOperationOnQueue:self.downloadQueue toFetchAndCacheTile:tile forFrameIndex:frameIndex];
                }
			}
            
			// Wait for all the tiles in this frame index to finish downloading before proceeding
			[self.downloadQueue waitUntilAllOperationsAreFinished];
            
			dispatch_async(dispatch_get_main_queue(), ^{
				progressHandler(frameIndex, &didStopFlag);
			});
		}
		[self.downloadQueue waitUntilAllOperationsAreFinished];
        
		//set the current image to the first time index
		[self moveToFrameIndex:self.currentFrameIndex isContinuouslyMoving:YES];
		
		dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(!didStopFlag, nil);
		});
	}];
}

- (void)moveToFrameIndex:(NSInteger)frameIndex isContinuouslyMoving:(BOOL)isContinuouslyMoving
{
    if (self.currentAnimatingState == MATAnimatingStateAnimating) {
        [self pauseAnimating];
    }
    
    // Determine when the user has finished moving animation frames (i.e. scrubbing) to toggle
    // the tiled overlay on and off.
    if (!isContinuouslyMoving) {
        self.tileOverlay = [[MKTileOverlay alloc] initWithURLTemplate:self.templateURLs[self.currentFrameIndex]];
        [self.mapView addOverlay:self.tileOverlay];
    } else if (self.tileOverlay) {
        [self.mapView removeOverlay:self.tileOverlay];
        self.tileOverlay = nil;
    }
    
    [self updateTilesToFrameIndex:frameIndex];
}

- (MATAnimationTile *)tileForMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale;
{
    MATTileCoordinate coord = [self tileCoordinateForMapRect:mapRect zoomScale:zoomScale];
    for (MATAnimationTile *tile in self.mapTiles) {
        if (coord.x == tile.x && coord.y == tile.y && coord.z == tile.z) {
            return tile;
        }
    }
	return nil;
}

- (NSArray *)cachedTilesForMapRect:(MKMapRect)rect
{
    NSMutableArray *tiles = [NSMutableArray array];
    for (MATAnimationTile *tile in self.mapTiles) {
        if (MKMapRectIntersectsRect(rect, tile.mapRectFrame)) {
            [tiles addObject:tile];
        }
    }
    return [tiles copy];
}

#pragma  mark - Private


- (void)enqueueOperationOnQueue:(NSOperationQueue *)queue toFetchAndCacheTile:(MATAnimationTile *)tile forFrameIndex:(NSInteger)frameIndex
{
    // TODO: do we really need to check failedMapTiles both here and in fetch?
    //if tile not in failedMapTiles, go and fetch the tile
    if ([self.failedMapTiles containsObject:tile]) {
        return;
    }
    
	[queue addOperationWithBlock:^{
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        NSURLSession *session = [NSURLSession sharedSession];
        NSURL *url = [NSURL URLWithString:tile.tileURLs[frameIndex]];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                      cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                  timeoutInterval:0];
        NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            
            //parse URL and add to failed map tiles set
            BOOL errorResponse = [self checkResponseForError:(NSHTTPURLResponse *)response data:data];
            
            //there is an error 
            if(errorResponse) {
                [self.failedMapTiles addObject:tile];
            }
            
            dispatch_semaphore_signal(semaphore);
        }];
        [task resume];

        // Have the thread wait until the download task is done. Timeout is 10 secs.
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 60));
	}];
}

- (void)updateTilesToFrameIndex:(NSInteger)frameIndex
{
    // RSS: Tried to have this data updating occur on a background thread, but it causes threading issues.
    // I wanted this in the background so that it doesn't block the main thread when it's loading cached
    // data. However, scrubbing quickly causes multiple calls to occur concurrently, which causes the
    // currentFrameIndex to enter a race condition. If we want to do this in the background, I think we'll
    // need to create a serial background queue.
    for (MATAnimationTile *tile in self.mapTiles) {
        if ([self.failedMapTiles containsObject:tile]) {
            continue;
        }
        
        NSURL *url = [[NSURL alloc] initWithString:tile.tileURLs[frameIndex]];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:1];
        NSURLResponse *response;
        NSError *error;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        BOOL errorOccurred = [self checkResponseForError:(NSHTTPURLResponse *)response data:data];
        
        if (!errorOccurred) {
            tile.tileImage = [UIImage imageWithData:data];
        }
    }
    
    self.currentFrameIndex = frameIndex;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate animatedTileOverlay:self didAnimateWithAnimationFrameIndex:self.currentFrameIndex];
    });
}

/*
 derives a URL string from the template URLs, needs tile coordinates and a time index
 */
- (NSString *)URLStringForX:(NSInteger)xValue Y:(NSInteger)yValue Z:(NSInteger)zValue timeIndex:(NSInteger)aTimeIndex
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

- (MATTileCoordinate)tileCoordinateForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale
{
	MATTileCoordinate coord = {0, 0, 0};
    
	NSUInteger zoomLevel = [self zoomLevelForZoomScale: aZoomScale];
    CGPoint mercatorPoint = [self mercatorTileOriginForMapRect: aMapRect];
    
	coord.x = floor(mercatorPoint.x * [self worldTileWidthForZoomLevel:zoomLevel]);;
	coord.y = floor(mercatorPoint.y * [self worldTileWidthForZoomLevel:zoomLevel]);
	coord.z = zoomLevel;
	return coord;
}

// Creates a set of @c MATAnimationTile objects for a given map rect and zoom scale
- (NSSet *)mapTilesInMapRect:(MKMapRect)rect zoomScale:(MKZoomScale)zoomScale
{
    NSLog(@"Zoom scale in mapTilesInMapRect: %f", zoomScale);
    
    // Ripped from http://stackoverflow.com/a/4445576/766491
    NSInteger zoomLevel = [self zoomLevelForZoomScale:zoomScale];
    NSInteger overZoom = 1;
    
    if (zoomLevel > self.maximumZ) {
        overZoom = pow(2, (zoomLevel - self.maximumZ));
        zoomLevel = self.maximumZ;
    }
    
    // When we are zoomed in beyond the tile set, use the tiles from the maximum z-depth,
    // but render them larger.
    NSInteger adjustedTileSize = overZoom * self.tileSize;
	
    NSInteger minX = floor((MKMapRectGetMinX(rect) * zoomScale) / adjustedTileSize);
    NSInteger maxX = ceil((MKMapRectGetMaxX(rect) * zoomScale) / adjustedTileSize);
    NSInteger minY = floor((MKMapRectGetMinY(rect) * zoomScale) / adjustedTileSize);
    NSInteger maxY = ceil((MKMapRectGetMaxY(rect) * zoomScale) / adjustedTileSize);
    
    NSMutableSet *tiles = [NSMutableSet set];
	for (NSInteger x = minX; x <= maxX; x++) {
        for (NSInteger y = minY; y <=maxY; y++) {
			MKMapRect frame = MKMapRectMake((x * adjustedTileSize) / zoomScale, (y * adjustedTileSize) / zoomScale, adjustedTileSize / zoomScale, adjustedTileSize / zoomScale);
            if (MKMapRectIntersectsRect(frame, rect)) {
                [tiles addObject:[[MATAnimationTile alloc] initWithFrame:frame x:x y:y z:zoomLevel]];
            }
        }
    }
    return [tiles copy];
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

- (BOOL)checkResponseForError:(NSHTTPURLResponse *)response data:(NSData *)data
{
    
    if (data) {
        if (response.statusCode != 200) {
            
            NSString *localizedDescription = [NSString stringWithFormat:@"Error during fetch. Image tile HTTP respsonse code %ld, URL %@", (long)response.statusCode, response.URL];
            NSError *error = [NSError errorWithDomain:MATAnimatedTileOverlayErrorDomain code:MATAnimatingErrorBadURLResponseCode userInfo:@{ NSLocalizedDescriptionKey : localizedDescription }];
            [self sendErrorToDelegate:error];
            return YES;
            
        }
    } else {
        NSString *localizedDescription = [NSString stringWithFormat:@"No image data. HTTP respsonse code %ld, URL %@", (long)response.statusCode, response.URL];
        NSError *error = [NSError errorWithDomain:MATAnimatedTileOverlayErrorDomain code:MATAnimatingErrorNoImageData userInfo:@{ NSLocalizedDescriptionKey : localizedDescription }];
        [self sendErrorToDelegate:error];
        return YES;
    }
    return NO;
}

- (void)sendErrorToDelegate:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(animatedTileOverlay:didHaveError:)]) {
        [self.delegate animatedTileOverlay:self didHaveError:error];
    }
}

@end
