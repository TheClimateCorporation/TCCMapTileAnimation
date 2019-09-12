//
//  TCCAnimationTile.h
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCAnimationTile.h"

@implementation TCCAnimationTile

- (id)initWithFrame:(MKMapRect)frame x:(NSInteger)x y:(NSInteger)y z:(NSInteger)z
{
    self = [super init];
    if (self) {
        _x = x;
        _y = y;
        _z = z;
        _mapRectFrame = frame;
    }
    return self;
}
- (id)initWithFrame:(MKMapRect)frame configuringURLSession: (NSURLSessionConfiguration*)configuration x:(NSInteger)x y:(NSInteger)y z:(NSInteger)z {
    self = [super init];
    if (self) {
        _configuration = configuration;
        _x = x;
        _y = y;
        _z = z;
        _mapRectFrame = frame;
    }
    return self;
}

#pragma mark - Public methods

- (NSString *)description
{
    return [NSString stringWithFormat:@"(%ld, %ld, %ld) mapRectFrame origin: (%f, %f) size: (%f, %f)", (long)self.x, (long)self.y, (long)self.z, self.mapRectFrame.origin.x, self.mapRectFrame.origin.y, self.mapRectFrame.size.width, self.mapRectFrame.size.height];
}

#pragma mark - Overridden methods

//checks to see if hashCoords is equal on the two tiles being compared
- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TCCAnimationTile class]]) return NO;
    
    TCCAnimationTile *other = (TCCAnimationTile *)object;
    return [self hash] == [other hash] &&
    self.x == other.x &&
    self.y == other.y &&
    self.z == other.z;
}

//custom hash to identify tiles by their x/y/z (their hashCoords)
- (NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%ld/%ld/%ld", (long)self.x, (long)self.y, (long)self.z] hash];
}

- (void)fetchTileForFrameIndex:(NSInteger)frameIndex session:(NSURLSession *)session completionHandler:(void (^)(NSData * date, NSURLResponse * response, NSError * error))completionBlock {
    
    NSURL *url = [NSURL URLWithString:self.templateURLs[frameIndex]];
    self.tileImageIndex = frameIndex;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                                            timeoutInterval:0];
    [request setHTTPMethod: @"GET"];
    [request setAllHTTPHeaderFields:session.configuration.HTTPAdditionalHeaders];
    NSURLSessionTask * task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            self.tileImage = [UIImage imageWithData:data];
        }
        if (self.tileImage == nil) {
            self.failedToFetch = YES;
        }
        if (completionBlock) {
            completionBlock(data, response, error);
        }
    }];
    [task resume];
}

@end
