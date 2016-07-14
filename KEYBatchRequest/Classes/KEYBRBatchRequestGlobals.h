//
//  KEYBRBatchRequestGlobals.h
//  Pods
//
//  Created by Manuel Maly on 13.07.16.
//
//

#ifdef DEBUG
#define DLog(...) NSLog(@"%s %@", __PRETTY_FUNCTION__, [NSString stringWithFormat:__VA_ARGS__])
#else
#define DLog(...) do { } while (0)
#endif