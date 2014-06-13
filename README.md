Map Animation Tile View
=======================
QUESTIONS /START
1. Better way to handle 2 overlays and being DRY for index, tiles, etc.
2. Do we need path and maprect on tile? Do we need tile?
3. In the delegate do we need startAnimating and didAnimate?
4. Questions in comments below

QUESTIONS /END

The design philosophy of this is to use 2 overlays to provide a panning overlay and an animation tile overlay. When panning the standard MKTileOverlay and MKTileOverlayRenderer would be used. When not panning and an animation is requested to be performed the MATAnimationTileOverlay would be used. The reason for this separation is that we can't easily work around the flickering caused by MKTileOverlayRenderer when it loads portions of a tile on the screen.

In the implementation there are 3 components added to the map view.

- Controls: This a view that the application adds to the MapView for Play, Pause, Slider, etc. It's the responsibility of the implementing application to build and provide this interface.
- Panning: An MATTileOverlay and standard MKTileOverlayRenderer are used. The MATTileOverlay contains some specific functionality around panning with an index.
- Animation: An MATAnimationTileOverlay and MATTileOverlayRenderer are used to provide the logic and fetching of tiled set of images associated on the map view. This is modeled after MKTileOverlay, MKTileOverlayRenderer and UIImageView animations.

Panning
=======
The following is an overlay class that defers all it's calls to the MATAnimationTileOverlay and MATAnimationTileRenderer to keep the animation indexes DRY.

    @interface MATTileOverlay : MKTileOverlay
    @property (weak, nonatomic, readonly) MATAnimationTileOverlay* tileAnimationOverlay;
    - (id) initWithMATAnimationTileOverlay:(MATAnimationTileOverlay*) tileAnimationOverlay;
    @end

Animation
=========
The following MATAnimationTileOverlay

    @protocol MATAnimationTileOverlayDelegate
    - (void) matAnimationTileOverlay:(MATAnimationTileOverlay*) animationTileOverlay didAnimateWithCurrentAnimationImageIndex:(NSInteger) currentAnimationImageIndex;
    - (void) matAnimationTileOverlay:(MATAnimationTileOverlay*) animationTileOverlay didStartAnimatingWithCurrentAnimationImageIndex:(NSInteger) currentAnimationImageIndex;
    - (void) matAnimationTileOverlay:(MATAnimationTileOverlay*) animationTileOverlay willStartAnimatingWithCurrentAnimationImageIndex:(NSInteger) currentAnimationImageIndex;
    - (void) matAnimationTileOverlay:(MATAnimationTileOverlay*) animationTileOverlay didHaveError:(NSError*) error; // Does not stop the fetching of other images, could have multiple errors
    @end

    @interface MATAnimationTileOverlay : NSObject <MKOverlay>
    @property (weak, nonatomic, readonly) id <MATAnimationTileOverlayDelegate> delegate;
    @property (assign, nonatomic, readonly) NSInteger numberOfAnimationImages;
    @property (assign, nonatomic, readonly) NSTimeInterval animationDuration;
    @property (assign, nonatomic) NSInteger currentAnimationImageIndex; // If set this will nil the animationTiles
    @property (strong, nonatomic) NSArray* animationTiles; // Set to nil if the map moves
    @property (assign, nonatomic, readonly) BOOL isAnimating;
    - (id) initWithNumberOfAnimationImages:(NSInteger) numberOfAnimationImages animationDuration:(NSTimeInterval) animationDuration;
    - (void) loadAnimationImages; // For preload purposes, but for Climate we wouldn't use.
    - (void) startAnimating; // Loads and after loading starts the animations
    - (void) stopAnimating;
    @end

    @interface MATAnimationTileOverlayRenderer :
    @end

    @interface MATAnimationTile // Is this class necessary?
    @property (assign, nonatomic, readonly) MKTileOverlayPath path;
    @property (assign, nonatomic, readonly) MKMapRect mapRect; // Do we need both mapRect and path?
    @property (strong, nonatomic, readonly) NSDictionary* animationImages; // Key is NSNumber of animationIndex
    - (id) initWithPath:(MKTileOverlayPath) path mapRect:(MKMapRect) mapRect animationImages:(NSDictionary*) animationImages;
    @end
