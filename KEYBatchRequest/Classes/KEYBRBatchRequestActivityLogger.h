//
//  KEYBRBatchRequestActivityLogger.h
//  Pods
//
//  Created by Manuel Maly on 13.07.16.
//
//

#import <Foundation/Foundation.h>

@interface KEYBRBatchRequestActivityLogger : NSObject

+ (instancetype)sharedLogger;

- (void)startLogging;

- (void)stopLogging;

@end
