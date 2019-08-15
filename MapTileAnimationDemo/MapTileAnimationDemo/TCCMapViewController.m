//
//  TCCViewController.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapViewController.h"
#import "TCCTimeFrameParser.h"
#import "TCCAnimationTileOverlayRenderer.h"
#import "TCCAnimationTileOverlay.h"

#define FUTURE_RADAR_FRAMES_URI @"http://climate.com/assets/future-radar/LKG.txt?grower_apps=true"

@interface TCCMapViewController () <MKMapViewDelegate, TCCAnimationTileOverlayDelegate, TCCTimeFrameParserDelegateProtocol, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *frameIndexLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIButton *startStopButton;
@property (weak, nonatomic) IBOutlet UISlider *timeSlider;
@property (strong, nonatomic) TCCTimeFrameParser *timeFrameParser;
@property (strong, nonatomic) TCCAnimationTileOverlay *animatedTileOverlay;
@property (strong, nonatomic) TCCAnimationTileOverlayRenderer *animatedTileRenderer;
@property (weak, nonatomic) UIAlertController * alertViewController;

@end

@implementation TCCMapViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the starting location.
    CLLocationCoordinate2D startingLocation = {30.33, -81.52};
    MKCoordinateSpan span = {7.0, 7.0};
    MKCoordinateRegion region = [self.mapView regionThatFits: MKCoordinateRegionMake(startingLocation, span)];
    [self.mapView setRegion:region animated:NO];
    
    // The time frame parser performs a network fetch to create a list of template URLs, one for each
    // frame of animation.
    self.timeFrameParser = [[TCCTimeFrameParser alloc] initWithURLString:FUTURE_RADAR_FRAMES_URI delegate:self];
}

#pragma mark - IBActions

- (IBAction)onSliderValueChange:(id)sender
{
    // Only advance the animated overlay to the next frame if the slider no longer matches the
    // current frame index
	NSInteger sliderVal = floor(self.timeSlider.value);
    if (sliderVal == self.animatedTileOverlay.currentFrameIndex) return;
    
    [self.animatedTileOverlay moveToFrameIndex:sliderVal isContinuouslyMoving:YES];
}

- (IBAction)finishedSliding:(id)sender
{
    NSInteger sliderVal = floor(self.timeSlider.value);
    // It's very important to let the overlay know when the user has finished actively scrubbing.
    [self.animatedTileOverlay moveToFrameIndex:sliderVal isContinuouslyMoving:NO];
}

- (IBAction)onHandleStartStopAction:(id)sender
{
	if (self.animatedTileOverlay.currentAnimationState == TCCAnimationStateStopped) {
        // Fetch tiles and start animating when loading has finished.
		[self.animatedTileOverlay fetchTilesForMapRect:self.mapView.visibleMapRect zoomLevel:self.animatedTileRenderer.renderedTileZoomLevel progressHandler:^(NSUInteger loadedFrameIndex) {
            // Show the loading progress
			[self.downloadProgressView setProgress:((float)loadedFrameIndex + 1) / self.animatedTileOverlay.numberOfAnimationFrames animated:YES];
		} completionHandler:^(BOOL success, NSError *error) {
			if (success) {
                self.timeSlider.enabled = YES;
				[self.animatedTileOverlay startAnimating];
                return;
			}
            dispatch_async(dispatch_get_main_queue(), ^{
                [self displayError:error];
            });
		}];
	} else if (self.animatedTileOverlay.currentAnimationState == TCCAnimationStateLoading) {
        [self.animatedTileOverlay cancelLoading];
	} else if (self.animatedTileOverlay.currentAnimationState == TCCAnimationStateAnimating) {
		[self.animatedTileOverlay pauseAnimating];
	}
}

#pragma mark - Private methods

- (void)displayError:(NSError *)error
{
    UIAlertController * alertView = [UIAlertController alertControllerWithTitle:@"Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alertView addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    self.alertViewController = alertView;
    [self presentViewController:alertView animated:YES completion:nil];
}

#pragma mark - Protocol conformance

#pragma mark TCCTimeFrameParserDelegate

- (void)didLoadTimeStampData;
{
    // Only use a subset of the available template URLs
	NSArray *templateURLs = self.timeFrameParser.templateFrameTimeURLs;
    NSMutableArray *pluckedArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < templateURLs.count; i+=3) {
        [pluckedArray addObject:templateURLs[i]];
    }
    
    // Setting up the overlay's maximumZ caps the zoom level of the tiles that get fetched.
    // If the user zooms closer in than this level, then tiles from the maximumZ level are
    // fetched and scaled up for rendering.
	self.animatedTileOverlay = [[TCCAnimationTileOverlay alloc] initWithTemplateURLs:pluckedArray frameDuration:0.50 minimumZ:3 maximumZ:9 tileSize:CGSizeMake(256, 256)];
	self.animatedTileOverlay.delegate = self;
	[self.mapView addOverlay:self.animatedTileOverlay level:MKOverlayLevelAboveRoads];
    
	self.timeSlider.maximumValue = pluckedArray.count - 1;
}

#pragma mark TCCAnimationTileOverlayDelegate

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay
 didChangeFromAnimationState:(TCCAnimationState)previousAnimationState
            toAnimationState:(TCCAnimationState)currentAnimationState
{
    //set titles of button to appropriate string based on currentAnimationState
    if (currentAnimationState == TCCAnimationStateLoading) {
        [self.startStopButton setTitle:@"◼︎" forState:UIControlStateNormal];
        self.downloadProgressView.hidden = NO;
    } else if(currentAnimationState == TCCAnimationStateStopped) {
        [self.startStopButton setTitle:@"▶︎" forState:UIControlStateNormal];
        self.downloadProgressView.hidden = YES;
        self.downloadProgressView.progress = 0.0;
    } else if (currentAnimationState == TCCAnimationStateAnimating) {
        [self.startStopButton setTitle:@"❚❚" forState:UIControlStateNormal];
        self.downloadProgressView.hidden = YES;
    }
}

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex
{
    // When the animation overlay animates to a new frame, it's the responsibility of the delegate
    // to call setNeedsDisplay
    [self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect];
    
    self.frameIndexLabel.text = [NSString stringWithFormat:@"%ld", (long)animationFrameIndex];
 	if (animationTileOverlay.currentAnimationState == TCCAnimationStateAnimating) {
		self.timeSlider.value = animationFrameIndex;
	}
}

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didHaveError:(NSError *) error
{
    NSLog(@"%s ERROR %ld %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
    // Only want to display one error alert view at a time
    if (!self.alertViewController) {
        [self displayError:error];
    }
}

#pragma mark MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
    // When the user moves/zooms/rotates the map, it should pause loading or animating, since
    // otherwise we might not have fetched the tile data necessary to display the overlay
    // for the new region.
    if (self.animatedTileOverlay.currentAnimationState == TCCAnimationStateAnimating ||
        self.animatedTileOverlay.currentAnimationState == TCCAnimationStateLoading) {
        [self.animatedTileOverlay pauseAnimating];
    }
    // Disable the slider when the region changes. Only want to enable it until the
    // tiles have finished fetching.
    self.timeSlider.enabled = NO;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
	if ([overlay isKindOfClass:[TCCAnimationTileOverlay class]]) {
        self.animatedTileRenderer = [[TCCAnimationTileOverlayRenderer alloc] initWithOverlay:overlay];
        self.animatedTileRenderer.drawDebugInfo = YES;
        self.animatedTileRenderer.alpha = 1;
        return self.animatedTileRenderer;
	}
	return nil;
}

@end
