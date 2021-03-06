//
//  KEYBRBatchRequest.h
//  Pods
//
//  Created by Manuel Maly on 08.07.16.
//
//

#import <Foundation/Foundation.h>

@interface KEYBRBatchRequest : NSObject

- (void)addRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, NSData *responseData, NSError *error))completionHandler;

- (void)sendWithURLSession:(NSURLSession *)session withBatchRequestEndpointRequest:(NSURLRequest *)endpointRequest;

@property (nonatomic, copy) NSString *tag;

@property (nonatomic, copy) void (^completionHandler)(BOOL unauthorizedAccessOccurred);

@end
