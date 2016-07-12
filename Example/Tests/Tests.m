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
#import "KEYBRBatchRequest.h"

SpecBegin(InitialSpecs)


describe(@"Multipart Writer", ^{
    
    NSString *boundary = [NSString stringWithFormat:@"batch-%@", NSUUID.UUID.UUIDString];
    NSString *batchRequestContentType = [NSString stringWithFormat:@"multipart/mixed; boundary=\"%@\"", boundary];
    NSString *subRequestContentType = @"application/http; msgtype=request";
    
    it(@"serializes a request", ^{
        CBLMultipartWriter *writer = [[CBLMultipartWriter alloc] initWithContentType:batchRequestContentType
                                                                            boundary:boundary];
        
        NSURL *URL = [NSURL URLWithString:@"https://api.keyper.io/containers"];
        NSString *authHeader = @"AUTHTOKEN auth_token=\"e111f0b0-b455-43fe-b8ec-66aa31e9a87c\"";
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
        [writer addBatchedRequest:request];
        
        NSString *expectedOutcomeTemplate = @"\r\n--%@\r\n"
                                             "Content-Type: %@\r\n\r\n"
                                             "GET %@ HTTP/1.1\r\n"
                                             "Host: %@\r\n"
                                             "Authorization: %@\r\n\r\n\r\n"
                                             "--%@--";
        NSString *expectedOutcome = [NSString stringWithFormat:expectedOutcomeTemplate, boundary, subRequestContentType, URL.path, URL.host, authHeader, boundary];
        
        NSData *outcomeData = [writer allOutput];
        NSString *outcomeString = [[NSString alloc] initWithData:outcomeData encoding:NSUTF8StringEncoding];
        
        expect(outcomeString).equal(expectedOutcome);
    });
    
});


describe(@"KEYBRBatchRequest", ^{
    
    it(@"sends and parses a request", ^{
        
        KEYBRBatchRequest *batchRequest = KEYBRBatchRequest.new;
        
        NSMutableURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://develop.api.keyper.io/api/containers"]].mutableCopy;
        [request setValue:@"AUTHTOKEN auth_token=\"c2fcd85d-dc83-40ba-93b5-b0d3fa314681\"" forHTTPHeaderField:@"Authorization"];
        
        waitUntilTimeout(10000, ^(DoneCallback done) {
            [batchRequest addRequest:request completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error) {
                
                
                done();
            }];
            
            NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:nil delegateQueue:nil];
            NSMutableURLRequest *endpointRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://develop.api.keyper.io/api/batch"]].mutableCopy;
            [batchRequest sendWithURLSession:session withBatchRequestEndpointRequest:endpointRequest];
        });
        
//        
//        CBLMultipartWriter *writer = [[CBLMultipartWriter alloc] initWithContentType:batchRequestContentType
//                                                                            boundary:boundary];
//        
//        NSURL *URL = [NSURL URLWithString:@"https://api.keyper.io/containers"];
//        NSString *authHeader = @"AUTHTOKEN auth_token=\"e111f0b0-b455-43fe-b8ec-66aa31e9a87c\"";
//        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
//        [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
//        [writer addBatchedRequest:request];
//        
//        NSString *expectedOutcomeTemplate = @"\r\n--%@\r\n"
//        "Content-Type: %@\r\n"
//        "GET %@ HTTP/1.1\r\n"
//        "Host: %@\r\n"
//        "Authorization: %@\r\n\r\n"
//        "--%@--";
//        NSString *expectedOutcome = [NSString stringWithFormat:expectedOutcomeTemplate, boundary, subRequestContentType, URL.path, URL.host, authHeader, boundary];
//        
//        NSData *outcomeData = [writer allOutput];
//        NSString *outcomeString = [[NSString alloc] initWithData:outcomeData encoding:NSUTF8StringEncoding];
//        
//        expect(outcomeString).equal(expectedOutcome);
        
//        GET /api/containers HTTP/1.1
//    Host: develop.api.keyper.io
//    Authorization: AUTHTOKEN auth_token="c2fcd85d-dc83-40ba-93b5-b0d3fa314681"
//        Cache-Control: no-cache
//        Postman-Token: 96ae7b86-e108-036b-f7e3-967a489e914a
    });
    
});




SpecEnd

