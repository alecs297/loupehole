#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

typedef PHAuthorizationStatus (*LHPhotosAuthorizationStatusOriginal)(id self, SEL selector);
typedef PHAuthorizationStatus (*LHPhotosAuthorizationStatusForAccessLevelOriginal)(id self, SEL selector, PHAccessLevel accessLevel);
typedef void (*LHPhotosRequestAuthorizationOriginal)(id self, SEL selector, void (^handler)(PHAuthorizationStatus status));
typedef void (*LHPhotosRequestAuthorizationForAccessLevelOriginal)(id self, SEL selector, PHAccessLevel accessLevel, void (^handler)(PHAuthorizationStatus status));
typedef PHFetchResult<PHAsset *> *(*LHPhotosFetchAssetsOriginal)(id self, SEL selector, PHFetchOptions *options);
typedef PHFetchResult<PHAsset *> *(*LHPhotosFetchAssetsMediaTypeOriginal)(id self, SEL selector, PHAssetMediaType mediaType, PHFetchOptions *options);
typedef PHFetchResult<PHAsset *> *(*LHPhotosFetchAssetsInCollectionOriginal)(id self, SEL selector, PHAssetCollection *assetCollection, PHFetchOptions *options);
typedef PHFetchResult<PHAsset *> *(*LHPhotosFetchKeyAssetsOriginal)(id self, SEL selector, PHAssetCollection *assetCollection, PHFetchOptions *options);
typedef PHFetchResult<PHAssetCollection *> *(*LHPhotosFetchCollectionsOriginal)(id self, SEL selector, PHAssetCollectionType type, PHAssetCollectionSubtype subtype, PHFetchOptions *options);
typedef NSUInteger (*LHPhotosFetchResultCountOriginal)(PHFetchResult *self, SEL selector);
typedef CLLocation *(*LHPhotosAssetLocationOriginal)(PHAsset *self, SEL selector);

static LHPhotosAuthorizationStatusOriginal LHPhotosAuthorizationStatusOriginalImplementation;
static LHPhotosAuthorizationStatusForAccessLevelOriginal LHPhotosAuthorizationStatusForAccessLevelOriginalImplementation;
static LHPhotosRequestAuthorizationOriginal LHPhotosRequestAuthorizationOriginalImplementation;
static LHPhotosRequestAuthorizationForAccessLevelOriginal LHPhotosRequestAuthorizationForAccessLevelOriginalImplementation;
static LHPhotosFetchAssetsOriginal LHPhotosFetchAssetsOriginalImplementation;
static LHPhotosFetchAssetsMediaTypeOriginal LHPhotosFetchAssetsMediaTypeOriginalImplementation;
static LHPhotosFetchAssetsInCollectionOriginal LHPhotosFetchAssetsInCollectionOriginalImplementation;
static LHPhotosFetchKeyAssetsOriginal LHPhotosFetchKeyAssetsOriginalImplementation;
static LHPhotosFetchCollectionsOriginal LHPhotosFetchCollectionsOriginalImplementation;
static LHPhotosFetchResultCountOriginal LHPhotosFetchResultCountOriginalImplementation;
static LHPhotosAssetLocationOriginal LHPhotosAssetLocationOriginalImplementation;

/** Returns fetch options that match no Photos rows while preserving result type. */
static PHFetchOptions *LHPhotosEmptyFetchOptions(PHFetchOptions *options) {
    PHFetchOptions *emptyOptions = options != nil ? [options copy] : [[PHFetchOptions alloc] init];
    emptyOptions.predicate = [NSPredicate predicateWithValue:NO];
    return emptyOptions;
}

/** Replacement for `+[PHPhotoLibrary authorizationStatus]`. */
static PHAuthorizationStatus LHPhotosAuthorizationStatusReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return PHAuthorizationStatusAuthorized;
}

/** Replacement for `+[PHPhotoLibrary authorizationStatusForAccessLevel:]`. */
static PHAuthorizationStatus LHPhotosAuthorizationStatusForAccessLevelReplacement(id self, SEL selector, PHAccessLevel accessLevel) {
    (void)self;
    (void)selector;
    (void)accessLevel;
    return PHAuthorizationStatusAuthorized;
}

