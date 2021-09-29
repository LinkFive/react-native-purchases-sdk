#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(PurchasesSdk, NSObject)

RCT_EXTERN_METHOD(multiply:(float)a withB:(float)b
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(launch:(NSString*)apiKey withEnvironment:(NSString*)environment
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(fetchSubscriptions:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(purchase:(NSString*)productId
                withResolver:(RCTPromiseResolveBlock)resolve
                withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(restore:(RCTPromiseResolveBlock)resolve
                withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(fetchReceiptInfo:(BOOL)fromCache
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)


@end
