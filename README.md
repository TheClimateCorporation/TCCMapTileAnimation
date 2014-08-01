TCCMapTileAnimation
=======================

An iOS library for creating an animated map overlay from tiled images.

### Features ###
* Create an animated overlay on an `MKMapView` by using map tiles from either the local file system or from a map tile server, where each frame of animation consists of a set of tiles.
* Allow users to play, pause, and jump/scrub through the animation timeline.
* Animates the overlay consistently and smoothly. Depending on the graphical power of the device, there should be little to no tiling or flickering when drawing a frame of the animation.
* When the user pans around the map, the overlay falls back to retrieving and rendering tiles on demand.

TCCMapTileAnimation does not provide any UI playback controls, but please take a look at the demo project to see how to wire up UI controls to the overlay.

### Installation ###
If you use Cocoapods, add `pod 'TCCMapTileAnimation'` to your Podfile, then run `pod install`.

You can also manually add the `.m` and `.h` files in the `TCCMapTileAnimation` directory to your project, or create a static library from those files and add the library to your project.

### Getting Started ###

Creating the overlay

	NSArray *templateURLs = @[@"http://url.to/first_frame/{z}/{x}/{y}", @"http://url.to/second_frame/{z}/{x}/{y}"];
	self.overlay = [[TCCAnimationTileOverlay alloc] initWithMapView:self.mapView templateURLs:templateURLs frameDuration:0.50 minimumZ:3 maximumZ:9 tileSize:CGSizeMake(256, 256)];
	self.overlay.delegate = self;
	[self.mapView addOverlay:self.overlay];


Creating the overlay renderer

	- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
	{
		if ([overlay isKindOfClass:[TCCAnimationTileOverlay class]]) {
	        self.animatedTileRenderer = [[TCCAnimationTileOverlayRenderer alloc] initWithOverlay:overlay];
	        self.animatedTileRenderer.drawDebugInfo = YES;
	        self.animatedTileRenderer.alpha = .75;
	        return self.animatedTileRenderer;
		}
		return nil;
	}

Fetching tiles and starting animation

	[self.overlay fetchTilesForMapRect:self.mapView.visibleMapRect zoomLevel:self.animatedTileRenderer.renderedTileZoomLevel progressHandler:^(NSUInteger currentTimeIndex) {
        // Show loading progress
		[self.downloadProgressView setProgress:(CGFloat)currentTimeIndex / self.animatedTileOverlay.numberOfAnimationFrames animated:YES];
	} completionHandler:^(BOOL success, NSError *error) {
		if (success) {
			[self.animatedTileOverlay startAnimating];
            return;
		}
	}];

Rendering the animation

	- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex
	{
		[self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect];
		...    
	}

Stop animation

	[self.overlay pauseAnimating];

Reacting to user input on the map

	- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
	{
	    // When the user moves/zooms/rotates the map, it should pause loading or animating, since
	    // otherwise we might not have fetched the tile data necessary to display the overlay
	    // for the new region.
	    if (self.animatedTileOverlay.currentAnimationState == TCCAnimationStateAnimating ||
	        self.animatedTileOverlay.currentAnimationState == TCCAnimationStateLoading) {
	        [self.animatedTileOverlay pauseAnimating];
	    }
	    [self.animatedTileRenderer setNeedsDisplay];

	    // Disable the slider when the region changes. Only want to enable it until the
	    // tiles have finished fetching.
	    self.timeSlider.enabled = NO;
	}

Check out the demo project `MapTileAnimationDemo` to get a more in-depth look at incorporating TCCMapTileAnimation into a project.

### Technical Details ###
1. It relies on cached HTTP network responses (from NSURLCache) to provide good performance during animation.