//
//  CCIDU2FService.m
//  CCIDU2F
//

#import <Cocoa/Cocoa.h>
#import "CCIDU2FService.h"
#import "APDU.h"

static const char kAPDUSelectU2FResponse[] = {
    'U','2','F','_','V','2'
};

static const char kU2FLegacyAID[] = {
    0xA0, 0x00, 0x00, 0x05, 0x27, 0x10, 0x02
};

static const char kU2FAID[] = {
    0xA0, 0x00, 0x00, 0x06, 0x47,
    0x2F, 0x00, 0x01
};


@implementation CCIDU2FService
- (CCIDU2FService *)init {
    self = [super init];
    self.slotManager = [TKSmartCardSlotManager defaultManager];

    self.slots = [[NSMutableDictionary alloc] init];
    self.cards = [[NSMutableSet alloc] init];

    return self;
}

- (void)start {
    [self.slotManager
        addObserver:self
        forKeyPath:@"slotNames"
        options:NSKeyValueObservingOptionInitial
        context:NULL
    ];
    NSLog(@"Waiting for smart cards...");

}

- (void)stop {
    [self.slotManager
        removeObserver:self
        forKeyPath:@"slotNames"
    ];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (object == self.slotManager && [keyPath isEqual:@"slotNames"]) {
        for (NSString* name in self.slotManager.slotNames) {
            if ([name containsString:@"Yubico"]) {
                // Ignore yubikeys, they already do U2F.
                NSLog(@"Ignoring Yubico devices, they already support U2F.");
                continue;
            }

            [self.slotManager
                getSlotWithName:name
                reply:^(TKSmartCardSlot * _Nullable slot) {
                    if (slot != nil) {
                        dispatch_async(
                            dispatch_get_main_queue(),
                            ^(void) {
                                if ([self.slots objectForKey:name] == nil) {
                                    [self onNewSmartCardSlot:slot];
                                }
                            }
                        );
                    }
                }
            ];
        }
    } else if([object isKindOfClass:TKSmartCardSlot.class] && [keyPath isEqual:@"state"]) {
        switch ([(TKSmartCardSlot*)object state]) {
            case TKSmartCardSlotStateMissing:
                {
                    TKSmartCardSlot* slot = (TKSmartCardSlot*)object;
                    dispatch_async(
                        dispatch_get_main_queue(),
                        ^(void) {
                            if ([slot isEqual:[self.slots valueForKey:slot.name]]) {
                                [self.slots removeObjectForKey:slot.name];
                            }
                            [slot removeObserver:self forKeyPath:@"state"];
                        }
                    );
                }
                break;
            case TKSmartCardSlotStateEmpty:
            case TKSmartCardSlotStateProbing:
            case TKSmartCardSlotStateMuteCard:
                break;
            case TKSmartCardSlotStateValidCard:
                {
                    TKSmartCardSlot* slot = (TKSmartCardSlot*)object;
                    dispatch_async(
                        dispatch_get_main_queue(),
                        ^(void) {
                            [self onSmartCardAdded:[slot makeSmartCard]];
                        }
                    );
                }
                break;
        }
    } else if([object isKindOfClass:TKSmartCard.class] && [keyPath isEqual:@"valid"]) {
        TKSmartCard* card = (TKSmartCard*)object;
        if (!card.valid) {
            [self onSmartCardRemoved:card];
        }
    }
}

- (void)onNewSmartCardSlot: (TKSmartCardSlot*)slot {
    [self.slots setObject:slot forKey:slot.name];

    [slot
        addObserver:self
        forKeyPath:@"state"
        options:NSKeyValueObservingOptionInitial
        context:NULL
    ];
}

