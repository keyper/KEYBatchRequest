//
//  KEYBRMultipartReaderDelegate.h
//  Pods
//
//  Created by Manuel Maly on 08.07.16.
//
//

#import <Foundation/Foundation.h>
#import "CBLMultipartReader.h"

@interface KEYBRMultipartReaderDelegate : NSObject <CBLMultipartReaderDelegate>

- (instancetype)initWithOriginalRequests:(NSArray *)originalRequests finishBlock:(void (^)())finishBlock;
- (void)responseDataForRequest:(NSURLRequest *)request responseData:(NSData **)responseData response:(NSURLResponse **)response error:(NSError **)error;

@end
