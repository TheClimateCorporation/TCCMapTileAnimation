//
//  TCCViewController.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapViewController.h"
#import "TCCTimeFrameParser.h"
#import "MATAnimatedTileOverlayRenderer.h"
#import "MATAnimatedTileOverlay.h"
#import "MATAnimatedTileOverlayDelegate.h"
#import "MKOverzoomTileOverlayRenderer.h"
#import "MKMapView+Extras.h"

#define FUTURE_RADAR_FRAMES_URI @"http://climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"

@interface TCCMapViewController () <MKMapViewDelegate, MATAnimatedTileOverlayDelegate, TCCTimeFrameParserDelegateProtocol, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *timeIndexLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIButton *startStopButton;
@property (weak, nonatomic) IBOutlet UISlider *timeSlider;
@property (nonatomic) MKMapRect visibleMapRect;
@property (strong, nonatomic) TCCTimeFrameParser *timeFrameParser;
@property (nonatomic) BOOL initialLoad;
@property (weak, nonatomic) MATAnimatedTileOverlay *animatedTileOverlay;
@property (strong, nonatomic) MATAnimatedTileOverlayRenderer *animatedTileRenderer;

@property (nonatomic) BOOL shouldStop;

@end

@implementation TCCMapViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the starting  location.
    CLLocationCoordinate2D startingLocation = {30.33, -81.52};
//	MKCoordinateSpan span = {8.403266, 7.031250};
	MKCoordinateSpan span = {7.0, 7.0};
	//calling regionThatFits: is very important, this will line up the visible map rect with the screen aspect ratio
	//which is important for calculating the number of tiles, their coordinates and map rect frame
	MKCoordinateRegion region = [self.mapView regionThatFits: MKCoordinateRegionMake(startingLocation, span)];
	
	[self.mapView setRegion: region animated: NO];
	
	self.startStopButton.tag = MATAnimatingStateStopped;
    self.initialLoad = YES;
    self.visibleMapRect = self.mapView.visibleMapRect;
    
    self.timeFrameParser = [[TCCTimeFrameParser alloc] initWithURLString:FUTURE_RADAR_FRAMES_URI delegate:self];
}

- (IBAction)onHandleTimeIndexChange:(id)sender
{
	NSInteger sliderVal = floor(self.timeSlider.value);
    if (sliderVal == self.animatedTileOverlay.currentFrameIndex) return;
    
    [self.animatedTileOverlay moveToFrameIndex:sliderVal isContinuouslyMoving:YES];
    self.timeIndexLabel.text = [NSString stringWithFormat:@"%ld", (long)self.animatedTileOverlay.currentFrameIndex];
    [self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect zoomScale:self.mapView.zoomScale];
}

- (IBAction)finishedSliding:(id)sender
{
    NSInteger sliderVal = floor(self.timeSlider.value);
    [self.animatedTileOverlay moveToFrameIndex:(NSInteger)sliderVal isContinuouslyMoving:NO];
    self.timeIndexLabel.text = [NSString stringWithFormat:@"%ld", (long)self.animatedTileOverlay.currentFrameIndex];
    [self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect zoomScale:self.mapView.zoomScale];
}

