Map Animation Tile Overlay
=======================

Project Overview
----------------

### Features ###
1. Create an animated overlay on an `MKMapView` by using map tiles from either the local file system or from a map tile
   server, where each frame of animation consists of a set of tiles.
2. Animate the overlay consistently and smoothly. There should be no tiling when drawing a frame of the animation, and
   there should be no flicker when animating between frames.
3. Allow users to play, pause, and jump/scrub through the animation timeline.
4. Pause the animation when the user interacts with the map view in such a way that the map animation tile overlay does
   not have enough tile data to accurately draw the overlay on screen (i.e. user zooms in )
5. When the user pans around the map, the overlay falls back to using `MKTileOverlay` and `MKTileOverlayRenderer` behavior,
   which is to load tiles on demand and draw them as they are returned<sup>1</sup>.

### Tasks and Challenges ###
1. Figuring out which tiles to load (x/y/z) based on the map view's current map region.
2. Fetching tile data in a performant way.
3. Storing tile data so that it's quickly and easily accessible for playback, while also being conscious of device
   memory limitations.
4. Drawing the tile data onto the screen so that it doesn't tile.
5. Toggling between animation frames smoothly without any redraw flicker.
6. Behavior when tile server only supports up to a certain maximum zoom level.

### Preconditions ###
1. Animation cannot begin until all of the tile data has been loaded from the tile source.

### Questions ###
1. Better way to handle 2 overlays and being DRY for index, tiles, etc.
2. Do we need path and maprect on tile? Do we need tile?
3. In the delegate do we need startAnimating and didAnimate?
4. A flexible design for supplying the URL template strings for tiles.
5. HTTP-level caching of data? Fallback cache with NSCache?

<sup>1</sup>The design philosophy of this is to use 2 overlays to provide a panning overlay and an animation tile overlay. When panning the standard MKTileOverlay and MKTileOverlayRenderer would be used. When not panning and an animation is requested to be performed the MATAnimationTileOverlay would be used. The reason for this separation is that we can't easily work around the flickering caused by MKTileOverlayRenderer when it loads portions of a tile on the screen.

In the implementation there are 3 components added to the map view.

- Controls: This a view that the application adds to the MapView for Play, Pause, Slider, etc. It's the responsibility of the implementing application to build and provide this interface.
- Panning: An MATTileOverlay and standard MKTileOverlayRenderer are used. The MATTileOverlay contains some specific functionality around panning with an index.
- Animation: An MATAnimationTileOverlay and MATTileOverlayRenderer are used to provide the logic and fetching of tiled set of images associated on the map view. This is modeled after MKTileOverlay, MKTileOverlayRenderer and UIImageView animations.

Panning
=======
The following is an overlay class that defers all it's calls to the MATAnimationTileOverlay and MATAnimationTileRenderer to keep the animation indexes DRY.

    @interface MATTileOverlay : MKTileOverlay
    @property (weak, nonatomic, readonly) MATAnimatedTileOverlay *animatedTileOverlay;
    - (id)initWithAnimationTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay;
    @end

Animation
=========

    @protocol MATAnimatedTileOverlayDelegate
    - (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didChangeAnimationState:(MATAnimatingState)currentAnimationState;
    - (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didAnimateWithFrameIndex:(NSInteger)animationFrameIndex;
     // Does not stop the fetching of other images, could have multiple errors
    - (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didHaveError:(NSError *) error;
    @end

    @interface MATAnimatedTileOverlay : NSObject <MKOverlay>

    @property (weak, nonatomic) id <MATAnimatedTileOverlayDelegate> delegate;
    @property (nonatomic, readonly) NSUInteger numberOfAnimationFrames;
    @property (nonatomic, readonly) NSTimeInterval frameDuration;
    @property (nonatomic) NSUInteger currentFrameIndex; // If set this will nil the animationTiles
    @property (copy, nonatomic) NSArray *animationTiles; // of MATAnimationTile. Set to nil if the map moves
    @property (nonatomic, readonly) BOOL isAnimating;

    - (instancetype)initWithNumberOfAnimationFrames:(NSUInteger)numberOfAnimationFrames frameDuration:(NSTimeInterval)frameDuration;
    - (void)startAnimating; // Loads and after loading starts the animations
    - (void)stopAnimating;
    - (void)fetchTilesForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aScale progressBlock:(void(^)(NSUInteger currentTimeIndex, BOOL *stop))progressBlock completionBlock:(void (^)(BOOL success, NSError *error))completionBlock;
    - (void)updateTilesToFrameIndex:(NSUInteger)animationFrameIndex;
    - (MATAnimationTile *)tileForMapRect:(MKMapRect)aMapRect zoomScale:(MKZoomScale)aZoomScale;

    @end

    @interface MATAnimatedTileOverlayRenderer : MKOverlayRenderer
    @end

    @interface MATAnimationTile

    @property (readonly, nonatomic) MATTileCoordinate coordinate;
    @property (readonly, nonatomic) MKMapRect tileMapRect;
    @property (strong, nonatomic) UIImage *currentTileImage;
    @property (strong, nonatomic) NSArray *tileURLs;

    - (instancetype)initWithMapRect:(MKMapRect)tileMapRect tileCoordinate:(MATTileCoordinate)tileCoordinate;
    
    @end
