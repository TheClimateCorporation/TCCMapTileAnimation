//
//  TCCAnimationTileOverlay.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCAnimationTileOverlay.h"
#import "TCCAnimationTile.h"

// TODO: This should be documented as the expected format of the template URLs
#define Z_INDEX "{z}"
#define X_INDEX "{x}"
#define Y_INDEX "{y}"

NSString *const TCCAnimationTileOverlayErrorDomain = @"TCCAnimationTileOverlayError";

@interface TCCAnimationTileOverlay ()

@property (strong, nonatomic) NSOperationQueue *downloadQueue;
@property (strong, nonatomic) NSArray *templateURLs;
@property (nonatomic) NSTimeInterval frameDuration;
@property (strong, nonatomic) NSTimer *timer;
@property (readwrite, nonatomic) TCCAnimationState currentAnimationState;
@property (strong, nonatomic) NSSet *mapTiles;
@property (strong, nonatomic) MKTileOverlay *tileOverlay;
@property (strong, nonatomic) MKMapView *mapView;

@end

// TODO: Purge NSURLCache on memory warnings

@implementation TCCAnimationTileOverlay

#pragma mark - Lifecycle

- (instancetype)initWithMapView:(MKMapView *)mapView templateURLs:(NSArray *)templateURLs frameDuration:(NSTimeInterval)frameDuration minimumZ:(NSInteger)minimumZ maximumZ:(NSInteger)maximumZ tileSize:(NSInteger)tileSize
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
        // Download queue uses 4 by default
		_downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 4;
		
		_currentAnimationState = TCCAnimationStateStopped;

        _mapView = mapView;
        _minimumZ = minimumZ;
        _maximumZ = maximumZ;
        _tileSize = tileSize;
        [self addStaticTileOverlay];
	}
	return self;
}

#pragma mark - Custom accessors

- (void)setCurrentAnimationState:(TCCAnimationState)currentAnimationState
{
    // Set new animating state if state different than old value
    if (currentAnimationState != _currentAnimationState){
        TCCAnimationState previousAnimationState = _currentAnimationState;
        _currentAnimationState = currentAnimationState;
        [self.delegate animationTileOverlay:self didChangeFromAnimationState:previousAnimationState toAnimationState:currentAnimationState];
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
    self.currentFrameIndex = (self.currentFrameIndex + 1) % (self.numberOfAnimationFrames);
    [self updateTilesToFrameIndex:self.currentFrameIndex];
}

#pragma mark - Public

- (void)startAnimating;
{
    [self removeStaticTileOverlay];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:self.frameDuration target:self selector:@selector(updateImageTileAnimation:) userInfo:nil repeats:YES];
	[self.timer fire];
	self.currentAnimationState = TCCAnimationStateAnimating;
    
}

- (void)pauseAnimating
{
	[self.timer invalidate];
    [self.downloadQueue cancelAllOperations];
	self.timer = nil;
	self.currentAnimationState = TCCAnimationStateStopped;
    if (self.tileOverlay) [self removeStaticTileOverlay];
    [self addStaticTileOverlay];
}

- (void)cancelLoading
{
    [self pauseAnimating];
}

