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
#import "TCCTileFetchOperation.h"

#define Z_INDEX "{z}"
#define X_INDEX "{x}"
#define Y_INDEX "{y}"

NSString *const TCCAnimationTileOverlayErrorDomain = @"TCCAnimationTileOverlayError";

@interface TCCAnimationTileOverlay ()

@property (strong, nonatomic) NSOperationQueue *downloadQueue;
@property (nonatomic) NSTimeInterval frameDuration;
@property (strong, nonatomic) NSTimer *timer;
@property (readwrite, nonatomic) TCCAnimationState currentAnimationState;
@property (strong, nonatomic) NSSet *animationTiles;
@property (strong, nonatomic) NSCache *staticTilesCache;
@property (strong, nonatomic) NSURLSession *session;

@end

@implementation TCCAnimationTileOverlay

#pragma mark - Lifecycle

- (instancetype)initWithTemplateURLs:(NSArray *)templateURLs
                       frameDuration:(NSTimeInterval)frameDuration
                            minimumZ:(NSInteger)minimumZ
                            maximumZ:(NSInteger)maximumZ
                            tileSize:(CGSize)tileSize
{
    if (self = [super init]) {
        //Initialize network settings
        NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                             diskCapacity:32 * 1024 * 1024
                                                                 diskPath:nil];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.URLCache = URLCache;
        _session = [NSURLSession sessionWithConfiguration:configuration];
        
        _templateURLs = templateURLs;
        _numberOfAnimationFrames = [templateURLs count];
        _frameDuration = frameDuration;
        _currentFrameIndex = 0;
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 4;
        if ([_downloadQueue respondsToSelector:@selector(setQualityOfService:)]) {
            _downloadQueue.qualityOfService = NSOperationQualityOfServiceUserInitiated;
        }
        
        _currentAnimationState = TCCAnimationStateStopped;
        
        self.minimumZ = minimumZ;
        self.maximumZ = maximumZ;
        self.tileSize = tileSize;
        
        _staticTilesCache = [[NSCache alloc] init];
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

// Allows users to mutate the template URLs of the animation overlay.
- (void)setTemplateURLs:(NSArray *)templateURLs
{
    [self pauseAnimating];
    _templateURLs = templateURLs;
    _numberOfAnimationFrames = [_templateURLs count];
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
    // Have to set the current animation state first before firing the timer because the timer depends on
    // the animation state to be animating, otherwise the playback skips one frame of animation.
	self.currentAnimationState = TCCAnimationStateAnimating;
	self.timer = [NSTimer scheduledTimerWithTimeInterval:self.frameDuration target:self selector:@selector(updateAnimationTiles:) userInfo:nil repeats:YES];
	[self.timer fire];
}

- (void)pauseAnimating
{
    self.currentAnimationState = TCCAnimationStateStopped;
    [self.timer invalidate];
    [self.downloadQueue cancelAllOperations];
    self.timer = nil;
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
    zoomLevel = MAX(MIN(zoomLevel, self.maximumZ), self.minimumZ);
    
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
    NSOperation *previousDoneOp;
    for (NSInteger frameIndex = 0; frameIndex < self.numberOfAnimationFrames; frameIndex++) {
        // Create "Done" operation for this animation frame -- need this to signal when
        // all tiles for this frame have finished downloading so we can fire progress handler
        NSBlockOperation *doneOp = [NSBlockOperation blockOperationWithBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                progressHandler(frameIndex);
            });
        }];
        
        // Fetch and cache the tile data
        for (TCCAnimationTile *tile in self.animationTiles) {
            // Create NSOperation to fetch tile
            TCCTileFetchOperation *fetchOp = [[TCCTileFetchOperation alloc] initWithTile:tile frameIndex:frameIndex];
            
            // Add a dependency from the "Done" operation onto this operation
            [doneOp addDependency:fetchOp];
            // Queue it onto the download queue
            [operations addObject:fetchOp];
        }
        
        // Queue the "Done" operation
        [operations addObject:doneOp];
        [completionDoneOp addDependency:doneOp];
        
        // The "Done" operations for each frame should also have a dependency on the previous done op.
        // This prevents the case where the loading progress can go from 2 to 4 back to 3 then to 5, etc.
        if (previousDoneOp) {
            [doneOp addDependency:previousDoneOp];
        }
        previousDoneOp = doneOp;
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
        // Need to set the animation state to "scrubbing". This is because the animation renderer
        // uses two different method of retrieving tiles based on whether the current animation state
        // of the overlay is stopped (uses static tiles with async loadTileAtPath) or scrubbing/animating
        // (uses cached animation tiles synchronously). If we don't set this to scrubbing and let it
        // be stopped, the rendering has a noticeable flicker due to the async nature of loading tiles.
        self.currentAnimationState = TCCAnimationStateScrubbing;
        [self updateAnimationTilesToFrameIndex:frameIndex];
        // We're actively scrubbing, so there's a good chance that the static tiles in the cache
        // will not be used.
        [self.staticTilesCache removeAllObjects];
        
        [self.delegate animationTileOverlay:self didAnimateWithAnimationFrameIndex:self.currentFrameIndex];
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
    
    TCCAnimationTile *tile = [self.staticTilesCache objectForKey:[self keyForTilePath:path]];

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
    
    [self.staticTilesCache setObject:tile forKey:[NSString stringWithFormat:@"%ld-%ld-%ld", (long)tile.x, (long)tile.y, (long)tile.z]];
    
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
    
    NSSet *tilesInMapRect = [self mapTilesInMapRect:rect zoomLevel:zoomLevel];
    for (TCCAnimationTile *tile in tilesInMapRect) {
        TCCAnimationTile *cachedTile = [self.staticTilesCache objectForKey:[self keyForTile:tile]];
        // The cache should always contain a tile, but in the event of an unexpected cache miss (i.e.
        // the app cleared the cache right before we needed it, which it shouldn't do), we opt to not
        // return the tile since inserting nil would cause a crash
        if (!cachedTile) continue;
        if (MKMapRectIntersectsRect(rect, tile.mapRectFrame)) {
            [tiles addObject:cachedTile];
        }
    }
    
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
    // Since the tile is in a cache from which it could be released, we need to capture the tile for use in
    // the block below.  Setting the variable to __block will not work since "Object variables
    // of __block storage type are assumed to hold normal pointers with no provision for retain
    // and release messages." (see http://releases.llvm.org/5.0.0/tools/clang/docs/BlockLanguageSpec.html)
    // Therefore, we create a weak reference here and make it strong in the block.
    __weak __typeof__(TCCAnimationTile *) weakTile = [self.staticTilesCache objectForKey:[self keyForTilePath:path]];
    
    NSURL *url = [NSURL URLWithString:weakTile.templateURLs[self.currentFrameIndex]];
    weakTile.tileImageIndex = self.currentFrameIndex;
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url
                                                  cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                              timeoutInterval:0];
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __typeof__(TCCAnimationTile *) strongTile = weakTile;
        if ((strongTile != nil) && data && !error) {
            strongTile.tileImage = [UIImage imageWithData:data];
        }
        if (result) result(data, error);
    }];
    [task resume];
}

