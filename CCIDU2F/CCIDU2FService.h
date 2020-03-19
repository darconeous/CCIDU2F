//
//  CCIDU2FService.h
//  CCIDU2F
//

#import <Foundation/Foundation.h>
#import <CryptoTokenKit/CryptoTokenKit.h>
#import "CCIDU2F-Swift.h"

NS_ASSUME_NONNULL_BEGIN

@interface CCIDU2FService : NSObject
@property TKSmartCardSlotManager* slotManager;
@property NSMutableDictionary* slots;
@property NSMutableSet* cards;
@property U2FHID* _Nullable hid;

- (CCIDU2FService *)init;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