/** Replacement for `+[PHPhotoLibrary requestAuthorization:]`. */
static void LHPhotosRequestAuthorizationReplacement(id self, SEL selector, void (^handler)(PHAuthorizationStatus status)) {
    (void)self;
    (void)selector;
    if (handler != nil) {
        handler(PHAuthorizationStatusAuthorized);
    }
}

/** Replacement for `+[PHPhotoLibrary requestAuthorizationForAccessLevel:handler:]`. */
static void LHPhotosRequestAuthorizationForAccessLevelReplacement(id self, SEL selector, PHAccessLevel accessLevel, void (^handler)(PHAuthorizationStatus status)) {
    (void)self;
    (void)selector;
    (void)accessLevel;
    if (handler != nil) {
        handler(PHAuthorizationStatusAuthorized);
    }
}

/** Replacement for `+[PHAsset fetchAssetsWithOptions:]`. */
static PHFetchResult<PHAsset *> *LHPhotosFetchAssetsReplacement(id self, SEL selector, PHFetchOptions *options) {
    if (LHPhotosFetchAssetsOriginalImplementation != 0) {
        return LHPhotosFetchAssetsOriginalImplementation(self, selector, LHPhotosEmptyFetchOptions(options));
    }
    return nil;
}

/** Replacement for `+[PHAsset fetchAssetsWithMediaType:options:]`. */
static PHFetchResult<PHAsset *> *LHPhotosFetchAssetsMediaTypeReplacement(id self, SEL selector, PHAssetMediaType mediaType, PHFetchOptions *options) {
    if (LHPhotosFetchAssetsMediaTypeOriginalImplementation != 0) {
        return LHPhotosFetchAssetsMediaTypeOriginalImplementation(self, selector, mediaType, LHPhotosEmptyFetchOptions(options));
    }
    return nil;
}

/** Replacement for `+[PHAsset fetchAssetsInAssetCollection:options:]`. */
static PHFetchResult<PHAsset *> *LHPhotosFetchAssetsInCollectionReplacement(id self, SEL selector, PHAssetCollection *assetCollection, PHFetchOptions *options) {
    if (LHPhotosFetchAssetsInCollectionOriginalImplementation != 0) {
        return LHPhotosFetchAssetsInCollectionOriginalImplementation(self, selector, assetCollection, LHPhotosEmptyFetchOptions(options));
    }
    return nil;
}

/** Replacement for `+[PHAsset fetchKeyAssetsInAssetCollection:options:]`. */
static PHFetchResult<PHAsset *> *LHPhotosFetchKeyAssetsReplacement(id self, SEL selector, PHAssetCollection *assetCollection, PHFetchOptions *options) {
    if (LHPhotosFetchKeyAssetsOriginalImplementation != 0) {
        return LHPhotosFetchKeyAssetsOriginalImplementation(self, selector, assetCollection, LHPhotosEmptyFetchOptions(options));
    }
    return nil;
}

/** Replacement for `+[PHAssetCollection fetchAssetCollectionsWithType:subtype:options:]`. */
static PHFetchResult<PHAssetCollection *> *LHPhotosFetchCollectionsReplacement(id self, SEL selector, PHAssetCollectionType type, PHAssetCollectionSubtype subtype, PHFetchOptions *options) {
    if (LHPhotosFetchCollectionsOriginalImplementation != 0) {
        return LHPhotosFetchCollectionsOriginalImplementation(self, selector, type, subtype, LHPhotosEmptyFetchOptions(options));
    }
    return nil;
}

/** Replacement for `-[PHFetchResult count]`. */
static NSUInteger LHPhotosFetchResultCountReplacement(PHFetchResult *self, SEL selector) {
    (void)self;
    (void)selector;
    return 0;
}

/** Replacement for `-[PHAsset location]`. */
static CLLocation *LHPhotosAssetLocationReplacement(PHAsset *self, SEL selector) {
    (void)self;
    (void)selector;
    return nil;
}

