#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

typedef MPMediaLibraryAuthorizationStatus (*LHMusicAuthorizationStatusOriginal)(id self, SEL selector);
typedef void (*LHMusicRequestAuthorizationOriginal)(id self, SEL selector, void (^handler)(MPMediaLibraryAuthorizationStatus status));
typedef NSArray<MPMediaItem *> *(*LHMusicQueryItemsOriginal)(MPMediaQuery *self, SEL selector);
typedef NSArray<MPMediaItemCollection *> *(*LHMusicQueryCollectionsOriginal)(MPMediaQuery *self, SEL selector);
typedef NSString *(*LHMusicItemStringOriginal)(MPMediaItem *self, SEL selector);
typedef NSDate *(*LHMusicItemDateOriginal)(MPMediaItem *self, SEL selector);
typedef SKCloudServiceAuthorizationStatus (*LHMusicCloudAuthorizationStatusOriginal)(id self, SEL selector);
typedef void (*LHMusicCloudCapabilitiesOriginal)(SKCloudServiceController *self, SEL selector, void (^completion)(SKCloudServiceCapability capabilities, NSError *error));

static LHMusicAuthorizationStatusOriginal LHMusicAuthorizationStatusOriginalImplementation;
static LHMusicRequestAuthorizationOriginal LHMusicRequestAuthorizationOriginalImplementation;
static LHMusicQueryItemsOriginal LHMusicQueryItemsOriginalImplementation;
static LHMusicQueryCollectionsOriginal LHMusicQueryCollectionsOriginalImplementation;
static LHMusicItemStringOriginal LHMusicItemGenreOriginalImplementation;
static LHMusicItemStringOriginal LHMusicItemArtistOriginalImplementation;
static LHMusicItemDateOriginal LHMusicItemDateAddedOriginalImplementation;
static LHMusicCloudAuthorizationStatusOriginal LHMusicCloudAuthorizationStatusOriginalImplementation;
static LHMusicCloudCapabilitiesOriginal LHMusicCloudCapabilitiesOriginalImplementation;

/** Replacement for `+[MPMediaLibrary authorizationStatus]`. */
static MPMediaLibraryAuthorizationStatus LHMusicAuthorizationStatusReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return MPMediaLibraryAuthorizationStatusDenied;
}

/** Replacement for `+[MPMediaLibrary requestAuthorization:]`. */
static void LHMusicRequestAuthorizationReplacement(id self, SEL selector, void (^handler)(MPMediaLibraryAuthorizationStatus status)) {
    (void)self;
    (void)selector;
    if (handler != nil) {
        handler(MPMediaLibraryAuthorizationStatusDenied);
    }
}

/** Replacement for `-[MPMediaQuery items]`. */
static NSArray<MPMediaItem *> *LHMusicQueryItemsReplacement(MPMediaQuery *self, SEL selector) {
    (void)self;
    (void)selector;
    return @[];
}

/** Replacement for `-[MPMediaQuery collections]`. */
static NSArray<MPMediaItemCollection *> *LHMusicQueryCollectionsReplacement(MPMediaQuery *self, SEL selector) {
    (void)self;
    (void)selector;
    return @[];
}

/** Replacement for taste-profile string fields on `MPMediaItem`. */
static NSString *LHMusicItemStringReplacement(MPMediaItem *self, SEL selector) {
    (void)self;
    (void)selector;
    return nil;
}

/** Replacement for `-[MPMediaItem dateAdded]`. */
static NSDate *LHMusicItemDateAddedReplacement(MPMediaItem *self, SEL selector) {
    (void)self;
    (void)selector;
    return nil;
}

/** Replacement for `+[SKCloudServiceController authorizationStatus]`. */
static SKCloudServiceAuthorizationStatus LHMusicCloudAuthorizationStatusReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return SKCloudServiceAuthorizationStatusDenied;
}

/** Replacement for `-[SKCloudServiceController requestCapabilitiesWithCompletionHandler:]`. */
static void LHMusicCloudCapabilitiesReplacement(SKCloudServiceController *self, SEL selector, void (^completion)(SKCloudServiceCapability capabilities, NSError *error)) {
    (void)self;
    (void)selector;
    if (completion != nil) {
        completion((SKCloudServiceCapability)0, nil);
    }
}

/** Hooks one Music selector and records whether it installed. */
static bool LHMusicHookMessage(LHHookBackend *backend, Class targetClass, const char *selectorName, void *replacement, void **original) {
    SEL selector = sel_registerName(selectorName);
    if (selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

/** Installs MediaPlayer and StoreKit music-library hooks. */
bool LHMitigation_media_library_music_inventory_empty_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    bool installed = false;

    Class libraryClass = NSClassFromString(@"MPMediaLibrary");
    if (libraryClass != Nil) {
        Class metaClass = object_getClass(libraryClass);
        installed = LHMusicHookMessage(backend,
                                       metaClass,
                                       "authorizationStatus",
                                       (void *)LHMusicAuthorizationStatusReplacement,
                                       (void **)&LHMusicAuthorizationStatusOriginalImplementation) || installed;
        installed = LHMusicHookMessage(backend,
                                       metaClass,
                                       "requestAuthorization:",
                                       (void *)LHMusicRequestAuthorizationReplacement,
                                       (void **)&LHMusicRequestAuthorizationOriginalImplementation) || installed;
    }

    Class queryClass = NSClassFromString(@"MPMediaQuery");
    if (queryClass != Nil) {
        installed = LHMusicHookMessage(backend,
                                       queryClass,
                                       "items",
                                       (void *)LHMusicQueryItemsReplacement,
                                       (void **)&LHMusicQueryItemsOriginalImplementation) || installed;
        installed = LHMusicHookMessage(backend,
                                       queryClass,
                                       "collections",
                                       (void *)LHMusicQueryCollectionsReplacement,
                                       (void **)&LHMusicQueryCollectionsOriginalImplementation) || installed;
    }

    Class itemClass = NSClassFromString(@"MPMediaItem");
    if (itemClass != Nil) {
        installed = LHMusicHookMessage(backend,
                                       itemClass,
                                       "genre",
                                       (void *)LHMusicItemStringReplacement,
                                       (void **)&LHMusicItemGenreOriginalImplementation) || installed;
        installed = LHMusicHookMessage(backend,
                                       itemClass,
                                       "artist",
                                       (void *)LHMusicItemStringReplacement,
                                       (void **)&LHMusicItemArtistOriginalImplementation) || installed;
        installed = LHMusicHookMessage(backend,
                                       itemClass,
                                       "dateAdded",
                                       (void *)LHMusicItemDateAddedReplacement,
                                       (void **)&LHMusicItemDateAddedOriginalImplementation) || installed;
    }

    Class cloudClass = NSClassFromString(@"SKCloudServiceController");
    if (cloudClass != Nil) {
        installed = LHMusicHookMessage(backend,
                                       object_getClass(cloudClass),
                                       "authorizationStatus",
                                       (void *)LHMusicCloudAuthorizationStatusReplacement,
                                       (void **)&LHMusicCloudAuthorizationStatusOriginalImplementation) || installed;
        installed = LHMusicHookMessage(backend,
                                       cloudClass,
                                       "requestCapabilitiesWithCompletionHandler:",
                                       (void *)LHMusicCloudCapabilitiesReplacement,
                                       (void **)&LHMusicCloudCapabilitiesOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_media_library_music_inventory_empty);
    }
    return true;
}
