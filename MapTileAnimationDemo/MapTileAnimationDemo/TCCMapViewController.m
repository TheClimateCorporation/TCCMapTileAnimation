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
@property (nonatomic, readwrite, strong) TCCTimeFrameParser *timeFrameParser;

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
    startingLocation.latitude = 40.7500;
    startingLocation.longitude = -111.8833;

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

	TCCMapViewController *controller = self;
	
	[self.animatedTileOverlay fetchTilesForMapRect: self.mapView.visibleMapRect zoomScale: [self.mapView currentZoomScale] progressBlock:^(NSUInteger currentTimeIndex, NSError *error) {
		
	} completionBlock:^(BOOL success, NSError *error) {
		if (success) {
			[controller.animatedTileRenderer setNeedsDisplay];
			NSLog(@"done");
		}
	}];
}
//============================================================
#pragma mark - MKMapViewDelegate Protocol
//============================================================
- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
	if (fullyRendered == YES) {
//		MKTileOverlay *tileOverlay = [[MKTileOverlay alloc] initWithURLTemplate: [templateURLs firstObject]];
//		[self.mapView addOverlay: tileOverlay];

		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			
			TCCMapViewController *controller = self;
			
			//start downloading the image tiles for the time frame indexes
			NSArray *templateURLs = self.timeFrameParser.templateFrameTimeURLs;
			MATAnimatedTileOverlay *overlay = [[MATAnimatedTileOverlay alloc] initWithTemplateURLs: templateURLs numberOfAnimationFrames: templateURLs.count frameDuration: 1.0];
			[overlay fetchTilesForMapRect: self.mapView.visibleMapRect zoomScale: [self.mapView currentZoomScale] progressBlock: ^(NSUInteger currentTimeIndex, NSError *error) {
				
				NSLog(@"current Index %lu", (unsigned long)currentTimeIndex);
				
			} completionBlock: ^(BOOL success, NSError *error) {
				if (success) {
					[controller.mapView addOverlay: overlay level: MKOverlayLevelAboveRoads];
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
		return renderer;
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
