TCCMapTileAnimation
=======================

An iOS library for creating an animated map overlay from tiled images.

### Features ###
* Create an animated overlay on an `MKMapView` by using map tiles from either the local file system or from a map tile server, where each frame of animation consists of a set of tiles.
* Allow users to play, pause, and jump/scrub through the animation timeline.
* Animates the overlay consistently and smoothly. Depending on the graphical power of the device, there should be little to no tiling or flickering when drawing a frame of the animation.
* When the user pans around the map, the overlay falls back to retrieving and rendering tiles on demand.

### Installation ###
If you use Cocoapods, add `pod 'TCCMapTileAnimation'` to your Podfile, then run `pod install`.

You can also manually add the `.m` and `.h` files in the `TCCMapTileAnimation` directory to your project, or create a static library from those files and add the library to your project.

### Getting Started ###


Check out the demo project `MapTileAnimationDemo` to get a more in-depth look at incorporating TCCMapTileAnimation into a project.

### Technical Details ###
1. It relies on a shared NSURLCache for caching purposes for quicker reponses to HTTP calls for tiles to animate.
2. The design philosophy of using 2 overlays to provide a panning overlay and an animation tile overlay. When panning
   the standard MKTileOverlay and MKTileOverlayRenderer would be used. When not panning and an animation is requested 
   to be performed the MATAnimationTileOverlay would be used. The reason for this separation is that we can't easily
   work around the tiling/flickering caused by MKTileOverlayRenderer when it loads portions of a tile on the screen.


### Tasks and Challenges ###
1. Figuring out which tiles to load (x/y/z) based on the map view's current map region.
2. Fetching tile data in a performant way.
3. Storing tile data so that it's quickly and easily accessible for playback, while also being conscious of device
   memory limitations.
4. Drawing the tile data onto the screen so that it doesn't tile.
5. Toggling between animation frames smoothly without any redraw flicker.
6. Behavior when tile server only supports up to a certain maximum zoom level.

### TODO ###
1. Better way to handle 2 overlays and being DRY for index, tiles, etc.
2. Do we need path and maprect on tile? Do we need tile?
3. In the delegate do we need startAnimating and didAnimate?
4. A flexible design for supplying the URL template strings for tiles.
5. HTTP-level caching of data? Fallback cache with NSCache?

In the implementation there are 3 components added to the map view.

- Controls: This a view that the application adds to the MapView for Play, Pause, Slider, etc. It's the responsibility of the implementing application to build and provide this interface.
- Panning: An MATTileOverlay and standard MKTileOverlayRenderer are used. The MATTileOverlay contains some specific functionality around panning with an index.
- Animation: An MATAnimationTileOverlay and MATTileOverlayRenderer are used to provide the logic and fetching of tiled set of images associated on the map view. This is modeled after MKTileOverlay, MKTileOverlayRenderer and UIImageView animations.
