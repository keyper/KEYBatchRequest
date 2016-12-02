//
//  KEYBRMultipartReaderDelegate.m
//  Pods
//
//  Created by Manuel Maly on 08.07.16.
//
//

#import "KEYBRMultipartReaderDelegate.h"

@interface KEYBRMultipartReaderDelegate()

@property (copy, nonatomic) NSArray *originalRequests; // order in batch response is guaranteed to be the same as in the request
@property (strong, nonatomic) NSMutableArray *responseDataItems;

@end

@implementation KEYBRMultipartReaderDelegate

- (instancetype)initWithOriginalRequests:(NSArray *)originalRequests {
    if ((self = [super init])) {
        self.originalRequests = originalRequests;
    }
    
    return self;
}

/** This method is called when a part's headers have been parsed, before its data is parsed. */
- (BOOL)startedPart:(NSDictionary *)headers {
    
    if (!self.responseDataItems) {
        self.responseDataItems = NSMutableArray.new;
    }
    
    [self.responseDataItems addObject:NSNull.null];
    
    return YES;
}

/** This method is called to append data to a part's body. */
- (BOOL)appendToPart:(NSData*)data {

    NSInteger currentItemIndex = self.responseDataItems.count - 1;
    if (self.responseDataItems[currentItemIndex] == NSNull.null) {
        [self.responseDataItems replaceObjectAtIndex:currentItemIndex withObject:data];
    } else {
        NSMutableData *existingData = [self.responseDataItems[currentItemIndex] mutableCopy];
        [existingData appendData:data];
        [self.responseDataItems replaceObjectAtIndex:currentItemIndex withObject:existingData];
    }
    
    return YES;
}

/** This method is called when a part is complete. */
- (BOOL)finishedPart {
    
    if (self.responseDataItems.count == self.originalRequests.count && self.finishBlock) {
        self.finishBlock();
        return NO;
    }
    
    return YES;
}

- (void)responseDataForRequest:(NSURLRequest *)request responseData:(NSData **)responseData response:(NSURLResponse **)response error:(NSError **)error {
    
    NSInteger idx = [self.originalRequests indexOfObject:request];
    if (idx == NSNotFound) {
        return;
    }
    
    //////// Batch request responses (ie. the individual sub request responses) look like this:
    // --c326f19c-fcbe-4d25-9281-5dc97e826e75
    // Content-Type: application/http; msgtype=response
    //
    // HTTP/1.1 200 OK
    // Content-Type: application/json; charset=utf-8
    //
    // BODY CONTENT OF 1st REQUEST
    // --c326f19c-fcbe-4d25-9281-5dc97e826e75
    // Content-Type: application/http; msgtype=response
    //
    // HTTP/1.1 200 OK
    // Content-Type: application/json; charset=utf-8
    //
    // BODY CONTENT OF 1st REQUEST
    // --c326f19c-fcbe-4d25-9281-5dc97e826e75--
    
    NSString *HTTPVersion = nil;
    NSInteger statusCode = 0;
    NSMutableDictionary *headers = NSMutableDictionary.new;
    NSString *payload = nil;
    
    NSData *rawData = self.responseDataItems[idx];
    NSString *rawString = [[NSString alloc] initWithData:rawData encoding:NSUTF8StringEncoding];
    
    NSScanner *scanner = [NSScanner scannerWithString:rawString];
    scanner.charactersToBeSkipped = nil;
    NSCharacterSet *newLine = [NSCharacterSet newlineCharacterSet];
    NSCharacterSet *numbers = [NSCharacterSet decimalDigitCharacterSet];
    
    // skip HTTP/
    [scanner scanString:@"HTTP/" intoString:nil];
    // scan http version
    [scanner scanCharactersFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet] intoString:&HTTPVersion];
    // skip whitespace between http version and status code
    [scanner scanUpToCharactersFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet] intoString:nil];
    // scan status code
    NSString *statusCodeString = nil;
    [scanner scanCharactersFromSet:numbers intoString:&statusCodeString];
    statusCode = [statusCodeString integerValue];
    
    if (statusCode == 0) {
        return;
    }
    
    [KEYBRMultipartReaderDelegate skipRestOfLineAndNewLine:scanner];
    
    // scan headers
    
    NSMutableCharacterSet *headerNameSet = [NSCharacterSet alphanumericCharacterSet].mutableCopy;
    [headerNameSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"-"]];
    [headerNameSet formUnionWithCharacterSet:newLine]; // to avoid scanning past the last header line
    
    NSMutableCharacterSet *headerSeparator = [NSCharacterSet whitespaceCharacterSet].mutableCopy;
    [headerSeparator formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@":"]];
    [headerSeparator formUnionWithCharacterSet:newLine]; // to avoid scanning past the last header line
    
    // scan header lines
    
    while (YES) {
        
        NSString *headerLine = nil;
        [scanner scanUpToCharactersFromSet:newLine intoString:&headerLine];
        
        if (headerLine.length == 0) {
            // This is the empty line after the headers. Next line will be payload.
            [KEYBRMultipartReaderDelegate skipRestOfLineAndNewLine:scanner];
            break;
        } else {
            NSScanner *headerScanner = [NSScanner scannerWithString:headerLine];

            NSString *headerName = nil;
            NSString *headerValue = nil;
            
            // make sure we reach first header name character
            [headerScanner scanUpToCharactersFromSet:headerNameSet intoString:nil];
            [headerScanner scanCharactersFromSet:headerNameSet intoString:&headerName];
            
            // skip : and whitespace
            [headerScanner scanUpToCharactersFromSet:[headerSeparator invertedSet] intoString:nil];
            // scan header value
            [headerScanner scanUpToCharactersFromSet:newLine intoString:&headerValue];
            
            if (headerName && headerValue) {
                headers[headerName] = headerValue;
            }
        }
    }
    
    // scan body
    
    payload = [rawString substringFromIndex:scanner.scanLocation];
    
    if (responseData) {
        *responseData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    if (response) {
        *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:statusCode HTTPVersion:HTTPVersion headerFields:headers];
    }
    
    if (error) {
        *error = nil;
    }
}

+ (void)skipRestOfLineAndNewLine:(NSScanner *)scanner {
    NSCharacterSet *newLine = [NSCharacterSet newlineCharacterSet];
    [scanner scanUpToCharactersFromSet:newLine intoString:nil];
    [scanner scanCharactersFromSet:newLine intoString:nil];
}

@end
