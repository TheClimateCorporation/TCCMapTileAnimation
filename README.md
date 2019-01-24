TCCMapTileAnimation
=======================

An iOS library for creating an animated map overlay from tiled images.

### Features ###
* Create an animated overlay on an `MKMapView` by using map tiles from either the local file system or from a map tile server, where each frame of animation consists of a set of tiles.
* Allow users to play, pause, and jump/scrub through the animation timeline.
* Animates the overlay consistently and smoothly. Depending on the graphical power of the device, there should be little to no tiling or flickering when drawing a frame of the animation.
* When the user pans around the map, the overlay falls back to retrieving and rendering tiles on demand.

TCCMapTileAnimation does not provide any UI playback controls, but please take a look at the demo project to see how to wire up UI controls to the overlay.

Getting Started
---------------

### Installation ###
If you use CocoaPods, add `pod 'TCCMapTileAnimation'` to your Podfile, then run `pod install`.

You can also manually add the `.m` and `.h` files in the `TCCMapTileAnimation` directory to your project, or create a static library from those files and add the library to your project.

### Prerequisites ###

TCCMapTileAnimation uses NSURLCache to quickly look up and render overlay tiles that have already been fetched from the network. This must be set up explicitly by your app, ideally in `application:didFinishLaunchingWithOptions`.

	- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	    NSURLCache *cache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
	                                                      diskCapacity:20 * 1024 * 1024
	                                                          diskPath:nil];
	    [NSURLCache setSharedURLCache:cache];
	    
	    ...
	}

### Creating the overlay ###

	NSArray *templateURLs = @[@"http://url.to/first_frame/{z}/{x}/{y}", @"http://url.to/second_frame/{z}/{x}/{y}"];
	self.overlay = [[TCCAnimationTileOverlay alloc] initWithMapView:self.mapView templateURLs:templateURLs frameDuration:0.50 minimumZ:3 maximumZ:9 tileSize:CGSizeMake(256, 256)];
	self.overlay.delegate = self;
	[self.mapView addOverlay:self.overlay];
	
	
### Setting URL Session Configuration when creating the overlay ###

	NSURLSessionConfiguration * configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSArray *templateURLs = @[@"http://url.to/first_frame/{z}/{x}/{y}", @"http://url.to/second_frame/{z}/{x}/{y}"];
	self.overlay = [[TCCAnimationTileOverlay alloc] initWithTemplateURLs: templateURLs, configuration: configuration, frameDuration:0.50 minimumZ:3 maximumZ:9 tileSize:CGSizeMake(256, 256)];
	self.overlay.delegate = self;
	[self.mapView addOverlay:self.overlay];

### Creating the overlay renderer ###

	- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
	{
		if ([overlay isKindOfClass:[TCCAnimationTileOverlay class]]) {
	        self.animatedTileRenderer = [[TCCAnimationTileOverlayRenderer alloc] initWithOverlay:overlay];
	        // Optional - draws tile grid debug info
	        // self.animatedTileRenderer.drawDebugInfo = YES;
	        self.animatedTileRenderer.alpha = .75;
	        return self.animatedTileRenderer;
		}
		return nil;
	}

### Fetching tiles and starting animation ###

	[self.overlay fetchTilesForMapRect:self.mapView.visibleMapRect zoomLevel:self.animatedTileRenderer.renderedTileZoomLevel progressHandler:^(NSUInteger currentTimeIndex) {
        // Show loading progress
		[self.downloadProgressView setProgress:(CGFloat)currentTimeIndex / self.animatedTileOverlay.numberOfAnimationFrames animated:YES];
	} completionHandler:^(BOOL success, NSError *error) {
		if (success) {
			[self.animatedTileOverlay startAnimating];
            return;
		}
	}];

### Rendering the animation ###

	// When the overlay has started animating, it calls this delegate method when each frame of animation ticks.
	// It is its responsibility to tell the overlay renderer to redraw for each frame.
	- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex
	{
		[self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect];
		...    
	}

### Stopping animation ###

	[self.overlay pauseAnimating];

### Scrubbing between frames of animation ###

	// This action is connected to the "Value Changed" event for the playback slider
	- (IBAction)onSliderValueChange:(id)sender
	{
	    // Only advance the animated overlay to the next frame if the slider no longer matches the current frame index
		NSInteger sliderVal = floor(self.timeSlider.value);
	    if (sliderVal == self.animatedTileOverlay.currentFrameIndex) return;
	    [self.animatedTileOverlay moveToFrameIndex:frameIndex isContinuouslyMoving:YES];
	}

	// This action is connected to "Touch Up Inside" and "Touch Up Outside" for the playback slider
	- (IBAction)finishedSliding:(id)sender
	{
	    NSInteger sliderVal = floor(self.timeSlider.value);
	    [self.animatedTileOverlay moveToFrameIndex:frameIndex isContinuouslyMoving:NO];
	}

### Reacting to user input on the map ###

	- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
	{
	    // When the user moves/zooms/rotates the map, it should pause loading or animating, since
	    // otherwise we might not have fetched the tile data necessary to display the overlay
	    // for the new region.
	    if (self.animatedTileOverlay.currentAnimationState == TCCAnimationStateAnimating ||
	        self.animatedTileOverlay.currentAnimationState == TCCAnimationStateLoading) {
	        [self.animatedTileOverlay pauseAnimating];
	    }
	}

Check out the demo project `MapTileAnimationDemo` to get a more in-depth look at incorporating TCCMapTileAnimation into a project.

### Technical Details ###
1. It relies on cached HTTP network responses (from NSURLCache) to provide good performance during animation.
