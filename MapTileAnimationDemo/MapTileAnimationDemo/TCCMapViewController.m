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

#import "MKMapView+Extras.h"


//#define FUTURE_RADAR_FRAMES_URI "https://qa1-twi.climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"
#define FUTURE_RADAR_FRAMES_URI "http://climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"

@interface TCCMapViewController () <MKMapViewDelegate, MATAnimatedTileOverlayDelegate, TCCTimeFrameParserDelegateProtocol>

@property (nonatomic, readwrite, weak) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *timeIndexLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIButton *startStopButton;

@property (nonatomic, readwrite, strong) TCCTimeFrameParser *timeFrameParser;

@property (readwrite, weak) MKTileOverlayRenderer *tileOverlayRenderer;
@property (readwrite, weak) MATAnimatedTileOverlay *animatedTileOverlay;
@property (readwrite, weak) MATAnimatedTileOverlayRenderer *animatedTileRenderer;

@property (readwrite, assign) BOOL shouldStop;
@end

@implementation TCCMapViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the starting  location.
    CLLocationCoordinate2D startingLocation = {41.5908, -93.6208};
//	MKCoordinateSpan span = {8.403266, 7.031250};
	MKCoordinateSpan span = {7.0, 7.0};
	//calling regionThatFits: is very important, this will line up the visible map rect with the screen aspect ratio
	//which is important for calculating the number of tiles, their coordinates and map rect frame
	MKCoordinateRegion region = [self.mapView regionThatFits: MKCoordinateRegionMake(startingLocation, span)];
	
	[self.mapView setRegion: region animated: NO];
	
	self.shouldStop = NO;
//	[self.mapView setCenterCoordinate: startingLocation zoomLevel: 5 animated: NO];
}

- (void) viewDidAppear:(BOOL)animated
{
	[super viewDidAppear: animated];
	self.timeFrameParser = [[TCCTimeFrameParser alloc] initWithURLString: @FUTURE_RADAR_FRAMES_URI delegate: self];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onHandleTimeIndexChange:(id)sender
{
	self.timeIndexLabel.text = [NSString stringWithFormat: @"%lu", (unsigned long)self.animatedTileOverlay.currentTimeIndex];
	[self.animatedTileOverlay updateImageTilesToCurrentTimeIndex];
	[self.animatedTileRenderer setNeedsDisplayInMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale];

}

- (IBAction) onHandleStartStopAction: (id)sender
{
	
	if (self.startStopButton.tag == MATAnimatingState_stopped) {
		[self.tileOverlayRenderer setAlpha: 1.0];
		
        TCCMapViewController __weak *controller = self;
		
		//start downloading the image tiles for the time frame indexes
		self.downloadProgressView.hidden = NO;

		[self.animatedTileOverlay fetchTilesForMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale progressBlock: ^(NSUInteger currentTimeIndex, BOOL *stop) {
			
			CGFloat progressValue = (CGFloat)currentTimeIndex / (CGFloat)(self.animatedTileOverlay.numberOfAnimationFrames - 1);
			[controller.downloadProgressView setProgress: progressValue animated: YES];
			controller.timeIndexLabel.text = [NSString stringWithFormat: @"%lu", (unsigned long)currentTimeIndex];

			if (currentTimeIndex == 0) {
				[controller.tileOverlayRenderer setAlpha: 0.0];
				[controller.animatedTileRenderer setAlpha: 1.0];
			}
			
			//controller.animatedTileOverlay.currentTimeIndex = currentTimeIndex;
			[controller.animatedTileOverlay updateImageTilesToCurrentTimeIndex];
            
			[controller.animatedTileRenderer setNeedsDisplayInMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale];
			*stop = controller.shouldStop;
			
		} completionBlock: ^(BOOL success, NSError *error) {
			
			controller.downloadProgressView.hidden = YES;
			[controller.downloadProgressView setProgress: 0.0];
			controller.animatedTileOverlay.currentTimeIndex = 0;

			if (success) {
				[controller.animatedTileOverlay updateImageTilesToCurrentTimeIndex];
				
				[controller.animatedTileRenderer setNeedsDisplayInMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale];
				[controller.animatedTileOverlay startAnimating];
			} else {
				
				controller.shouldStop = NO;
			}
		}];
	} else if (self.startStopButton.tag == MATAnimatingState_loading) {
		self.shouldStop = YES;
	} else if (self.startStopButton.tag == MATAnimatingState_animating) {
		[self.animatedTileOverlay stopAnimating];
	}
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString: @"currentAnimatingState"]) {
		NSNumber *animatingState = [change objectForKey: NSKeyValueChangeNewKey];
		self.startStopButton.tag = [animatingState integerValue];
		
		switch ([animatingState integerValue]) {
			case MATAnimatingState_loading:
				[self.startStopButton setTitle: @"Cancel" forState: UIControlStateNormal];
				break;
			case MATAnimatingState_animating:
				[self.startStopButton setTitle: @"Stop" forState: UIControlStateNormal];
				break;
			default:
				[self.startStopButton setTitle: @"Play" forState: UIControlStateNormal];
				break;
		}
	}
}

#pragma mark - TCCTimeFrameParserDelegate Protocol

- (void) didLoadTimeStampData;
{
	MKTileOverlay *tileOverlay = [[MKTileOverlay alloc] initWithURLTemplate: [self.timeFrameParser.templateFrameTimeURLs firstObject]];
	[self.mapView addOverlay: tileOverlay level: MKOverlayLevelAboveRoads];
	
	NSArray *templateURLs = self.timeFrameParser.templateFrameTimeURLs;
	MATAnimatedTileOverlay *overlay = [[MATAnimatedTileOverlay alloc] initWithTemplateURLs: templateURLs numberOfAnimationFrames: templateURLs.count frameDuration: 0.25];
	overlay.delegate = self;
	
	[overlay addObserver: self forKeyPath: @"currentAnimatingState" options: NSKeyValueObservingOptionNew context: nil];
	
	[self.mapView addOverlay: overlay level: MKOverlayLevelAboveRoads];

}

#pragma mark - MATAnimatedTileOverlayDelegate Protocol

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex
{
	self.timeIndexLabel.text = [NSString stringWithFormat: @"%lu", (unsigned long)animationFrameIndex];
	[self.animatedTileRenderer setNeedsDisplayInMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale];

}

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didHaveError:(NSError *) error
{
	
}


#pragma mark - MKMapViewDelegate Protocol

- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
	if (fullyRendered == YES) {


	}
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
	if (self.startStopButton.tag != 0) {
		[self.animatedTileOverlay stopAnimating];
	}

	[self.tileOverlayRenderer setAlpha: 1.0];
	[self.animatedTileRenderer setAlpha: 0.0];

}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	if (animated == NO) {
		
	}
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
	if ([overlay isKindOfClass: [MKTileOverlay class]]) {
		MKTileOverlayRenderer *renderer = [[MKTileOverlayRenderer alloc] initWithTileOverlay: (MKTileOverlay *)overlay];
		self.tileOverlayRenderer = renderer;
		return self.tileOverlayRenderer;
	} else if ([overlay isKindOfClass: [MATAnimatedTileOverlay class]]) {
		self.animatedTileOverlay = (MATAnimatedTileOverlay *)overlay;
		MATAnimatedTileOverlayRenderer *renderer = [[MATAnimatedTileOverlayRenderer alloc] initWithOverlay: overlay];
		self.animatedTileRenderer = renderer;

		return self.animatedTileRenderer;
	}
	return nil;
}




@end
