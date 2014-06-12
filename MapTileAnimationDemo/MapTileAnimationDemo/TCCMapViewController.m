//
//  TCCViewController.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapViewController.h"
#import "TCCTimeFrameParser.h"

#import "TCCMapTileRenderer.h"
#import "TCCMapTileOverlay.h"

#import "TCCMapTileProviderProtocol.h"
#import "TCCMapTileProvider.h"
#import "MKMapView+Extras.h"


#define FUTURE_RADAR_FRAMES_URI "https://qa1-twi.climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"
//#define FUTURE_RADAR_FRAMES_URI "http://climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"

@interface TCCMapViewController () <MKMapViewDelegate>

@property (nonatomic, readwrite, weak) IBOutlet MKMapView *mapView;
@property (nonatomic, readwrite, strong) TCCMapTileProvider *tileProvider;
@property (nonatomic, readwrite, strong) TCCTimeFrameParser *timeFrameParser;
@property (readwrite, assign) NSUInteger currentTimeIndex;


@end

@implementation TCCMapViewController
//============================================================
- (void)viewDidLoad
{
    [super viewDidLoad];
	self.currentTimeIndex = 0;
	
    // Set the starting  location.
    CLLocationCoordinate2D startingLocation;
    startingLocation.latitude = 38.6272;
    startingLocation.longitude = -90.1978;

	[self.mapView setCenterCoordinate: startingLocation zoomLevel: 6 animated: NO];

	self.tileProvider = [[TCCMapTileProvider alloc] initWithTimeFrameURI: @FUTURE_RADAR_FRAMES_URI delegate: self];
}
//============================================================
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
//============================================================
#pragma mark - TCCMapTileProvider Protocol
//============================================================
- (void) tileProvider: (TCCMapTileProvider *)aProvider didFetchTimeFrameData: (NSData *)theTimeFrameData
{
	self.timeFrameParser = [[TCCTimeFrameParser alloc] initWithData: theTimeFrameData];

}
//============================================================
// called by the tile provider to get a base URI (without tile coordinates) for a given time index
- (NSString *)baseURIForTimeIndex: (NSUInteger)aTimeIndex;
{
	return [self.timeFrameParser.timeFrameURLs objectAtIndex: aTimeIndex];
}
//============================================================
- (NSString *)uniqueCacheKey
{
	//this will grab the the time stamp string for the currentTimeIndex, we use this as a unique key for caching
	NSString *indexURL = [[self.timeFrameParser timeFrameURLs] objectAtIndex: self.currentTimeIndex];
	NSString *key = [indexURL lastPathComponent];
	return key;
}
//============================================================
#pragma mark - MKMapViewDelegate Protocol
//============================================================
- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
	if (fullyRendered == YES) {
		
//		NSArray *templateURLs = self.timeFrameParser.templateFrameTimeURLs;
//		NSString *templateURL = [templateURLs firstObject];
//		
//		MKTileOverlay *tileOverlay = [[MKTileOverlay alloc] initWithURLTemplate: templateURL];
//		[self.mapView addOverlay: tileOverlay];

		__block TCCMapViewController *controller = self;
		
		//start downloading the image tiles for the time frame indexes
		[self.tileProvider fetchTilesForMapRect: self.mapView.visibleMapRect zoomScale: [self.mapView currentZoomScale] timeIndex: self.currentTimeIndex completionBlock:^(NSArray *tileArray) {
			
			TCCMapTileOverlay *overlay = [[TCCMapTileOverlay alloc] initWithTileArray: tileArray];
			[controller.mapView addOverlay: overlay];
			
		}];

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
	else if ([overlay isKindOfClass: [TCCMapTileOverlay class]])
	{
		TCCMapTileRenderer *renderer = [[TCCMapTileRenderer alloc] initWithOverlay: overlay];
		return renderer;
	}
	return nil;
}
//============================================================

//============================================================

@end
