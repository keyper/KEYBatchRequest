//
//  CBLMultipartWriter.m
//  CouchbaseLite
//
//  Created by Jens Alfke on 2/2/12.
//  Copyright (c) 2012-2013 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//
//  Modifications copyright (c) 2016 keyper GmbH

#import "CBLMultipartWriter.h"
#import "CBLGZip.h"


// Don't compress data shorter than this (not worth the CPU time, plus it might not shrink)
#define kMinDataLengthToCompress 100


@implementation CBLMultipartWriter


- (instancetype) initWithContentType: (NSString*)type boundary: (NSString*)boundary {
    self = [super init];
    if (self) {
        _contentType = [type copy];
        _boundary = boundary ? [boundary copy] : [[NSUUID UUID] UUIDString];
        // Account for the final boundary to be written by -opened. Add its length now, because the
        // client is probably going to ask for my .length *before* it calls -open.
        NSString* finalBoundaryStr = [NSString stringWithFormat:@"\r\n--%@--", _boundary];
        _finalBoundary = [finalBoundaryStr dataUsingEncoding: NSUTF8StringEncoding];
        _length += _finalBoundary.length;
    }
    return self;
}




@synthesize boundary=_boundary;


- (NSString*) contentType {
    return [NSString stringWithFormat:@"%@; boundary=\"%@\"", _contentType, _boundary];
}


- (void) setNextPartsHeaders: (NSDictionary*)headers {
    _nextPartsHeaders = headers;
}

- (void)setValue:(NSString *)value forNextPartsHeader:(NSString *)header {
    NSMutableDictionary* headers = _nextPartsHeaders.mutableCopy ?: NSMutableDictionary.new;
    [headers setValue: value forKey: header];
    _nextPartsHeaders = headers;
}

// Adds the request as part of a multipart/mixed batch request. It could look like this:
//
// --batch_0cac279a-09b2-4ec1-a7a5-67670bdfec5f
// Content-Type: application/http; msgtype=request
// GET /api/events HTTP/1.1
// Host: yourhostname.com
// Authorization: your-auth-header-value
//
- (void)addBatchedRequest:(NSURLRequest *)request {
    
    // Boundary
    NSMutableString *part = [NSMutableString stringWithFormat: @"\r\n--%@\r\n", _boundary];
    
    // Content-Type
    [part appendString:@"Content-Type: application/http; msgtype=request\r\n\r\n"];
    
    // Path
    NSURLComponents *c = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
    NSString *path = [NSString stringWithFormat:@"%@?%@", c.path, c.query];
    [part appendString:[NSString stringWithFormat:@"%@ %@ HTTP/1.1\r\n", request.HTTPMethod, path]];
    
    // Host
    [part appendString:[NSString stringWithFormat:@"Host: %@\r\n", request.URL.host]];
    
    // All headers
    for (NSString *header in request.allHTTPHeaderFields.allKeys) {
        [part appendString:[NSString stringWithFormat:@"%@: %@\r\n", header, request.allHTTPHeaderFields[header]]];
    }
    
    [part appendString:@"\r\n"];
    
    [super addInput:[part dataUsingEncoding:NSUTF8StringEncoding] length:part.length];
}

// Overridden to prepend the MIME multipart separator+headers
- (void) addInput: (id)part length:(UInt64)length {
    NSMutableString* headers = [NSMutableString stringWithFormat: @"\r\n--%@\r\n", _boundary];
    [headers appendFormat: @"Content-Length: %llu\r\n", length];
    for (NSString* name in _nextPartsHeaders) {
        // Strip any CR or LF in the header value. This isn't real quoting, just enough to ensure
        // a spoofer can't add bogus headers by putting CRLF into a header value!
        NSMutableString* value = [_nextPartsHeaders[name] mutableCopy];
        [value replaceOccurrencesOfString: @"\r" withString: @""
                                  options: 0 range: NSMakeRange(0, value.length)];
        [value replaceOccurrencesOfString: @"\n" withString: @""
                                  options: 0 range: NSMakeRange(0, value.length)];
        [headers appendFormat: @"%@: %@\r\n", name, value];
    }
    [headers appendString: @"\r\n"];
    NSData* separator = [headers dataUsingEncoding: NSUTF8StringEncoding];
    [self setNextPartsHeaders: nil];

    [super addInput: separator length: separator.length];
    [super addInput: part length: length];
}


- (void) addGZippedData: (NSData*)data {
    if (data.length >= kMinDataLengthToCompress) {
        NSData* compressed = [CBLGZip dataByCompressingData: data];
        if (compressed.length < data.length) {
            data = compressed;
            [self setValue: @"gzip" forNextPartsHeader: @"Content-Encoding"];
        }
    }
    [self addData: data];
}


// Original code to add a CouchbaseLite Attachment. In order to make this compatible with
// this library, we would have to create our own attachment object, and emulate part of
// their CBL_Attachment behavior, e.g. getContentStreamDecoded:andLength:.
//
//- (CBLStatus) addAttachment: (CBL_Attachment*)attachment {
//    NSString* disposition = [NSString stringWithFormat:@"attachment; filename=%@",
//                             CBLQuoteString(attachment.name)];
//    [self setNextPartsHeaders: @{
//                                 @"Content-Disposition": disposition,
//                                 @"Content-Type": attachment.contentType,
//                                 @"Content-Encoding": attachment.encodingName
//                                 }];
//    uint64_t contentLength;
//    NSInputStream *contentStream = [attachment getContentStreamDecoded: NO
//                                                             andLength: &contentLength];
//    if (!contentStream)
//        return kCBLStatusAttachmentNotFound;
//    
//    uint64_t declaredLength = attachment.possiblyEncodedLength;
//    if (contentLength == 0)
//        contentLength = declaredLength;
//    else if (declaredLength != 0 && contentLength != declaredLength)
//        Warn(@"Attachment '%@' length mismatch; actually %llu, declared %llu",
//             attachment.name, contentLength, declaredLength);
//    
//    [self addStream: contentStream length: contentLength];
//    return kCBLStatusOK;
//}


- (void) opened {
    if (_finalBoundary) {
        // Append the final boundary:
        [super addInput: _finalBoundary length: 0];
        // _length was already adjusted for this in -init
        _finalBoundary = nil;
    }
    [super opened];
}


- (void) openForURLRequest: (NSMutableURLRequest*)request;
{
    request.HTTPBodyStream = [self openForInputStream];
    [request setValue: self.contentType forHTTPHeaderField: @"Content-Type"];
}


@end
