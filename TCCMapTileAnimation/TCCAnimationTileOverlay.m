//
//  TCCAnimationTileOverlay.m
//  MapTileAnimationDemo
//
//  Created by Bruce Johnson on 6/12/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCAnimationTileOverlay.h"
#import "TCCAnimationTile.h"
#import "TCCMapKitHelpers.h"

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
@property (strong, nonatomic) NSSet *animationTiles;
@property (strong, nonatomic) NSCache *staticTilesCache;
@property (strong, nonatomic) NSLock *staticTilesLock;
@property (strong, nonatomic) MKMapView *mapView;

@end

@implementation TCCAnimationTileOverlay

#pragma mark - Lifecycle

- (instancetype)initWithMapView:(MKMapView *)mapView
                   templateURLs:(NSArray *)templateURLs
                  frameDuration:(NSTimeInterval)frameDuration
                       minimumZ:(NSInteger)minimumZ
                       maximumZ:(NSInteger)maximumZ
                       tileSize:(CGSize)tileSize
{
	if (self = [super init]) {
        //Initialize network caching settings
        NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                             diskCapacity:32 * 1024 * 1024
                                                                 diskPath:nil];
        [NSURLCache setSharedURLCache:URLCache];
        
		_templateURLs = templateURLs;
		_numberOfAnimationFrames = [templateURLs count];
		_frameDuration = frameDuration;
		_currentFrameIndex = 0;
		_downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 4;
		
		_currentAnimationState = TCCAnimationStateStopped;

        _mapView = mapView;
        self.minimumZ = minimumZ;
        self.maximumZ = maximumZ;
        self.tileSize = tileSize;
        
        _staticTilesCache = [[NSCache alloc] init];
        _staticTilesLock = [[NSLock alloc] init];
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

- (IBAction)updateAnimationTiles:(NSTimer *)aTimer
{
    self.currentFrameIndex = (self.currentFrameIndex + 1) % (self.numberOfAnimationFrames);
    [self updateAnimationTilesToFrameIndex:self.currentFrameIndex];
}

#pragma mark - Public

- (void)startAnimating;
{
	self.timer = [NSTimer scheduledTimerWithTimeInterval:self.frameDuration target:self selector:@selector(updateAnimationTiles:) userInfo:nil repeats:YES];
	[self.timer fire];
	self.currentAnimationState = TCCAnimationStateAnimating;
}

- (void)pauseAnimating
{
	[self.timer invalidate];
    [self.downloadQueue cancelAllOperations];
	self.timer = nil;
	self.currentAnimationState = TCCAnimationStateStopped;
}

- (void)cancelLoading
{
    [self pauseAnimating];
}

- (void)fetchTilesForMapRect:(MKMapRect)mapRect
                   zoomLevel:(NSUInteger)zoomLevel
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
    zoomLevel = MIN(zoomLevel, self.maximumZ);
    zoomLevel = MAX(zoomLevel, self.minimumZ);
    
    // Generate list of tiles on the screen to fetch
    self.animationTiles = [self mapTilesInMapRect:mapRect zoomLevel:zoomLevel];
    
    // Fill in map tiles with an array of template URL strings, one for each frame
    for (TCCAnimationTile *tile in self.animationTiles) {
        NSMutableArray *array = [NSMutableArray array];
        for (NSUInteger timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
            [array addObject:[self URLStringForX:tile.x Y:tile.y Z:tile.z timeIndex:timeIndex]];
        }
        tile.templateURLs = [array copy];
    }
    
    // "Completion" done op - detects when all fetch operations have completed
    NSBlockOperation *completionDoneOp = [NSBlockOperation blockOperationWithBlock:^{
        [self updateAnimationTilesToFrameIndex:self.currentFrameIndex];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(YES, nil);
        });
    }];

    // Initiate fetch operations for tiles for each frame
    NSMutableArray *operations = [NSMutableArray array];
    for (NSInteger frameIndex = 0; frameIndex < self.numberOfAnimationFrames; frameIndex++) {
        // Create "Done" operation for this animation frame -- need this to signal when
        // all tiles for this frame have finished downloading so we can fire progress handler
        NSBlockOperation *doneOp = [NSBlockOperation blockOperationWithBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                progressHandler(frameIndex + 1);
            });
        }];
        
        // Fetch and cache the tile data
        for (TCCAnimationTile *tile in self.animationTiles) {
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
            [operations addObject:fetchTileOp];
        }
        
        // Queue the "Done" operation
        [operations addObject:doneOp];
        [completionDoneOp addDependency:doneOp];
    }
    
    [operations addObject:completionDoneOp];
    [self.downloadQueue addOperations:operations waitUntilFinished:NO];
}

