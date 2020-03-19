//
//  main.m
//  CCIDU2F
//

#import <Foundation/Foundation.h>
#import "softu2f.h"
#import "CCIDU2FService.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        CCIDU2FService* service = [[CCIDU2FService alloc] init];

        [service start];
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
