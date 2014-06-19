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

#import "MKMapView+Extras.h"


//#define FUTURE_RADAR_FRAMES_URI "https://qa1-twi.climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"
#define FUTURE_RADAR_FRAMES_URI "http://climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"

@interface TCCMapViewController () <MKMapViewDelegate>

@property (nonatomic, readwrite, weak) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIStepper *timeIndexStepper;
@property (weak, nonatomic) IBOutlet UILabel *timeIndexLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;

@property (nonatomic, readwrite, strong) TCCTimeFrameParser *timeFrameParser;

@property (readwrite, weak) MKTileOverlayRenderer *tileOverlayRenderer;
@property (readwrite, weak) MATAnimatedTileOverlay *animatedTileOverlay;
@property (readwrite, weak) MATAnimatedTileOverlayRenderer *animatedTileRenderer;

@end

@implementation TCCMapViewController
//============================================================
- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the starting  location.
    CLLocationCoordinate2D startingLocation;
    startingLocation.latitude = 34.1811;
    startingLocation.longitude = -97.1294;

	[self.mapView setCenterCoordinate: startingLocation zoomLevel: 6 animated: NO];
	self.timeFrameParser = [[TCCTimeFrameParser alloc] initWithURLString: @FUTURE_RADAR_FRAMES_URI];
	
}
//============================================================
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
//============================================================
- (IBAction)onHandleTimeIndexChange:(id)sender
{
	self.animatedTileOverlay.currentTimeIndex = (NSInteger)self.timeIndexStepper.value;
	
	self.timeIndexLabel.text = [NSString stringWithFormat: @"%lu", (unsigned long)self.animatedTileOverlay.currentTimeIndex];

	[self.animatedTileOverlay updateImageTilesToCurrentTimeIndex];
	[self.animatedTileRenderer setNeedsDisplay];

}
//============================================================
#pragma mark - MKMapViewDelegate Protocol
//============================================================
- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
	if (fullyRendered == YES) {

		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			
			MKTileOverlay *tileOverlay = [[MKTileOverlay alloc] initWithURLTemplate: [self.timeFrameParser.templateFrameTimeURLs firstObject]];
			[self.mapView addOverlay: tileOverlay level: MKOverlayLevelAboveRoads];

			TCCMapViewController *controller = self;

			//start downloading the image tiles for the time frame indexes
			NSArray *templateURLs = self.timeFrameParser.templateFrameTimeURLs;
			MATAnimatedTileOverlay *overlay = [[MATAnimatedTileOverlay alloc] initWithTemplateURLs: templateURLs numberOfAnimationFrames: templateURLs.count frameDuration: 1.0];
			self.downloadProgressView.hidden = NO;
			[overlay fetchTilesForMapRect: self.mapView.visibleMapRect zoomScale: [self.mapView currentZoomScale] progressBlock: ^(NSUInteger currentTimeIndex, NSError *error) {
				
				CGFloat progressValue = (CGFloat)currentTimeIndex / (CGFloat)(templateURLs.count - 1);
				[controller.downloadProgressView setProgress: progressValue animated: YES];
				
			} completionBlock: ^(BOOL success, NSError *error) {
				
				if (success) {
					[self.tileOverlayRenderer setAlpha: 0.0];
					controller.timeIndexStepper.maximumValue = (double)templateURLs.count - 1;
					[controller.mapView addOverlay: overlay level: MKOverlayLevelAboveRoads];
					controller.downloadProgressView.hidden = YES;
					[controller.downloadProgressView setProgress: 0.0];
				}
			}];

		});
	}
}
//============================================================
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	
}
//============================================================
- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id < MKOverlay >)overlay
{
	if ([overlay isKindOfClass: [MKTileOverlay class]])
	{
		MKTileOverlayRenderer *renderer = [[MKTileOverlayRenderer alloc] initWithTileOverlay: (MKTileOverlay *)overlay];
		self.tileOverlayRenderer = renderer;
		return self.tileOverlayRenderer;
	}
	else if ([overlay isKindOfClass: [MATAnimatedTileOverlay class]])
	{
		self.animatedTileOverlay = (MATAnimatedTileOverlay *)overlay;
		MATAnimatedTileOverlayRenderer *renderer = [[MATAnimatedTileOverlayRenderer alloc] initWithOverlay: overlay];
		self.animatedTileRenderer = renderer;

		return self.animatedTileRenderer;
	}
	return nil;
}
//============================================================

//============================================================

@end