/** Hooks one Photos selector and records whether it installed. */
static bool LHPhotosHookMessage(LHHookBackend *backend, Class targetClass, const char *selectorName, void *replacement, void **original) {
    SEL selector = sel_registerName(selectorName);
    if (selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

/** Installs Photos empty-library and geotag-hiding hooks. */
bool LHMitigation_photos_library_inventory_empty_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    bool installed = false;

    Class photoLibraryClass = NSClassFromString(@"PHPhotoLibrary");
    if (photoLibraryClass != Nil) {
        Class metaClass = object_getClass(photoLibraryClass);
        installed = LHPhotosHookMessage(backend,
                                        metaClass,
                                        "authorizationStatus",
                                        (void *)LHPhotosAuthorizationStatusReplacement,
                                        (void **)&LHPhotosAuthorizationStatusOriginalImplementation) || installed;
        installed = LHPhotosHookMessage(backend,
                                        metaClass,
                                        "authorizationStatusForAccessLevel:",
                                        (void *)LHPhotosAuthorizationStatusForAccessLevelReplacement,
                                        (void **)&LHPhotosAuthorizationStatusForAccessLevelOriginalImplementation) || installed;
        installed = LHPhotosHookMessage(backend,
                                        metaClass,
                                        "requestAuthorization:",
                                        (void *)LHPhotosRequestAuthorizationReplacement,
                                        (void **)&LHPhotosRequestAuthorizationOriginalImplementation) || installed;
        installed = LHPhotosHookMessage(backend,
                                        metaClass,
                                        "requestAuthorizationForAccessLevel:handler:",
                                        (void *)LHPhotosRequestAuthorizationForAccessLevelReplacement,
                                        (void **)&LHPhotosRequestAuthorizationForAccessLevelOriginalImplementation) || installed;
    }

    Class assetClass = NSClassFromString(@"PHAsset");
    if (assetClass != Nil) {
        Class metaClass = object_getClass(assetClass);
        installed = LHPhotosHookMessage(backend,
                                        metaClass,
                                        "fetchAssetsWithOptions:",
                                        (void *)LHPhotosFetchAssetsReplacement,
                                        (void **)&LHPhotosFetchAssetsOriginalImplementation) || installed;
        installed = LHPhotosHookMessage(backend,
                                        metaClass,
                                        "fetchAssetsWithMediaType:options:",
                                        (void *)LHPhotosFetchAssetsMediaTypeReplacement,
                                        (void **)&LHPhotosFetchAssetsMediaTypeOriginalImplementation) || installed;
        installed = LHPhotosHookMessage(backend,
                                        metaClass,
                                        "fetchAssetsInAssetCollection:options:",
                                        (void *)LHPhotosFetchAssetsInCollectionReplacement,
                                        (void **)&LHPhotosFetchAssetsInCollectionOriginalImplementation) || installed;
        installed = LHPhotosHookMessage(backend,
                                        metaClass,
                                        "fetchKeyAssetsInAssetCollection:options:",
                                        (void *)LHPhotosFetchKeyAssetsReplacement,
                                        (void **)&LHPhotosFetchKeyAssetsOriginalImplementation) || installed;
        installed = LHPhotosHookMessage(backend,
                                        assetClass,
                                        "location",
                                        (void *)LHPhotosAssetLocationReplacement,
                                        (void **)&LHPhotosAssetLocationOriginalImplementation) || installed;
    }

    Class collectionClass = NSClassFromString(@"PHAssetCollection");
    if (collectionClass != Nil) {
        installed = LHPhotosHookMessage(backend,
                                        object_getClass(collectionClass),
                                        "fetchAssetCollectionsWithType:subtype:options:",
                                        (void *)LHPhotosFetchCollectionsReplacement,
                                        (void **)&LHPhotosFetchCollectionsOriginalImplementation) || installed;
    }

    Class fetchResultClass = NSClassFromString(@"PHFetchResult");
    if (fetchResultClass != Nil) {
        installed = LHPhotosHookMessage(backend,
                                        fetchResultClass,
                                        "count",
                                        (void *)LHPhotosFetchResultCountReplacement,
                                        (void **)&LHPhotosFetchResultCountOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_photos_library_inventory_empty);
    }
    return true;
}
