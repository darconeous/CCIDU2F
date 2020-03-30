//
//  APDU.h
//  CCIDU2F
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface APDU : NSObject
@property NSData* rawData;

-(APDU*)initWithRawData:(NSData*)data;

+(APDU*)APDUFromRawData:(NSData*)data;

-(BOOL)isValid;
-(BOOL)isExtended;

-(uint8_t)cla;
-(uint8_t)ins;
-(uint8_t)p1;
-(uint8_t)p2;
-(uint16_t)lc;
-(int)le;
-(NSData* _Nullable)data;

-(uint16_t)claIns;
-(uint16_t)p1P2;

@end

NS_ASSUME_NONNULL_END
