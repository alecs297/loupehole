#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHValueQuantizer.h"

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#include <float.h>
#include <math.h>
#include <string.h>

typedef NSString *(*LHAudioPortNameOriginal)(id self, SEL selector);
typedef float (*LHAudioFloatOriginal)(id self, SEL selector);
typedef double (*LHAudioDoubleOriginal)(id self, SEL selector);
typedef BOOL (*LHAudioBoolOriginal)(id self, SEL selector);

static LHAudioPortNameOriginal LHAudioPortNameOriginalImplementation;
static LHAudioFloatOriginal LHAudioOutputVolumeOriginalImplementation;
static LHAudioDoubleOriginal LHAudioSampleRateOriginalImplementation;
static LHAudioDoubleOriginal LHAudioOutputLatencyOriginalImplementation;
static LHAudioDoubleOriginal LHAudioInputLatencyOriginalImplementation;
static LHAudioBoolOriginal LHAudioOtherAudioOriginalImplementation;
static LHPolicyEngine *LHAudioSessionPolicy;

LH_POLICY_SEED(audio_output_volume_curve)
LH_POLICY_SEED(audio_latency_jitter)

static NSString *LHAudioGenericPortName(NSString *portType) {
    if (![portType isKindOfClass:[NSString class]] || [portType length] == 0) {
        return nil;
    }

    if ([portType rangeOfString:@"BuiltInMic"].location != NSNotFound) {
        return @"Microphone";
    }
    if ([portType rangeOfString:@"BuiltInReceiver"].location != NSNotFound) {
        return @"Receiver";
    }
    if ([portType rangeOfString:@"BuiltInSpeaker"].location != NSNotFound) {
        return @"Speaker";
    }
    if ([portType rangeOfString:@"Headphones"].location != NSNotFound) {
        return @"Headphones";
    }
    if ([portType rangeOfString:@"Bluetooth"].location != NSNotFound) {
        return @"Bluetooth Audio";
    }
    if ([portType rangeOfString:@"AirPlay"].location != NSNotFound) {
        return @"AirPlay";
    }
    if ([portType rangeOfString:@"CarAudio"].location != NSNotFound) {
        return @"Car Audio";
    }
    if ([portType rangeOfString:@"HDMI"].location != NSNotFound) {
        return @"HDMI";
    }
    if ([portType rangeOfString:@"Line"].location != NSNotFound) {
        return @"Line Audio";
    }
    return @"Audio Route";
}

static NSString *LHAudioPortNameReplacement(id self, SEL selector) {
    SEL portTypeSelector = sel_registerName("portType");
    if (portTypeSelector != 0 && [self respondsToSelector:portTypeSelector]) {
        NSString *portType = ((NSString *(*)(id, SEL))objc_msgSend)(self, portTypeSelector);
        NSString *generic = LHAudioGenericPortName(portType);
        if (generic != nil) {
            return generic;
        }
    }

    if (LHAudioPortNameOriginalImplementation != 0) {
        return LHAudioPortNameOriginalImplementation(self, selector);
    }
    return nil;
}

static float LHAudioOutputVolumeReplacement(id self, SEL selector) {
    if (LHAudioOutputVolumeOriginalImplementation == 0) {
        return 0.0f;
    }

    float volume = LHAudioOutputVolumeOriginalImplementation(self, selector);
    if (!isfinite(volume) || volume < 0.0f || volume > 1.0f) {
        return volume;
    }
    double shaped = volume;
    if (LHAudioSessionPolicy != 0 &&
        LHValueMapUnitIntervalCurve(&LHAudioSessionPolicy->config.buildSeed,
                                    &LHGeneratedPolicySeed_audio_output_volume_curve,
                                    &LHAudioSessionPolicy->appContext.scope,
                                    (const uint8_t *)"outputVolume",
                                    sizeof("outputVolume") - 1,
                                    volume,
                                    0.04,
                                    0.015,
                                    &shaped)) {
        return (float)shaped;
    }
    return volume;
}

