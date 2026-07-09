#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSArray<AVSpeechSynthesisVoice *> *(*LHVoiceSpeechVoicesOriginal)(id self, SEL selector);
typedef AVSpeechSynthesisVoice *(*LHVoiceWithLanguageOriginal)(id self, SEL selector, NSString *language);
typedef AVSpeechSynthesisVoice *(*LHVoiceWithIdentifierOriginal)(id self, SEL selector, NSString *identifier);

static LHVoiceSpeechVoicesOriginal LHVoiceSpeechVoicesOriginalImplementation;
static LHVoiceWithLanguageOriginal LHVoiceWithLanguageOriginalImplementation;
static LHVoiceWithIdentifierOriginal LHVoiceWithIdentifierOriginalImplementation;

static BOOL LHVoiceIsVisible(AVSpeechSynthesisVoice *voice) {
    Class voiceClass = NSClassFromString(@"AVSpeechSynthesisVoice");
    if (voiceClass == Nil || ![voice isKindOfClass:voiceClass]) {
        return NO;
    }
    return (NSInteger)[voice quality] <= 1;
}

static NSArray<AVSpeechSynthesisVoice *> *LHFilteredVoices(NSArray<AVSpeechSynthesisVoice *> *voices) {
    if (![voices isKindOfClass:[NSArray class]] || [voices count] == 0) {
        return voices;
    }

    NSMutableArray<AVSpeechSynthesisVoice *> *filtered = [NSMutableArray arrayWithCapacity:[voices count]];
    for (AVSpeechSynthesisVoice *voice in voices) {
        if (LHVoiceIsVisible(voice)) {
            [filtered addObject:voice];
        }
    }

    if ([filtered count] == 0 || [filtered count] == [voices count]) {
        return voices;
    }
    return filtered;
}

static NSString *LHVoiceBaseLanguage(NSString *language) {
    if (![language isKindOfClass:[NSString class]] || [language length] == 0) {
        return nil;
    }
    NSRange dash = [language rangeOfString:@"-"];
    if (dash.location == NSNotFound || dash.location == 0) {
        return [language lowercaseString];
    }
    return [[language substringToIndex:dash.location] lowercaseString];
}

static AVSpeechSynthesisVoice *LHFirstVisibleVoiceForLanguage(NSString *language) {
    NSArray<AVSpeechSynthesisVoice *> *voices = LHFilteredVoices(LHVoiceSpeechVoicesOriginalImplementation != 0 ? LHVoiceSpeechVoicesOriginalImplementation((id)NSClassFromString(@"AVSpeechSynthesisVoice"), sel_registerName("speechVoices")) : nil);
    NSString *requestedBase = LHVoiceBaseLanguage(language);

    for (AVSpeechSynthesisVoice *voice in voices) {
        if ([voice.language isEqualToString:language]) {
            return voice;
        }
    }
    for (AVSpeechSynthesisVoice *voice in voices) {
        if (requestedBase != nil && [LHVoiceBaseLanguage(voice.language) isEqualToString:requestedBase]) {
            return voice;
        }
    }
    return nil;
}

static NSArray<AVSpeechSynthesisVoice *> *LHVoiceSpeechVoicesReplacement(id self, SEL selector) {
    if (LHVoiceSpeechVoicesOriginalImplementation == 0) {
        return nil;
    }
    return LHFilteredVoices(LHVoiceSpeechVoicesOriginalImplementation(self, selector));
}

static AVSpeechSynthesisVoice *LHVoiceWithLanguageReplacement(id self, SEL selector, NSString *language) {
    AVSpeechSynthesisVoice *original = nil;
    if (LHVoiceWithLanguageOriginalImplementation != 0) {
        original = LHVoiceWithLanguageOriginalImplementation(self, selector, language);
    }
    if (LHVoiceIsVisible(original)) {
        return original;
    }
    return LHFirstVisibleVoiceForLanguage(language);
}

static AVSpeechSynthesisVoice *LHVoiceWithIdentifierReplacement(id self, SEL selector, NSString *identifier) {
    if (LHVoiceWithIdentifierOriginalImplementation == 0) {
        return nil;
    }

    AVSpeechSynthesisVoice *original = LHVoiceWithIdentifierOriginalImplementation(self, selector, identifier);
    if (LHVoiceIsVisible(original)) {
        return original;
    }
    return nil;
}

bool LHMitigation_voices_inventory_avspeech_downloaded_hidden_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"AVSpeechSynthesisVoice");
    Class metaClass = object_getClass(targetClass);
    if (targetClass == Nil || metaClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_voices_inventory_avspeech_downloaded_hidden);
    }

    bool installed = false;
    SEL speechVoicesSelector = sel_registerName("speechVoices");
    SEL languageSelector = sel_registerName("voiceWithLanguage:");
    SEL identifierSelector = sel_registerName("voiceWithIdentifier:");

    if (speechVoicesSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             metaClass,
                                             speechVoicesSelector,
                                             (void *)LHVoiceSpeechVoicesReplacement,
                                             (void **)&LHVoiceSpeechVoicesOriginalImplementation) || installed;
    }
    if (languageSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             metaClass,
                                             languageSelector,
                                             (void *)LHVoiceWithLanguageReplacement,
                                             (void **)&LHVoiceWithLanguageOriginalImplementation) || installed;
    }
    if (identifierSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             metaClass,
                                             identifierSelector,
                                             (void *)LHVoiceWithIdentifierReplacement,
                                             (void **)&LHVoiceWithIdentifierOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_voices_inventory_avspeech_downloaded_hidden);
    }
    return true;
}