#pragma  mark - Private

- (void)updateAnimationTilesToFrameIndex:(NSInteger)frameIndex
{
    // The tiles in self.animationTiles need tileImage to be updated to the frameIndex.
    // TCCTileFetchOperation does this for us. We want to block until all tiles have
    // been updated. In theory, the NSURLCache used by NSURLSession should already have
    // all the necessary tile image data from fetchTilesForMapRect:
    NSMutableArray *operations = [NSMutableArray array];
    for (TCCAnimationTile *tile in self.animationTiles) {
        if (tile.failedToFetch) {
            continue;
        }
        
        TCCTileFetchOperation *fetchOp = [[TCCTileFetchOperation alloc] initWithTile:tile frameIndex:frameIndex];
        __weak TCCTileFetchOperation *weakOp = fetchOp;
        fetchOp.completionBlock = ^{
            tile.tileImage = weakOp.tileImage;
            tile.failedToFetch = tile.tileImage == nil;
        };
        [operations addObject:fetchOp];
    }
    [self.downloadQueue addOperations:operations waitUntilFinished:YES];

    self.currentFrameIndex = frameIndex;
    if (self.currentAnimationState == TCCAnimationStateAnimating) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate animationTileOverlay:self didAnimateWithAnimationFrameIndex:self.currentFrameIndex];
        });
    }
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
    return [NSString stringWithFormat:@"%ld-%ld-%ld", (long)path.x, (long)path.y, (long)path.z];
}

- (NSString *)keyForTile:(TCCAnimationTile *)tile
{
    return [NSString stringWithFormat:@"%ld-%ld-%ld", (long)tile.x, (long)tile.y, (long)tile.z];
}

@end