- (void)moveToFrameIndex:(NSInteger)frameIndex isContinuouslyMoving:(BOOL)isContinuouslyMoving
{
    if (self.currentAnimationState == TCCAnimationStateAnimating) {
        [self pauseAnimating];
    }
    
    // If the user is scrubbing (i.e. continually moving), update the animation tiles' images to
    // the desired frame index, since the animation tiles are the ones that are rendered. If the
    // user has finished scrubbing, the renderer uses the static tiles to render.
    if (isContinuouslyMoving) {
        // Need to set the animation state to "scrubbing" to indicate that animation hasn't
        // stopped, but that it's also not static. This is critically important to know when
        // the overlay is using animation tiles vs when it's using static tiles.
        self.currentAnimationState = TCCAnimationStateScrubbing;
        [self.staticTilesCache removeAllObjects];
        [self updateAnimationTilesToFrameIndex:frameIndex];
    } else {
        self.currentAnimationState = TCCAnimationStateStopped;
    }
}

- (TCCAnimationTile *)animationTileForMapRect:(MKMapRect)mapRect zoomLevel:(NSUInteger)zoomLevel
{
    MKTileOverlayPath path = [TCCMapKitHelpers tilePathForMapRect:mapRect zoomLevel:zoomLevel];
    TCCAnimationTile *tile = [[TCCAnimationTile alloc] initWithFrame:mapRect x:path.x y:path.y z:path.z];
    return [self.animationTiles member:tile];
}

- (TCCAnimationTile *)staticTileForMapRect:(MKMapRect)mapRect zoomLevel:(NSUInteger)zoomLevel
{
    MKTileOverlayPath path = [TCCMapKitHelpers tilePathForMapRect:mapRect zoomLevel:zoomLevel];
    MKMapRect cappedMapRect = [TCCMapKitHelpers mapRectForTilePath:path];
    
    [self.staticTilesLock lock];
    TCCAnimationTile *tile = [self.staticTilesCache objectForKey:[self keyForTilePath:path]];
    [self.staticTilesLock unlock];

    if (tile && tile.tileImageIndex == self.currentFrameIndex) {
        return tile;
    }
    if (!tile) {
        tile = [[TCCAnimationTile alloc] initWithFrame:cappedMapRect x:path.x y:path.y z:path.z];
    }
    tile.tileImage = nil;
    
    NSMutableArray *array = [NSMutableArray array];
    for (NSUInteger timeIndex = 0; timeIndex < self.numberOfAnimationFrames; timeIndex++) {
        [array addObject:[self URLStringForX:tile.x Y:tile.y Z:tile.z timeIndex:timeIndex]];
    }
    tile.templateURLs = [array copy];
    [self.staticTilesLock lock];
    [self.staticTilesCache setObject:tile forKey:[NSString stringWithFormat:@"%ld-%ld-%ld", tile.x, tile.y, tile.z]];
    [self.staticTilesLock unlock];
    return tile;
}

- (NSArray *)cachedTilesForMapRect:(MKMapRect)rect zoomLevel:(NSUInteger)zoomLevel
{
    NSMutableArray *tiles = [NSMutableArray array];
    for (TCCAnimationTile *tile in self.animationTiles) {
        if (MKMapRectIntersectsRect(rect, tile.mapRectFrame) &&
            tile.z == zoomLevel) {
            [tiles addObject:tile];
        }
    }
    return [tiles copy];
}

- (NSArray *)cachedStaticTilesForMapRect:(MKMapRect)rect zoomLevel:(NSUInteger)zoomLevel
{
    NSMutableArray *tiles = [NSMutableArray array];
    
    [self.staticTilesLock lock];
    
    NSSet *tilesInMapRect = [self mapTilesInMapRect:rect zoomLevel:zoomLevel];
    for (TCCAnimationTile *tile in tilesInMapRect) {
        TCCAnimationTile *cachedTile = [self.staticTilesCache objectForKey:[self keyForTile:tile]];
        if (MKMapRectIntersectsRect(rect, tile.mapRectFrame)) {
            [tiles addObject:cachedTile];
        }
    }
    
    [self.staticTilesLock unlock];
    return [tiles copy];
}