- (IBAction)onHandleStartStopAction: (id)sender
{
	if (self.startStopButton.tag == MATAnimatingStateStopped) {
		//start downloading the image tiles for the time frame indexes

		[self.animatedTileOverlay fetchTilesForMapRect:self.mapView.visibleMapRect zoomScale:self.mapView.zoomScale progressHandler:^(NSUInteger currentTimeIndex, BOOL *stop) {
			         
			CGFloat progressValue = (CGFloat)currentTimeIndex / (self.animatedTileOverlay.numberOfAnimationFrames - 1);
			[self.downloadProgressView setProgress: progressValue animated: YES];
            
            if (self.initialLoad) {
                self.timeSlider.enabled = NO;
                self.timeIndexLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)currentTimeIndex];
			}

			*stop = self.shouldStop;
		} completionHandler:^(BOOL success, NSError *error) {
			self.downloadProgressView.progress = 0.0;

			if (success) {
                self.initialLoad = NO;
                self.downloadProgressView.hidden = YES;
                
				[self.animatedTileOverlay moveToFrameIndex:self.animatedTileOverlay.currentFrameIndex
                                      isContinuouslyMoving:NO];
				[self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect
                                                          zoomScale: self.mapView.zoomScale];
				[self.animatedTileOverlay startAnimating];
			} else {
                self.downloadProgressView.hidden = NO;
				self.shouldStop = NO;
			}
		}];
	} else if (self.startStopButton.tag == MATAnimatingStateLoading) {
		self.shouldStop = YES;
	} else if (self.startStopButton.tag == MATAnimatingStateAnimating) {
		[self.animatedTileOverlay pauseAnimating];
	}
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
    
	MATAnimatedTileOverlay *overlay = [[MATAnimatedTileOverlay alloc] initWithMapView:self.mapView templateURLs:pluckedArray frameDuration:0.20];
	overlay.delegate = self;
		
	[self.mapView addOverlay:overlay level:MKOverlayLevelAboveRoads];
	self.timeSlider.maximumValue = pluckedArray.count - 1;
}

#pragma mark MATAnimatedTileOverlayDelegate

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didChangeAnimationState:(MATAnimatingState)currentAnimationState {
   
    self.startStopButton.tag = currentAnimationState;

    //set titles of button to appropriate string based on currentAnimationState
    if (currentAnimationState == MATAnimatingStateLoading) {
        [self.startStopButton setTitle: @"◼︎" forState: UIControlStateNormal];
        // check if user has panned (visibleRects different)
        if(!MKMapRectEqualToRect(self.visibleMapRect, self.mapView.visibleMapRect)) {
            self.downloadProgressView.hidden = NO;
            self.initialLoad = YES;
        }
        self.visibleMapRect = self.mapView.visibleMapRect;
    }
    else if(currentAnimationState == MATAnimatingStateStopped) {
        [self.startStopButton setTitle: @"▶︎" forState: UIControlStateNormal];

    }
    else if(currentAnimationState == MATAnimatingStateAnimating) {
        [self.startStopButton setTitle: @"❚❚" forState: UIControlStateNormal];
    }
    
}

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex
{
	[self.animatedTileRenderer setNeedsDisplayInMapRect:self.mapView.visibleMapRect
                                              zoomScale:self.mapView.zoomScale];
	//update the slider if we are loading or animating
    self.timeIndexLabel.text = [NSString stringWithFormat: @"%lu", (unsigned long)animationFrameIndex];
 	if (animatedTileOverlay.currentAnimatingState != MATAnimatingStateStopped) {
        self.timeSlider.enabled = YES;
		self.timeSlider.value = animationFrameIndex;
	}
}

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didHaveError:(NSError *) error
{
	NSLog(@"%s ERROR %ld %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
	
	if (error.code == MATAnimatingErrorInvalidZoomLevel) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Invalid Zoom Level"
														message: error.localizedDescription
													   delegate: self
											  cancelButtonTitle: @"Ok"
											  otherButtonTitles: nil, nil];
		[alert show];
	}
}


#pragma mark MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
	if (self.startStopButton.tag != 0) {
		[self.animatedTileOverlay pauseAnimating];
	}
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{

	if ([overlay isKindOfClass: [MATAnimatedTileOverlay class]]) {
		self.animatedTileOverlay = (MATAnimatedTileOverlay *)overlay;
        self.animatedTileRenderer = [[MATAnimatedTileOverlayRenderer alloc] initWithOverlay:overlay];
        return self.animatedTileRenderer;
	}
    if ([overlay isKindOfClass: [MKTileOverlay class]]) {
        MKOverzoomTileOverlayRenderer *renderer = [[MKOverzoomTileOverlayRenderer alloc] initWithOverlay:overlay];
        renderer.alpha = .75;
        return renderer;
	}
	return nil;
}

@end