- (void)onSmartCardAdded: (TKSmartCard*)card {
    NSLog(@"Smart card added to \"%@\": %@", card.slot.name, card.slot.ATR);

    // Check to see if it supports U2F.
    BOOL supportsU2F = [card
        inSessionWithError:nil
        executeBlock:^BOOL(NSError *__autoreleasing  _Nullable * _Nullable error) {
            UInt16 sw;
            NSLog(@"U2F check");

            if (error != nil) {
                NSLog(@"Error on U2F check");
                return NO;
            }

            // Select the applet.
            NSData* response = [card
                sendIns:0xa4
                p1:0x04
                p2:0x00
                data:[NSData dataWithBytes:kU2FAID length:sizeof(kU2FAID)]
                le:@0
                sw:&sw
                error:nil
            ];

            if (sw != 0x9000) {
                UInt16 sw2;
                response = [card
                    sendIns:0xa4
                    p1:0x04
                    p2:0x00
                    data:[NSData dataWithBytes:kU2FLegacyAID length:sizeof(kU2FLegacyAID)]
                    le:@0
                    sw:&sw2
                    error:nil
                ];
                if (sw2 == 0x9000) {
                    NSLog(@"Legacy U2F AID detected: %@", response);
                }
                return sw2 == 0x9000;
            }

            BOOL has_u2f = [response
                isEqual:[NSData
                    dataWithBytes:kAPDUSelectU2FResponse
                    length:sizeof(kAPDUSelectU2FResponse)
                ]
            ];

            if (!has_u2f) {
                NSLog(@"Card is not U2F compatible. SW = 0x%04X; DATA = %@", sw, response);
            }

            return has_u2f;
        }
    ];

    if (supportsU2F) {
        [self onU2FSmartCardAdded:card];
    } else {
        NSLog(@"Not U2F Compatible");
    }
}

- (void)sendError:(uint16_t)err forCid:(uint32_t)cid {
    U2FHID* hid = self.hid;
    if (hid == nil) {
        return;
    }
    uint8_t err_data[2] = {(uint8_t)(err>>8), (uint8_t)err};
    if (![hid sendMsgWithCid:cid data:[NSData dataWithBytes:err_data length:2]]) {
        NSLog(@"Unable to send error MSG for CID %u", cid);
    }
}

#define FLAG_FINAL_RED_SET      ((1<<0)|(1<<2))
#define FLAG_FINAL_RED_CLEAR    (1<<2)
#define FLAG_FINAL_GREEN_SET    ((1<<1)|(1<<3))
#define FLAG_FINAL_GREEN_CLEAR  (1<<3)
#define FLAG_BLINK_RED_INIT_SET      ((1<<4)|(1<<6))
#define FLAG_BLINK_RED_INIT_CLEAR    (1<<6)
#define FLAG_BLINK_GREEN_INIT_SET      ((1<<5)|(1<<7))
#define FLAG_BLINK_GREEN_INIT_CLEAR    (1<<7)

-(void)acr122ReaderFeedback:(TKSmartCard*)card flags:(uint8_t)flags t1dur:(uint8_t)t1dur t2dur:(uint8_t)t2dur count:(uint8_t)count buzzer:(uint8_t)buzz
{
    uint16_t ignore;
    uint8_t blink[4] = { t1dur, t2dur, count, buzz};
    uint8_t cla = card.cla;
    card.cla = 0xFF;
    [card
        sendIns:0x00
        p1:0x40
        p2:flags
        data:[NSData dataWithBytes:blink length:sizeof(blink)]
        le:@0
        sw:&ignore
        error:nil
    ];
    card.cla = cla;
}

-(void)winkCard:(TKSmartCard*)card {
    if ([card.slot.name containsString:@"ACR122U"]) {
        // The ACR122U supports the ability to blink the LED.
        [self
            acr122ReaderFeedback:card
            flags:FLAG_BLINK_GREEN_INIT_SET|FLAG_BLINK_RED_INIT_CLEAR
            t1dur:1
            t2dur:1
            count:4
            buzzer:0
        ];
    }
}

