//
//  TCCViewController.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapViewController.h"
#import "TCCTimeFrameParser.h"

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
	self.currentTimeIndex = 1;
	
    // Set the starting  location.
    CLLocationCoordinate2D startingLocation;
    startingLocation.latitude = 35.2269;  //St. Louis, MO
    startingLocation.longitude = -80.8433;
	
	self.mapView.region = MKCoordinateRegionMakeWithDistance(startingLocation, 180000, 180000);
    [self.mapView setCenterCoordinate: startingLocation];

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
	__block TCCMapViewController *mapController = self;
	
	self.timeFrameParser = [[TCCTimeFrameParser alloc] initWithData: theTimeFrameData];

	NSArray *templateURLs = self.timeFrameParser.templateFrameTimeURLs;
	NSString *templateURL = [templateURLs firstObject];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		MKTileOverlay *tileOverlay = [[MKTileOverlay alloc] initWithURLTemplate: templateURL];
		[mapController.mapView addOverlay: tileOverlay];
	});
}
// called by the tile provider to get a base URI (without tile coordinates) for a given time index
- (NSString *)baseURIForTimeIndex: (NSUInteger)aTimeIndex;
{
	return [self.timeFrameParser.timeFrameURLs objectAtIndex: aTimeIndex];
}
- (NSString *)uniqueCacheKey
{
	//this will grab the the time stamp string for the currentTimeIndex, we use this as a unique key
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
		
		//start downloading the image tiles for the time frame indexes
		[self.tileProvider fetchTilesForMapRect: mapView.visibleMapRect zoomScale: [mapView currentZoomScale] timeIndex: self.currentTimeIndex completionBlock:^(NSArray *tileArray) {
			NSArray *array = tileArray;
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
	return nil;
}
//============================================================

//============================================================

@end
