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
#import "MKMapView+Extras.h"

#define FUTURE_RADAR_FRAMES_URI @"http://climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"

@interface TCCMapViewController () <MKMapViewDelegate, TCCAnimationTileOverlayDelegate, TCCTimeFrameParserDelegateProtocol, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *timeIndexLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIButton *startStopButton;
@property (weak, nonatomic) IBOutlet UISlider *timeSlider;
@property (strong, nonatomic) TCCTimeFrameParser *timeFrameParser;
@property (nonatomic) BOOL initialLoad;
@property (weak, nonatomic) TCCAnimationTileOverlay *animatedTileOverlay;
@property (strong, nonatomic) TCCAnimationTileOverlayRenderer *animatedTileRenderer;
@property (weak, nonatomic) UIAlertView *alertView;

@property (nonatomic) BOOL shouldStop;

@end

@implementation TCCMapViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

	self.startStopButton.tag = TCCAnimationStateStopped;
    
    // Set the starting location.
    CLLocationCoordinate2D startingLocation = {30.33, -81.52};
    MKCoordinateSpan span = {7.0, 7.0};
    MKCoordinateRegion region = [self.mapView regionThatFits: MKCoordinateRegionMake(startingLocation, span)];
    [self.mapView setRegion: region animated: NO];
    
    self.timeFrameParser = [[TCCTimeFrameParser alloc] initWithURLString:FUTURE_RADAR_FRAMES_URI delegate:self];
}

- (IBAction)onHandleTimeIndexChange:(id)sender
{
    // Only advance the animated overlay to the next frame if the slider no longer matches the
    // current frame index
	NSInteger sliderVal = floor(self.timeSlider.value);
    if (sliderVal == self.animatedTileOverlay.currentFrameIndex) return;
    
    [self moveToFrameIndex:sliderVal isContinuallyMoving:YES];
}

- (IBAction)finishedSliding:(id)sender
{
    NSInteger sliderVal = floor(self.timeSlider.value);
    // It's very important to let the overlay know when the user has finished actively scrubbing.
    [self moveToFrameIndex:sliderVal isContinuallyMoving:NO];
}

- (void)moveToFrameIndex:(NSInteger)frameIndex isContinuallyMoving:(BOOL)isContinuallyMoving
{
    [self.animatedTileOverlay moveToFrameIndex:frameIndex isContinuouslyMoving:isContinuallyMoving];
    self.timeIndexLabel.text = [NSString stringWithFormat:@"%ld", (long)self.animatedTileOverlay.currentFrameIndex];
    [self.animatedTileRenderer setNeedsDisplay];
}

- (IBAction)onHandleStartStopAction:(id)sender
{
	if (self.startStopButton.tag == TCCAnimationStateStopped) {
		[self.animatedTileOverlay fetchTilesForMapRect:self.mapView.visibleMapRect zoomLevel:self.animatedTileRenderer.renderedTileZoomLevel progressHandler:^(NSUInteger currentTimeIndex) {
			[self.downloadProgressView setProgress:(CGFloat)currentTimeIndex / self.animatedTileOverlay.numberOfAnimationFrames animated:YES];
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
	} else if (self.startStopButton.tag == TCCAnimationStateLoading) {
        [self.animatedTileOverlay cancelLoading];
	} else if (self.startStopButton.tag == TCCAnimationStateAnimating) {
		[self.animatedTileOverlay pauseAnimating];
	}
}

#pragma mark - Private methods

- (void)displayError:(NSError *)error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    self.alertView = alertView;
    [alertView show];
}

#pragma mark - Protocol conformance

#pragma mark TCCTimeFrameParserDelegate

- (void)didLoadTimeStampData;
{
	NSArray *templateURLs = self.timeFrameParser.templateFrameTimeURLs;
    NSMutableArray *pluckedArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < templateURLs.count; i+=3) {
        [pluckedArray addObject:templateURLs[i]];
    }
    
	TCCAnimationTileOverlay *overlay = [[TCCAnimationTileOverlay alloc] initWithMapView:self.mapView templateURLs:pluckedArray frameDuration:0.50 minimumZ:3 maximumZ:9 tileSize:CGSizeMake(256, 256)];
	overlay.delegate = self;

	[self.mapView addOverlay:overlay level:MKOverlayLevelAboveRoads];
	self.timeSlider.maximumValue = pluckedArray.count - 1;
}

#pragma mark MATAnimatedTileOverlayDelegate

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay
 didChangeFromAnimationState:(TCCAnimationState)previousAnimationState
            toAnimationState:(TCCAnimationState)currentAnimationState
{
    self.startStopButton.tag = currentAnimationState;

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
    self.timeIndexLabel.text = [NSString stringWithFormat:@"%ld", (long)animationFrameIndex];
 	if (animationTileOverlay.currentAnimationState == TCCAnimationStateAnimating) {
		self.timeSlider.value = animationFrameIndex;
	}
    [self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect];
}

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didHaveError:(NSError *) error
{
    NSLog(@"%s ERROR %ld %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
    // Only want to display one error alert view at a time
    if (!self.alertView) {
        [self displayError:error];
    }
}

#pragma mark MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
    // We want moving/zooming/rotating the map to pause when loading or animating, since
    // otherwise we might not have fetched the tile data necessary to display the overlay
    // for the new region
    if (self.animatedTileOverlay.currentAnimationState == TCCAnimationStateAnimating ||
        self.animatedTileOverlay.currentAnimationState == TCCAnimationStateLoading) {
        [self.animatedTileOverlay pauseAnimating];
    }
    // Disable the slider when the region changes. Only want to enable it until the
    // tiles have finished fetching.
    self.timeSlider.enabled = NO;
    [self.animatedTileRenderer setNeedsDisplay];
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
	if ([overlay isKindOfClass: [TCCAnimationTileOverlay class]]) {
		self.animatedTileOverlay = (TCCAnimationTileOverlay *)overlay;
        self.animatedTileRenderer = [[TCCAnimationTileOverlayRenderer alloc] initWithOverlay:overlay];
        self.animatedTileRenderer.drawDebugInfo = YES;
        self.animatedTileRenderer.alpha = .75;
        return self.animatedTileRenderer;
	}
	return nil;
}

@end
