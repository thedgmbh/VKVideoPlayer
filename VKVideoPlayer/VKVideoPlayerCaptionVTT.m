//
//  VKVideoPlayerCaptionVTT.m
//  Pods
//
//
//  Created by sphatzik on 29/8/16.
//  Copyright © 2016 Spyridon Chatzikotoulas. All rights reserved.
//

#import "VKVideoPlayerCaptionVTT.h"

@implementation VKVideoPlayerCaptionVTT

#pragma mark - VKVideoPlayerCaptionParserProtocol
- (void)parseSubtitleRaw:(NSString *)vtt completion:(void (^)(NSMutableArray* segments, NSMutableArray* invalidSegments))completion {
    
    NSMutableArray* segments = [NSMutableArray array];
    NSMutableArray* invalidSegments = [NSMutableArray array];
    NSScanner *scanner = [NSScanner scannerWithString:vtt];
    
    NSString *vttSignature;
    [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&vttSignature];
    
    if (![vttSignature hasPrefix:@"WEBVTT"]) {
        NSLog(@"Invalid VTT File. Expecting WEBVTT, got %@", vttSignature);
        return;
    }
    
    NSInteger negativeTime = [self millisecondsFromTimecodeString:@"20:00:00.000"];
    
    while (![scanner isAtEnd]) {
        NSString *indexString;
        NSString *startString;
        NSString *endString;
        NSUInteger currLocation = scanner.scanLocation;
        BOOL setAsLastSubtitle = NO;
        
        [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&indexString];
        
        // break if we have reached the end
        if ([indexString containsString:@"NOTE end of file"]) {
            break;
        }
        
        // Check if we have an index line or not
        if ([indexString containsString:@"-->"]) {
            setAsLastSubtitle = YES;
            indexString = nil;
            scanner.scanLocation = currLocation;
        }
        
        [scanner scanUpToString:@" --> " intoString:&startString];
        [scanner scanString:@"-->" intoString:NULL];
        [scanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet] intoString:&endString];
        
        NSString *textString;
        [scanner scanUpToString:@"\n\n" intoString:&textString];
        textString = [textString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br>"];
        textString = [textString stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
        // Addresses trailing space added if CRLF is on a line by itself at the end of the SRT file
        textString = [textString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // Cut cues from end time
        NSRange cuesRange = [endString rangeOfString:@" "];
        if (cuesRange.location != NSNotFound) {
            endString = [endString substringToIndex:cuesRange.location];
        }
        
        NSNumber *start = [NSNumber numberWithInteger:[self millisecondsFromTimecodeString:startString]];
        NSNumber *end = [NSNumber numberWithInteger:[self millisecondsFromTimecodeString:endString]];
        BOOL isNegativeTime = [start integerValue] > negativeTime || [end integerValue] > negativeTime;
        BOOL isOverlappingSegment = segments.count > 0 && [segments.lastObject[@"end_time"] integerValue] > [start integerValue];
        BOOL isNextSegment = setAsLastSubtitle || segments.count == 0 || [indexString integerValue] > [segments.lastObject[@"index"] integerValue];
        BOOL isValidSegment = [start compare:end] == NSOrderedAscending;
        if (!isNegativeTime && isValidSegment && isNextSegment && !isOverlappingSegment) {
            NSMutableDictionary* segment = [NSMutableDictionary dictionary];
            [segment setValue:[NSNumber numberWithInteger:[indexString integerValue]] forKey:@"index"];
            [segment setValue:start forKey:@"start_time"];
            [segment setValue:end forKey:@"end_time"];
            [segment setValue:textString forKey:@"content"];
            [segments addObject:segment];
        } else {
            //      DDLogVerbose(@"\nInvalid segment: %@\nPrevious Endtime: %@\nstarttime %@\nendtime %@", textString, segments.lastObject[@"end_time"] ? segments.lastObject[@"end_time"] : @"unknown", start, end);
            [invalidSegments addObject:textString];
        }
        [scanner scanString:@"\n\n" intoString:NULL];
        
    }
    
    completion(segments, invalidSegments);
}

- (NSInteger)millisecondsFromTimecodeString:(NSString *)timecodeString {
    NSInteger hours = 0;
    NSInteger minutes = 0;
    NSInteger seconds = 0;
    NSInteger milliseconds = 0;
    
    NSMutableArray *timeComponents = [[timecodeString componentsSeparatedByString:@":"] mutableCopy];
    NSArray *secondsAndMillis = [[timeComponents lastObject] componentsSeparatedByString:@"."];
    [timeComponents removeLastObject];
    [timeComponents addObjectsFromArray:secondsAndMillis];
    
    // Add a zero for milliseconds if we don't have any
    if (secondsAndMillis.count != 2) [timeComponents addObject:@"0"];
    
    // Add zeros for missing hours, minutes, seconds
    for (NSInteger x = 4-timeComponents.count ; x>0 ; x--) {
        [timeComponents insertObject:@"0" atIndex:0];
    }
    
    NSAssert(timeComponents.count == 4, @"Expecting 4 time components exactly");
    
    hours = [timeComponents[0] integerValue];
    minutes = [timeComponents[1] integerValue];
    seconds = [timeComponents[2] integerValue];
    milliseconds = [timeComponents[3] integerValue];
    
    NSInteger totalNumSeconds = (hours * 3600) + (minutes * 60) + seconds;
    return totalNumSeconds * 1000 + milliseconds;
}

@end

