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
#import "TCCOverzoomTileOverlayRenderer.h"
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
    self.initialLoad = YES;
    self.timeSlider.enabled = NO;
    
    // I don't think this is really necessary... like Bruce was saying... thoughts???
    // Set the starting  location.
    CLLocationCoordinate2D startingLocation = {30.33, -81.52};
//     MKCoordinateSpan span = {8.403266, 7.031250};
       MKCoordinateSpan span = {7.0, 7.0};
       //calling regionThatFits: is very important, this will line up the visible map rect with the screen aspect ratio
       //which is important for calculating the number of tiles, their coordinates and map rect frame
       MKCoordinateRegion region = [self.mapView regionThatFits: MKCoordinateRegionMake(startingLocation, span)];

       [self.mapView setRegion: region animated: NO];
    
    self.timeFrameParser = [[TCCTimeFrameParser alloc] initWithURLString:FUTURE_RADAR_FRAMES_URI delegate:self];
}

- (IBAction)onHandleTimeIndexChange:(id)sender
{
	NSInteger sliderVal = floor(self.timeSlider.value);
    if (sliderVal == self.animatedTileOverlay.currentFrameIndex) return;
    
    [self.animatedTileOverlay moveToFrameIndex:sliderVal isContinuouslyMoving:YES];
    self.timeIndexLabel.text = [NSString stringWithFormat:@"%ld", (long)self.animatedTileOverlay.currentFrameIndex];
    [self.animatedTileRenderer setNeedsDisplay];
}

- (IBAction)finishedSliding:(id)sender
{
    NSInteger sliderVal = floor(self.timeSlider.value);
    [self.animatedTileOverlay moveToFrameIndex:(NSInteger)sliderVal isContinuouslyMoving:NO];
    self.timeIndexLabel.text = [NSString stringWithFormat:@"%ld", (long)self.animatedTileOverlay.currentFrameIndex];
    [self.animatedTileRenderer setNeedsDisplay];
}

- (IBAction)onHandleStartStopAction:(id)sender
{
	if (self.startStopButton.tag == TCCAnimationStateStopped) {
        self.downloadProgressView.hidden = NO;
        
		[self.animatedTileOverlay fetchTilesForMapRect:self.mapView.visibleMapRect zoomScale:self.animatedTileRenderer.zoomScale progressHandler:^(NSUInteger currentTimeIndex) {
			         
			CGFloat progressValue = (CGFloat)currentTimeIndex / (self.animatedTileOverlay.numberOfAnimationFrames - 1);
			[self.downloadProgressView setProgress: progressValue animated: YES];
            
            if (self.initialLoad) {
                self.timeSlider.enabled = NO;
                self.timeIndexLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)currentTimeIndex];
			}
		} completionHandler:^(BOOL success, NSError *error) {
			self.downloadProgressView.progress = 0.0;
            self.downloadProgressView.hidden = YES;

			if (success) {
                self.initialLoad = NO;
                
				[self.animatedTileOverlay moveToFrameIndex:self.animatedTileOverlay.currentFrameIndex
                                      isContinuouslyMoving:NO];
				[self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect
                                                          zoomScale: self.mapView.zoomScale];
				[self.animatedTileOverlay startAnimating];
			} else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self displayError:error];
                });
			}
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
    
	TCCAnimationTileOverlay *overlay = [[TCCAnimationTileOverlay alloc] initWithMapView:self.mapView templateURLs:pluckedArray frameDuration:0.20];
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
    } else if(currentAnimationState == TCCAnimationStateStopped) {
        [self.startStopButton setTitle:@"▶︎" forState:UIControlStateNormal];
    } else if(currentAnimationState == TCCAnimationStateAnimating) {
        [self.startStopButton setTitle:@"❚❚" forState:UIControlStateNormal];
    }
}

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex
{
	[self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect
                                              zoomScale:self.mapView.zoomScale];
	//update the slider if we are loading or animating
    self.timeIndexLabel.text = [NSString stringWithFormat: @"%lu", (unsigned long)animationFrameIndex];
 	if (animationTileOverlay.currentAnimationState != TCCAnimationStateStopped) {
        self.timeSlider.enabled = YES;
		self.timeSlider.value = animationFrameIndex;
	}
}

- (void)animationTileOverlay:(TCCAnimationTileOverlay *)animationTileOverlay didHaveError:(NSError *) error
{
     NSLog(@"%s ERROR %ld %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
    
    if (!self.alertView) {
        [self displayError:error];
    }
}


#pragma mark MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
	if (self.animatedTileOverlay.currentAnimationState == TCCAnimationStateAnimating) {
		[self.animatedTileOverlay pauseAnimating];
	}
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
    if ([overlay isKindOfClass: [MKTileOverlay class]]) {
        TCCOverzoomTileOverlayRenderer *renderer = [[TCCOverzoomTileOverlayRenderer alloc] initWithOverlay:overlay];
        renderer.drawDebugInfo = YES;
        renderer.alpha = .75;
        return renderer;
	}
	return nil;
}

@end
