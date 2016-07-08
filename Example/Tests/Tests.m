//
//  KEYBatchRequestTests.m
//  KEYBatchRequestTests
//
//  Created by Manuel Maly on 07/08/2016.
//  Copyright (c) 2016 Manuel Maly. All rights reserved.
//

// https://github.com/Specta/Specta

SpecBegin(InitialSpecs)


describe(@"these will pass", ^{
    
    it(@"can do maths", ^{
        expect(1).beLessThan(23);
    });
    
    it(@"can read", ^{
        expect(@"team").toNot.contain(@"I");
    });
    
    it(@"will wait and succeed", ^{
        waitUntil(^(DoneCallback done) {
            done();
        });
    });
});

SpecEnd

