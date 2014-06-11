//
//  TCCTimeFrameParser.h
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TCCTimeFrameParser : NSObject

@property (readonly) NSString *ingestTimeStampString;
@property (readonly) NSArray *frameTimeStamps;
@property (readonly) NSArray *templateFrameTimeURLs;
@property (readonly) NSArray *timeFrameURLs;

- (id) initWithData: (NSData *)timeStampData;

@end
