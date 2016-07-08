//
//  KEYBatchRequestTests.m
//  KEYBatchRequestTests
//
//  Created by Manuel Maly on 07/08/2016.
//  Copyright (c) 2016 Manuel Maly. All rights reserved.
//

// https://github.com/Specta/Specta

#import <Foundation/Foundation.h>
#import <Specta/Specta.h>
#import <Expecta/Expecta.h>
#import "CBLMultipartWriter.h"

SpecBegin(InitialSpecs)


describe(@"Multipart Writer", ^{
    
    NSString *requestContentType = @"application/http; msgtype=request";
    NSString *boundary = [NSString stringWithFormat:@"batch-%@", NSUUID.UUID.UUIDString];
    
    it(@"serializes a request", ^{
        CBLMultipartWriter *writer = [[CBLMultipartWriter alloc] initWithContentType:requestContentType
                                                                            boundary:boundary];
        
        NSURL *URL = [NSURL URLWithString:@"https://api.keyper.io/containers"];
        NSString *authHeader = @"AUTHTOKEN auth_token=\"e111f0b0-b455-43fe-b8ec-66aa31e9a87c\"";
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        [writer addBatchedRequest:request];
        
        NSString *expectedOutcomeTemplate = @"\r\n--%@\r\n"
                                             "Content-Type: %@\r\n"
                                             "GET %@ HTTP/1.1\r\n"
                                             "Host: %@\r\n"
                                             "Authorization: %@\r\n\r\n"
                                             "--%@--";
        NSString *expectedOutcome = [NSString stringWithFormat:expectedOutcomeTemplate, boundary, requestContentType, URL.path, URL.host, authHeader, boundary];
        
        NSData *outcomeData = [writer allOutput];
        NSString *outcomeString = [[NSString alloc] initWithData:outcomeData encoding:NSUTF8StringEncoding];
        
        expect(outcomeString).equal(expectedOutcome);
    });
    
});

SpecEnd

