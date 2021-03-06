//
//  KEYBRBatchRequest.m
//  Pods
//
//  Created by Manuel Maly on 08.07.16.
//
//

#import <Foundation/Foundation.h>
#import "KEYBRBatchRequest.h"
#import "KEYBRMultipartReaderDelegate.h"
#import "CBLMultipartWriter.h"
#import "CBLMultipartReader.h"
#import <QuartzCore/CABase.h>
#import "KEYBRBatchRequestStats.h"

typedef void (^CompletionHandler)(NSURLResponse *response, NSData *responseData, NSError *error);

@interface KEYBRBatchRequest()

@property (assign, nonatomic) BOOL started;
@property (strong, nonatomic) KEYBRMultipartReaderDelegate *readerDelegate;
@property (strong, nonatomic) NSMutableArray *requests;
@property (strong, nonatomic) NSMutableArray *completionHandlers;

@end

@implementation KEYBRBatchRequest

- (instancetype)init {

    if ((self = [super init])) {
        self.readerDelegate = KEYBRMultipartReaderDelegate.new;
    }
    
    return self;
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, NSData *responseData, NSError *error))completionHandler {
    
    if (self.started) {
        NSAssert(NO, @"Cannot add requests to batch request once started");
    }
    
    if (!self.requests) {
        self.requests = NSMutableArray.new;
    }
    
    if (!self.completionHandlers) {
        self.completionHandlers = NSMutableArray.new;
    }
    
    [self.requests addObject:request];
    [self.completionHandlers addObject:[completionHandler copy]];
}

- (void)sendWithURLSession:(NSURLSession *)session withBatchRequestEndpointRequest:(NSURLRequest *)endpointRequest {
    if (self.started) {
        return;
    }
    
    if (self.requests.count == 0) {
        return;
    }
    
    self.started = YES;
    
    NSString *boundary = [NSString stringWithFormat:@"batch-%@", NSUUID.UUID.UUIDString];
    NSString *batchRequestContentType = [NSString stringWithFormat:@"multipart/mixed; boundary=\"%@\"", boundary];
    
    CBLMultipartWriter *writer = [[CBLMultipartWriter alloc] initWithContentType:batchRequestContentType
                                                                        boundary:boundary];
    
    for (NSURLRequest *request in self.requests) {
        [writer addBatchedRequest:request];
    }
    
    NSMutableURLRequest *batchRequest = endpointRequest.mutableCopy;
    batchRequest.HTTPMethod = @"POST";
    [batchRequest setValue:batchRequestContentType forHTTPHeaderField:@"Content-Type"];
    batchRequest.HTTPBody = writer.allOutput;
    
    // Might give slightly better performance?:
    // batchRequest.HTTPBodyStream = writer.openForInputStream;
    
    CFTimeInterval batchRequestStartTime = CACurrentMediaTime();
    
    [[session dataTaskWithRequest:batchRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        CFTimeInterval batchRequestEndTime = CACurrentMediaTime();
        
        KEYBRBatchRequestStats *stats = KEYBRBatchRequestStats.new;
        stats.startTime = batchRequestStartTime;
        stats.endTime = batchRequestEndTime;
        
        NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
        if (error || !response || ![HTTPResponse isKindOfClass:NSHTTPURLResponse.class]) {
            
            NSError *internalError = [NSError errorWithDomain:error.domain ?: @"" code:error ? error.code : 0 userInfo:error.userInfo];
            [self.requests enumerateObjectsUsingBlock:^(NSURLRequest *request, NSUInteger idx, BOOL * _Nonnull stop) {
                CompletionHandler completionHandler = self.completionHandlers[idx];
                completionHandler(nil, nil, internalError);
            }];
            
            if ([HTTPResponse isKindOfClass:NSHTTPURLResponse.class]) {
                self.completionHandler(((NSHTTPURLResponse *)HTTPResponse).statusCode == 401);
            } else {
                self.completionHandler(NO);
            }
            
            [NSNotificationCenter.defaultCenter postNotificationName:KEYBRBatchRequestStatsNotificationName object:stats userInfo:nil];
            return;
        }

        NSString *contentType = HTTPResponse.allHeaderFields[@"Content-Type"];
        
        __weak __typeof(self) weakSelf = self;
        self.readerDelegate = [[KEYBRMultipartReaderDelegate alloc] initWithOriginalRequests:self.requests];
        self.readerDelegate.finishBlock = ^{
            
            NSMutableArray *requests = NSMutableArray.new;
            NSMutableArray *responses = NSMutableArray.new;
            __block BOOL unauthorizedAccessOccurred = NO;
            
            [weakSelf.requests enumerateObjectsUsingBlock:^(NSURLRequest *request, NSUInteger idx, BOOL * _Nonnull stop) {
                CompletionHandler completionHandler = weakSelf.completionHandlers[idx];
                NSData *responseData = nil;
                NSHTTPURLResponse *response = nil;
                NSError *subResponseError = nil;
                [weakSelf.readerDelegate responseDataForRequest:request responseData:&responseData response:&response error:&subResponseError];
                
                completionHandler(response, responseData, error ?: subResponseError);
                
                if (response) {
                    [responses addObject:response];
                    [requests addObject:request];
                    
                    if (response.statusCode == 401) {
                        unauthorizedAccessOccurred = YES;
                    }
                }
                
            }];
            
            stats.requests = requests;
            stats.responses = responses;
            
            weakSelf.completionHandler(unauthorizedAccessOccurred);
            
            [NSNotificationCenter.defaultCenter postNotificationName:KEYBRBatchRequestStatsNotificationName object:stats userInfo:nil];
        };
        
        CBLMultipartReader *reader = [[CBLMultipartReader alloc] initWithContentType:contentType delegate:self.readerDelegate];
        [reader appendData:data];
        
    }] resume];
}

@end
