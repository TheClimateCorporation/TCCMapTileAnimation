//
//  TCCTileFetchOperation.m
//  MapTileAnimationDemo
//
//  Created by Richard Shin on 8/1/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCTileFetchOperation.h"
#import "TCCAnimationTile.h"

@interface TCCTileFetchOperation ()
@property (nonatomic) BOOL finished;
@property (nonatomic) BOOL executing;
@property (strong, nonatomic) TCCAnimationTile *tile;
@property (nonatomic) NSUInteger frameIndex;
@property (strong, nonatomic) NSURL *tileURL;
@end

@implementation TCCTileFetchOperation

@synthesize finished = _finished;
@synthesize executing = _executing;

- (instancetype)initWithTile:(TCCAnimationTile *)tile frameIndex:(NSUInteger)frameIndex {
    if (self = [super init]) {
        _tile = tile;
        _frameIndex = frameIndex;
        _tileURL = [NSURL URLWithString:tile.templateURLs[frameIndex]];
    }
    return self;
}

#pragma mark - Custom accessors

- (BOOL)isFinished {
    return self.finished;
}

- (BOOL)isExecuting {
    return self.executing;
}

- (BOOL)isConcurrent {
    return YES;
}

- (NSURLSession *)session {
    if (!_session) {
        _session = [NSURLSession sharedSession];
    }
    return _session;
}

#pragma mark - Public methods

- (void)start
{
    // Always check for cancellation before launching the task.
    if ([self isCancelled]) {
        // Must move the operation to the finished state if it is canceled.
        [self willChangeValueForKey:@"isFinished"];
        self.finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    self.executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    // If the operation is not canceled, begin executing the task.
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.tileURL
                                                  cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                              timeoutInterval:5];
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
        if ((data && HTTPResponse.statusCode != 200) || !data) {
            self.tile.failedToFetch = YES;
        }
        
        [self willChangeValueForKey:@"isFinished"];
        [self willChangeValueForKey:@"isExecuting"];
        
        self.executing = NO;
        self.finished = YES;

        [self didChangeValueForKey:@"isFinished"];
        [self didChangeValueForKey:@"isExecuting"];
    }];
    [task resume];
}

@end