static double LHAudioNearestCommonSampleRate(double sampleRate) {
    static const double rates[] = { 44100.0, 48000.0 };
    double best = sampleRate;
    double bestDistance = DBL_MAX;
    for (size_t i = 0; i < sizeof(rates) / sizeof(rates[0]); i++) {
        double distance = fabs(sampleRate - rates[i]);
        if (distance < bestDistance) {
            best = rates[i];
            bestDistance = distance;
        }
    }
    return bestDistance <= 12000.0 ? best : sampleRate;
}

static double LHAudioSampleRateReplacement(id self, SEL selector) {
    if (LHAudioSampleRateOriginalImplementation == 0) {
        return 0.0;
    }

    double sampleRate = LHAudioSampleRateOriginalImplementation(self, selector);
    if (!isfinite(sampleRate) || sampleRate <= 0.0) {
        return sampleRate;
    }
    return LHAudioNearestCommonSampleRate(sampleRate);
}

static double LHAudioLatencyReplacement(id self, SEL selector, LHAudioDoubleOriginal original) {
    if (original == 0) {
        return 0.0;
    }

    double latency = original(self, selector);
    if (!isfinite(latency) || latency < 0.0) {
        return latency;
    }
    double shaped = latency;
    const char *context = selector == sel_registerName("outputLatency") ? "outputLatency" : "inputLatency";
    if (LHAudioSessionPolicy != 0 &&
        LHValueApplySeededSinePerturbation(&LHAudioSessionPolicy->config.buildSeed,
                                           &LHGeneratedPolicySeed_audio_latency_jitter,
                                           &LHAudioSessionPolicy->appContext.scope,
                                           (const uint8_t *)context,
                                           strlen(context),
                                           latency,
                                           0.002,
                                           0.04,
                                           &shaped)) {
        return shaped < 0.0 ? 0.0 : shaped;
    }
    return latency;
}

static double LHAudioOutputLatencyReplacement(id self, SEL selector) {
    return LHAudioLatencyReplacement(self, selector, LHAudioOutputLatencyOriginalImplementation);
}

static double LHAudioInputLatencyReplacement(id self, SEL selector) {
    return LHAudioLatencyReplacement(self, selector, LHAudioInputLatencyOriginalImplementation);
}

static BOOL LHAudioOtherAudioReplacement(id self, SEL selector) {
    if (LHAudioOtherAudioOriginalImplementation != 0) {
        (void)LHAudioOtherAudioOriginalImplementation(self, selector);
    }
    return NO;
}

static bool LHAudioHookMessage(LHHookBackend *backend, Class targetClass, const char *selectorName, void *replacement, void **original) {
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

bool LHMitigation_audio_session_avaudiosession_shaped_values_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHAudioSessionPolicy = policy;

    bool installed = false;
    Class portClass = NSClassFromString(@"AVAudioSessionPortDescription");
    installed = LHAudioHookMessage(backend,
                                   portClass,
                                   "portName",
                                   (void *)LHAudioPortNameReplacement,
                                   (void **)&LHAudioPortNameOriginalImplementation) || installed;

    Class sessionClass = NSClassFromString(@"AVAudioSession");
    installed = LHAudioHookMessage(backend,
                                   sessionClass,
                                   "outputVolume",
                                   (void *)LHAudioOutputVolumeReplacement,
                                   (void **)&LHAudioOutputVolumeOriginalImplementation) || installed;
    installed = LHAudioHookMessage(backend,
                                   sessionClass,
                                   "sampleRate",
                                   (void *)LHAudioSampleRateReplacement,
                                   (void **)&LHAudioSampleRateOriginalImplementation) || installed;
    installed = LHAudioHookMessage(backend,
                                   sessionClass,
                                   "outputLatency",
                                   (void *)LHAudioOutputLatencyReplacement,
                                   (void **)&LHAudioOutputLatencyOriginalImplementation) || installed;
    installed = LHAudioHookMessage(backend,
                                   sessionClass,
                                   "inputLatency",
                                   (void *)LHAudioInputLatencyReplacement,
                                   (void **)&LHAudioInputLatencyOriginalImplementation) || installed;
    installed = LHAudioHookMessage(backend,
                                   sessionClass,
                                   "isOtherAudioPlaying",
                                   (void *)LHAudioOtherAudioReplacement,
                                   (void **)&LHAudioOtherAudioOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_audio_session_avaudiosession_shaped_values);
    }
    return true;
}