- (void)handleMsg:(NSData*)data withCid:(uint32_t)cid {
    NSLog(@"Got U2FHID MSG %@, CID: %u", data, cid);
    TKSmartCard* card = self.cards.anyObject;

    [card
        inSessionWithError:nil
        executeBlock:^BOOL(NSError *__autoreleasing  _Nullable * _Nullable error) {
            UInt16 sw;

            if (error != nil) {
                NSLog(@"Error: %@", *error);
                [self sendError:0x6F00 forCid:cid];
                return NO;
            }

            APDU* apdu = [APDU APDUFromRawData:data];

            if (![apdu isValid]) {
                NSLog(@"Invalid APDU");
                [self sendError:0x6F00 forCid:cid];
                return NO;
            }

            // Class sanity check, U2F is always CLA 0x00
            if (apdu.cla != 0x00) {
                NSLog(@"Invalid CLA 0x%02X", apdu.cla);
                [self sendError:0x6E00 forCid:cid];
                return NO;
            }

            card.cla = 0x00;

            uint8_t ins = apdu.ins;

            // Instruction sanity check
            if (!((ins>=1 && ins<=0x3) || (ins>=0x40 && ins<=0xbf))) {
                NSLog(@"Invalid INS 0x%02X", ins);
                [self sendError:0x6D00 forCid:cid];
                return NO;
            }

            // Select the applet.
            [card
                sendIns:0xa4
                p1:0x04
                p2:0x00
                data:[NSData dataWithBytes:kU2FAID length:sizeof(kU2FAID)]
                le:@0
                sw:&sw
                error:nil
            ];

            if (sw != 0x9000) {
                // Select the legacy applet.
                [card
                    sendIns:0xa4
                    p1:0x04
                    p2:0x00
                    data:[NSData dataWithBytes:kU2FLegacyAID length:sizeof(kU2FLegacyAID)]
                    le:@0
                    sw:&sw
                    error:nil
                ];
            }

            if (sw != 0x9000) {
                [self sendError:sw forCid:cid];
                return NO;
            }

            NSMutableData* result = [[card
                sendIns:apdu.ins
                p1:apdu.p1
                p2:apdu.p2
                data:apdu.data
                le:@0
                sw:&sw
                error:nil
            ] mutableCopy];

            if (result == nil) {
                [self sendError:0x6F00 forCid:cid];
                return NO;
            }

            uint8_t byte = (sw>>8);
            [result appendBytes:&byte length:1];
            byte = sw;
            [result appendBytes:&byte length:1];

            NSLog(@"Sending U2FHID Response %@, CID: %u, %04X", result, cid, sw);
            (void)[self.hid sendMsgWithCid:cid data:result];

            switch ((apdu.claIns<<16)+sw) {
            case 0x00016985:
            case 0x00026985:
                [self winkCard:card];
                return NO;
                break;
            default:
                break;
            }

            return YES;
        }
    ];
}

- (void)enableU2FHID {
    NSLog(@"Enabling Fake U2F HID Device");
    if (self.hid == nil) {
        self.hid = [[U2FHID alloc] init];

        [self.hid handle:MessageTypeMsg with:^BOOL(softu2f_hid_message hid_msg) {
            NSData* data = (__bridge NSData *)(hid_msg.data);

            dispatch_async(
                dispatch_get_main_queue(),
                ^(void) {
                    [self handleMsg:data withCid:hid_msg.cid];
                }
            );

            return true;
        }];

        if (![self.hid run]) {
            NSLog(@"Unable to start U2FHID thread");
        }
    }
}

- (void)disableU2FHID {
    NSLog(@"Disabling Fake U2F HID Device");
    if (self.hid != nil) {
        [self.hid handle:MessageTypeMsg with:^BOOL(softu2f_hid_message hid_msg) { return false; }];
        if (![self.hid stop]) {
            NSLog(@"Unable to stop U2FHID thread");
        }
        self.hid = nil;
    }
}

- (void)onU2FSmartCardAdded: (TKSmartCard*)card {
    NSLog(@"Card supports U2F!");
    [self.cards addObject:card];
    [card
        addObserver:self
        forKeyPath:@"valid"
        options:NSKeyValueObservingOptionInitial
        context:NULL
    ];
    if ([self.cards count] == 1) {
        [self enableU2FHID];
    }
}

- (void)onSmartCardRemoved: (TKSmartCard*)card {
    [card removeObserver:self forKeyPath:@"valid"];
    [self.cards removeObject:card];
    if ([self.cards count] == 0) {
        [self disableU2FHID];
    }
}

@end