- (void)fetchTilesForMapRect:(MKMapRect)mapRect
                   zoomScale:(MKZoomScale)zoomScale
               progressHandler:(void(^)(NSUInteger currentFrameIndex))progressHandler
             completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    if (self.templateURLs.count == 0) {
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:TCCAnimationTileOverlayErrorDomain
                                                 code:TCCAnimationTileOverlayErrorNoFrames
                                             userInfo:nil];
                completionHandler(NO, error);
        }
        return;
    }
    
    self.currentAnimationState = TCCAnimationStateLoading;
    
    // Cap the zoom level of the tiles to fetch if the current zoom scale is not
    // supported by the tile server
	NSUInteger zoomLevel = [self zoomLevelForZoomScale:zoomScale];
    zoomLevel = MIN(zoomLevel, self.maximumZ);
    zoomLevel = MAX(zoomLevel, self.minimumZ);
    
    // Generate list of tiles on the screen to fetch
    self.mapTiles = [self mapTilesInMapRect:mapRect zoomScale:zoomScale];
    
    // Fill in map tiles with an array of template URL strings, one for each frame
    for (TCCAnimationTile *tile in self.mapTiles) {
        NSMutableArray *array = [NSMutableArray array];
        for (NSUInteger timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
            [array addObject:[self URLStringForX:tile.x Y:tile.y Z:tile.z timeIndex:timeIndex]];
        }
        tile.templateURLs = [array copy];
    }
    
    // "Completion" done op - detects when all fetch operations have completed
    NSBlockOperation *completionDoneOp = [NSBlockOperation blockOperationWithBlock:^{
        [self updateTilesToFrameIndex:self.currentFrameIndex];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(YES, nil);
        });
    }];

    // Initiate fetch operations for tiles for each frame
    for (NSInteger frameIndex = 0; frameIndex < self.numberOfAnimationFrames; frameIndex++) {
        // Create "Done" operation for this animation frame -- need this to signal when
        // all tiles for this frame have finished downloading so we can fire progress handler
        NSBlockOperation *doneOp = [NSBlockOperation blockOperationWithBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                progressHandler(frameIndex + 1);
            });
        }];
        
        // Fetch and cache the tile data
        for (TCCAnimationTile *tile in self.mapTiles) {
            // Create NSOperation to fetch tile
            NSBlockOperation *fetchTileOp = [NSBlockOperation blockOperationWithBlock:^{
                //if tile not in failedMapTiles, tile not bad -> go and fetch the tile
                if (!tile.failedToFetch) {
                    [self fetchAndCacheTile:tile forFrameIndex:frameIndex];
                }
            }];
            
            // Add a dependency from the "Done" operation onto this operation
            [doneOp addDependency:fetchTileOp];
            
            // Queue it onto the download queue
            [self.downloadQueue addOperation:fetchTileOp];
        }
        
        // Queue the "Done" operation
        [self.downloadQueue addOperation:doneOp];
        [completionDoneOp addDependency:doneOp];
    }
    
    [self.downloadQueue addOperation:completionDoneOp];
}

- (void)moveToFrameIndex:(NSInteger)frameIndex isContinuouslyMoving:(BOOL)isContinuouslyMoving
{
    if (self.currentAnimationState == TCCAnimationStateAnimating) {
        [self pauseAnimating];
    }
    
    // Determine when the user has finished moving animation frames (i.e. scrubbing) to toggle
    // the tiled overlay on and off.
    if (!isContinuouslyMoving) {
        [self addStaticTileOverlay];
        return;
    } else if (self.tileOverlay) {
        [self removeStaticTileOverlay];
    }
    
    [self updateTilesToFrameIndex:frameIndex];
}

- (TCCAnimationTile *)tileForMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale;
{
    TCCTileCoordinate coord = [self tileCoordinateForMapRect:mapRect zoomScale:zoomScale];
    for (TCCAnimationTile *tile in self.mapTiles) {
        if (coord.x == tile.x && coord.y == tile.y && coord.z == tile.z) {
            return tile;
        }
    }
	return nil;
}

- (NSArray *)cachedTilesForMapRect:(MKMapRect)rect
{
    NSMutableArray *tiles = [NSMutableArray array];
    for (TCCAnimationTile *tile in self.mapTiles) {
        if (MKMapRectIntersectsRect(rect, tile.mapRectFrame)) {
            [tiles addObject:tile];
        }
    }
    return [tiles copy];
}

#pragma  mark - Private

- (void)fetchAndCacheTile:(TCCAnimationTile *)tile forFrameIndex:(NSInteger)frameIndex
{
    // TODO: Wrap this code in a subclass of NSOperation
    //
    // We use the semaphore to force this method to become synchronous so that
    // we have better control over when this method call finishes. This is necessary
    // since this is wrapped in an NSOperation, and we need to know when that
    // operation has truly finished.
    //
    // Ideally, we'd subclass NSOperation to work with NSURLSession so that we can
    // queue those up instead. For now, this is okay.
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    NSURLSession *session = [NSURLSession sharedSession];
    NSURL *url = [NSURL URLWithString:tile.templateURLs[frameIndex]];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                  cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                              timeoutInterval:0];
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([self checkResponseForError:(NSHTTPURLResponse *)response data:data]) {
            tile.failedToFetch = YES;
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    
    // Have the thread wait until the download task is done. Timeout is 10 secs.
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 60));
}

