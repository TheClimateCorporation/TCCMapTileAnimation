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

#pragma mark - Public methods

- (void)start
{
    @try {
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
        
        NSError *error;
        NSURLResponse *response;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        if ([self isCancelled]) return;
        
        NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
        
        BOOL success = data && HTTPResponse.statusCode == 200;
        if (success) {
            self.tileImage = [UIImage imageWithData:data];
        }
        
        [self willChangeValueForKey:@"isFinished"];
        [self willChangeValueForKey:@"isExecuting"];
        
        self.executing = NO;
        self.finished = YES;
        
        [self didChangeValueForKey:@"isFinished"];
        [self didChangeValueForKey:@"isExecuting"];
    }
    @catch(NSException *exception) {
        // Suppress exception - do not rethrow
    }
}

@end
