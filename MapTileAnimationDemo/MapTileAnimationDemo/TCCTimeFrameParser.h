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

@property (weak, nonatomic) id<TCCTimeFrameParserDelegateProtocol>delegate;
@property (strong, readonly, nonatomic) NSArray *templateFrameTimeURLs;

- (id)initWithURLString:(NSString *)aURLString delegate:(id)aDelegate;

@end
