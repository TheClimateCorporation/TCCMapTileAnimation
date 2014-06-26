//
//  TCCTimeFrameParser.h
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TCCTimeFrameParserDelegateProtocol <NSObject>

- (void) didLoadTimeStampData;

@end

@interface TCCTimeFrameParser : NSObject

@property (readwrite, weak) id<TCCTimeFrameParserDelegateProtocol>delegate;

@property (readonly) NSString *ingestTimeStampString;
@property (readonly) NSArray *frameTimeStamps;
@property (readonly) NSArray *templateFrameTimeURLs;
@property (readonly) NSArray *timeFrameURLs;

@property (readonly) NSUInteger countOfTimeIndexes;

- (id) initWithURLString: (NSString *)aURLString delegate: (id)aDelegate;


@end
