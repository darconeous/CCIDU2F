//
//  APDU.m
//  CCIDU2F
//

#import "APDU.h"

@implementation APDU
-(APDU*)initWithRawData:(NSData*)data {
    if (nil != (self = [self init])) {
        self.rawData = data;
    }
    return self;
}

+(APDU*)APDUFromRawData:(NSData*)data {
    return [[APDU alloc] initWithRawData:data];
}

-(const uint8_t*)bytes {
    return (const uint8_t*)[self.rawData bytes];
}

-(BOOL)isValid {
    if (self.rawData.length < 4) {
        return false;
    }

    uint16_t dataLength = [self lc];
    if ([self isExtended]) {
        if (self.rawData.length != 7+dataLength+2
            && self.rawData.length != 7+dataLength
        ) {
            return false;
        }
    } else {
        if (self.rawData.length != 5+dataLength+1
            && self.rawData.length != 5+dataLength
        ) {
            return false;
        }
    }

    return true;
}

-(uint8_t)cla {
    return [self bytes][0];
}

-(uint8_t)ins {
    return [self bytes][1];
}

-(uint8_t)p1 {
    return [self bytes][2];
}

-(uint8_t)p2 {
    return [self bytes][3];
}

-(uint16_t)claIns {
        return (self.cla<<8) + self.ins;
}

-(uint16_t)p1P2 {
        return (self.p1<<8) + self.p2;
}

-(BOOL)isExtended {
    if (self.rawData.length < 7) {
        return false;
    }
    if ([self bytes][4] != 0) {
        return false;
    }
    return true;
}

-(uint16_t)lc {
    if ([self isExtended]) {
        return ([self bytes][5]<<8) + [self bytes][6];
    } else if (self.rawData.length < 5) {
        return 0;
    }
    return [self bytes][4];
}

-(NSData*)data {
    if (self.isValid == false) {
        return nil;
    }

    uint16_t dataLength = [self lc];
    if (dataLength == 0) {
        return nil;
    } else if ([self isExtended]) {
        return [self.rawData subdataWithRange:NSMakeRange(7, dataLength)];
    } else {
        return [self.rawData subdataWithRange:NSMakeRange(5, dataLength)];
    }
}

-(int)le {
    uint16_t dataLength = [self lc];
    if ([self isExtended]) {
        if (self.rawData.length == 7+dataLength+2) {
            uint16_t len = ([self bytes][7+dataLength]<<8) + [self bytes][7+dataLength+1];
            return len;
        } else if (self.rawData.length == 7+dataLength) {
            return 0;
        } else {
            return -1;
        }
    } else {
        if (self.rawData.length == 5+dataLength+1) {
            uint16_t len = [self bytes][5+dataLength];
            return len;
        } else if (self.rawData.length == 5+dataLength) {
            return 0;
        } else {
            return -1;
        }
    }
}

@end