- (BOOL)canAnimateForMapRect:(MKMapRect)rect zoomLevel:(NSInteger)zoomLevel
{
    NSSet *visibleMapTiles = [self mapTilesInMapRect:rect zoomLevel:zoomLevel];
    for (TCCAnimationTile *visibleTile in visibleMapTiles) {
        if (![self.animationTiles containsObject:visibleTile]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark Overrides

- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    [self.staticTilesLock lock];
    __block TCCAnimationTile *tile = [self.staticTilesCache objectForKey:[self keyForTilePath:path]];
    [self.staticTilesLock unlock];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURL *url = [NSURL URLWithString:tile.templateURLs[self.currentFrameIndex]];
    tile.tileImageIndex = self.currentFrameIndex;
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                  cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                              timeoutInterval:0];
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            tile.tileImage = [UIImage imageWithData:data];
        }
        if (result) result(data, error);
    }];
    [task resume];
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

- (void)updateAnimationTilesToFrameIndex:(NSInteger)frameIndex
{
    // RSS: Tried to have this data updating occur on a background thread, but it causes threading issues.
    // I wanted this in the background so that it doesn't block the main thread when it's loading cached
    // data. However, scrubbing quickly causes multiple calls to occur concurrently, which causes the
    // currentFrameIndex to enter a race condition. If we want to do this in the background, I think we'll
    // need to create a serial background queue.
    for (TCCAnimationTile *tile in self.animationTiles) {
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

// Creates a set of @c MATAnimationTile objects for a given map rect and zoom scale
- (NSSet *)mapTilesInMapRect:(MKMapRect)rect zoomLevel:(NSUInteger)zoomLevel
{
    // Ripped from http://stackoverflow.com/a/4445576/766491
    NSInteger overZoom = 1;
    
    if (zoomLevel > self.maximumZ) {
        overZoom = pow(2, (zoomLevel - self.maximumZ));
        zoomLevel = self.maximumZ;
    }
    
    // When we are zoomed in beyond the tile set, use the tiles from the maximum z-depth,
    // but render them larger.
    // **Adjusted from overZoom * self.tileSize to just self.tileSize in order to render at overzoom properly
    NSInteger adjustedTileSize = self.tileSize.width;

    // Need to use the zoom level zoom scale, not the actual zoom scale from the map view!
    NSInteger zoomExponent = 20 - zoomLevel;
    MKZoomScale zoomScale = 1/pow(2, zoomExponent);
    
    NSInteger minX = floor((MKMapRectGetMinX(rect) * zoomScale) / adjustedTileSize);
    NSInteger maxX = ceil((MKMapRectGetMaxX(rect) * zoomScale) / adjustedTileSize);
    NSInteger minY = floor((MKMapRectGetMinY(rect) * zoomScale) / adjustedTileSize);
    NSInteger maxY = ceil((MKMapRectGetMaxY(rect) * zoomScale) / adjustedTileSize);
    
    NSMutableSet *tiles = [NSMutableSet set];
	for (NSInteger x = minX; x <= maxX; x++) {
        for (NSInteger y = minY; y <=maxY; y++) {
			MKMapRect frame = MKMapRectMake((x * adjustedTileSize) / zoomScale, (y * adjustedTileSize) / zoomScale, adjustedTileSize / zoomScale, adjustedTileSize / zoomScale);
            if (MKMapRectIntersectsRect(frame, rect)) {
                TCCAnimationTile *tile = [[TCCAnimationTile alloc] initWithFrame:frame x:x y:y z:zoomLevel];
                [tiles addObject:tile];
            }
        }
    }
    return [tiles copy];
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

- (NSString *)keyForTilePath:(MKTileOverlayPath)path
{
    return [NSString stringWithFormat:@"%ld-%ld-%ld", path.x, path.y, path.z];
}

- (NSString *)keyForTile:(TCCAnimationTile *)tile
{
    return [NSString stringWithFormat:@"%ld-%ld-%ld", tile.x, tile.y, tile.z];
}

@end
