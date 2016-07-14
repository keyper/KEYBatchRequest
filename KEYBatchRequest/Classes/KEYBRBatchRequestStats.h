//
//  KEYBRBatchRequestStats.h
//  Pods
//
//  Created by Manuel Maly on 13.07.16.
//
//

#import <Foundation/Foundation.h>

extern NSString * const KEYBRBatchRequestStatsNotificationName;

@interface KEYBRBatchRequestStats : NSObject

@property (assign, nonatomic) CFTimeInterval startTime;
@property (assign, nonatomic) CFTimeInterval endTime;
@property (copy, nonatomic) NSArray<NSURLRequest *>* requests;
@property (copy, nonatomic) NSArray<NSHTTPURLResponse *>* responses;

@end
