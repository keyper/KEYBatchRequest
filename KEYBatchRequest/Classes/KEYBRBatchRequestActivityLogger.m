//
//  KEYBRBatchRequestActivityLogger.m
//  Pods
//
//  Created by Manuel Maly on 13.07.16.
//
//

#import "KEYBRBatchRequestActivityLogger.h"
#import "KEYBRBatchRequestStats.h"

@implementation KEYBRBatchRequestActivityLogger

+ (instancetype)sharedLogger {
    static KEYBRBatchRequestActivityLogger *_sharedLogger = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedLogger = [[self alloc] init];
    });
    
    return _sharedLogger;
}

- (void)dealloc {
    [self stopLogging];
}

- (void)startLogging {
    [self stopLogging];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batchRequestFinished:) name:KEYBRBatchRequestStatsNotificationName object:nil];
}

- (void)stopLogging {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)batchRequestFinished:(NSNotification *)note {

    KEYBRBatchRequestStats *stats = note.object;
    CFTimeInterval elapsedTime = stats.endTime - stats.startTime;
    NSLog(@"BATCH-POST [%.04f s]", elapsedTime);
    
    if (stats.responses.count != stats.requests.count) {
        return;
    }
    
    [stats.responses enumerateObjectsUsingBlock:^(NSHTTPURLResponse * _Nonnull response, NSUInteger idx, BOOL * _Nonnull stop) {
        NSURLRequest *request = stats.requests[idx];
        
        NSLog(@"-- %lu %@ '%@'", (long unsigned)response.statusCode, request.HTTPMethod, request.URL.absoluteString);
    }];
}

@end