- (void)updateTilesToFrameIndex:(NSInteger)frameIndex
{
    // RSS: Tried to have this data updating occur on a background thread, but it causes threading issues.
    // I wanted this in the background so that it doesn't block the main thread when it's loading cached
    // data. However, scrubbing quickly causes multiple calls to occur concurrently, which causes the
    // currentFrameIndex to enter a race condition. If we want to do this in the background, I think we'll
    // need to create a serial background queue.
    for (TCCAnimationTile *tile in self.mapTiles) {
        if (tile.failedToFetch) {
            continue;
        }
        
        NSURL *url = [[NSURL alloc] initWithString:tile.templateURLs[frameIndex]];
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
        [self.delegate animationTileOverlay:self didAnimateWithAnimationFrameIndex:self.currentFrameIndex];
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

- (TCCTileCoordinate)tileCoordinateForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale
{
	TCCTileCoordinate coord = {0, 0, 0};
    
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
    // Ripped from http://stackoverflow.com/a/4445576/766491
    NSInteger zoomLevel = [self zoomLevelForZoomScale:zoomScale];
    NSInteger overZoom = 1;
    
    if (zoomLevel > self.maximumZ) {
        overZoom = pow(2, (zoomLevel - self.maximumZ));
        zoomLevel = self.maximumZ;
    }
    
    // When we are zoomed in beyond the tile set, use the tiles from the maximum z-depth,
    // but render them larger.
    // **Adjusted from overZoom * self.tileSize to just self.tileSize in order to render at overzoom properly
    NSInteger adjustedTileSize = self.tileSize;
    NSLog(@"overzoom: %ld", (long)overZoom);

    // Need to use the zoom level zoom scale, not the actual zoom scale from the map view!
    NSInteger zoomExponent = 20 - zoomLevel;
    zoomScale = 1/pow(2, zoomExponent);
    NSLog(@"scale: %f", zoomScale);
    
    NSInteger minX = floor((MKMapRectGetMinX(rect) * zoomScale) / adjustedTileSize);
    NSInteger maxX = ceil((MKMapRectGetMaxX(rect) * zoomScale) / adjustedTileSize);
    NSInteger minY = floor((MKMapRectGetMinY(rect) * zoomScale) / adjustedTileSize);
    NSInteger maxY = ceil((MKMapRectGetMaxY(rect) * zoomScale) / adjustedTileSize);
    
    NSMutableSet *tiles = [NSMutableSet set];
	for (NSInteger x = minX; x <= maxX; x++) {
        for (NSInteger y = minY; y <=maxY; y++) {
			MKMapRect frame = MKMapRectMake((x * adjustedTileSize) / zoomScale, (y * adjustedTileSize) / zoomScale, adjustedTileSize / zoomScale, adjustedTileSize / zoomScale);
            if (MKMapRectIntersectsRect(frame, rect)) {
                NSLog(@"tile: x %ld, y %ld", (long)x, (long)y);
                TCCAnimationTile *tile = [[TCCAnimationTile alloc] initWithFrame:frame x:x y:y z:zoomLevel];
                [tiles addObject:tile];
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
            NSError *error = [NSError errorWithDomain:TCCAnimationTileOverlayErrorDomain code:TCCAnimationTileOverlayErrorBadURLResponseCode userInfo:@{ NSLocalizedDescriptionKey : localizedDescription }];
            [self sendErrorToDelegate:error];
            return YES;
        }
    } else {
        NSString *localizedDescription = [NSString stringWithFormat:@"No image data. HTTP respsonse code %ld, URL %@", (long)response.statusCode, response.URL];
        NSError *error = [NSError errorWithDomain:TCCAnimationTileOverlayErrorDomain code:TCCAnimationTileOverlayErrorNoImageData userInfo:@{ NSLocalizedDescriptionKey : localizedDescription }];
        [self sendErrorToDelegate:error];
        return YES;
    }
    return NO;
}

- (void)sendErrorToDelegate:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(animationTileOverlay:didHaveError:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate animationTileOverlay:self didHaveError:error];
        });
    }
}

- (void)addStaticTileOverlay
{
    // Prevent index out of bounds error from crashing app when we don't have a template URL for
    // the current timestamp
    if (self.templateURLs.count <= self.currentFrameIndex) return;
    
    self.tileOverlay = [[MKTileOverlay alloc] initWithURLTemplate:self.templateURLs[self.currentFrameIndex]];
    self.tileOverlay.minimumZ = self.minimumZ;
    self.tileOverlay.maximumZ = self.maximumZ;
    [self.mapView addOverlay:self.tileOverlay];
}

- (void)removeStaticTileOverlay
{
    [self.mapView removeOverlay:self.tileOverlay];
    self.tileOverlay = nil;
}

@end
