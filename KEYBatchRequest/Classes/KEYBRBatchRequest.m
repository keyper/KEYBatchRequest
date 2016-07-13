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
//    batchRequest.HTTPBodyStream = writer.openForInputStream;
    
    [[session dataTaskWithRequest:batchRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
        if (![HTTPResponse isKindOfClass:NSHTTPURLResponse.class]) {
            [self.requests enumerateObjectsUsingBlock:^(NSURLRequest *request, NSUInteger idx, BOOL * _Nonnull stop) {
                CompletionHandler completionHandler = self.completionHandlers[idx];
                completionHandler(nil, nil, [NSError errorWithDomain:@"" code:0 userInfo:nil]);
            }];
            return;
        }
        
        NSString *contentType = HTTPResponse.allHeaderFields[@"Content-Type"];
        
        KEYBRMultipartReaderDelegate *readerDelegate = [[KEYBRMultipartReaderDelegate alloc] initWithOriginalRequests:self.requests];
        readerDelegate.finishBlock = ^{
            
            [self.requests enumerateObjectsUsingBlock:^(NSURLRequest *request, NSUInteger idx, BOOL * _Nonnull stop) {
                CompletionHandler completionHandler = self.completionHandlers[idx];
                NSData *responseData = nil;
                NSURLResponse *response = nil;
                NSError *subResponseError = nil;
                [readerDelegate responseDataForRequest:request responseData:&responseData response:&response error:&subResponseError];
                
                completionHandler(response, responseData, error ?: subResponseError);
            }];
            
        };
        
        CBLMultipartReader *reader = [[CBLMultipartReader alloc] initWithContentType:contentType delegate:readerDelegate];
        [reader appendData:data];
        
    }] resume];
}

@end