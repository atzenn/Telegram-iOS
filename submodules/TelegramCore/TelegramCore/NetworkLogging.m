#import "NetworkLogging.h"

#import <Foundation/Foundation.h>

#ifdef BUCK
#   import <MtProtoKit/MtProtoKit.h>
#elif TARGET_OS_IOS
#   import <MTProtoKitDynamic/MTLogging.h>
#else
#   import <MTProtoKitMac/MTLogging.h>
#endif

static void (*bridgingTrace)(NSString *, NSString *);
void setBridgingTraceFunction(void (*f)(NSString *, NSString *)) {
    bridgingTrace = f;
}

static void (*bridgingShortTrace)(NSString *, NSString *);
void setBridgingShortTraceFunction(void (*f)(NSString *, NSString *)) {
    bridgingShortTrace = f;
}

static void TGTelegramLoggingFunction(NSString *format, va_list args) {
    if (bridgingTrace) {
        bridgingTrace(@"MT", [[NSString alloc] initWithFormat:format arguments:args]);
    }
}

static void TGTelegramShortLoggingFunction(NSString *format, va_list args) {
    if (bridgingShortTrace) {
        bridgingShortTrace(@"MT", [[NSString alloc] initWithFormat:format arguments:args]);
    }
}

void NetworkRegisterLoggingFunction() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MTLogSetLoggingFunction(&TGTelegramLoggingFunction);
        MTLogSetShortLoggingFunction(&TGTelegramShortLoggingFunction);
    });
}

void NetworkSetLoggingEnabled(bool value) {
    MTLogSetEnabled(value);
}
