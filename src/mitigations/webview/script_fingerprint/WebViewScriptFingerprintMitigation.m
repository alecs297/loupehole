#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef void (^LHWebViewJavaScriptCompletion)(id _Nullable result, NSError *_Nullable error);
typedef void (*LHWebViewEvaluateJavaScriptOriginal)(id self, SEL selector, NSString *script, LHWebViewJavaScriptCompletion completionHandler);

static LHWebViewEvaluateJavaScriptOriginal LHWebViewEvaluateJavaScriptOriginalImplementation;

static bool LHWebViewScriptEquals(NSString *script, NSString *expected) {
    return [script isKindOfClass:[NSString class]] && [script isEqualToString:expected];
}

static bool LHWebViewScriptContainsAll(NSString *script, NSArray<NSString *> *needles) {
    if (![script isKindOfClass:[NSString class]]) {
        return false;
    }

    for (NSString *needle in needles) {
        if ([script rangeOfString:needle].location == NSNotFound) {
            return false;
        }
    }
    return true;
}

static NSString *LHWebViewReducedJavaScriptResult(NSString *script) {
    if (LHWebViewScriptEquals(script, @"navigator.userAgent")) {
        return @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";
    }
    if (LHWebViewScriptEquals(script, @"navigator.platform")) {
        return @"iPhone";
    }
    if (LHWebViewScriptEquals(script, @"JSON.stringify(navigator.languages)")) {
        return @"[\"en-US\",\"en\"]";
    }
    if (LHWebViewScriptEquals(script, @"String(new Date().getTimezoneOffset())")) {
        return @"0";
    }
    if (LHWebViewScriptContainsAll(script, (@[
            @"document.createElement('canvas')",
            @"getContext('2d')",
            @"toDataURL()",
            @"Math.PI*2"
        ]))) {
        return @"data:,";
    }
    if (LHWebViewScriptContainsAll(script, (@[
            @"getContext('webgl')",
            @"WEBGL_debug_renderer_info",
            @"UNMASKED_RENDERER_WEBGL"
        ]))) {
        return @"Apple Inc. | Apple GPU";
    }

    return nil;
}

/** Replacement for exact WebView JavaScript fingerprint probe shapes. */
static void LHWebViewEvaluateJavaScriptReplacement(id self, SEL selector, NSString *script, LHWebViewJavaScriptCompletion completionHandler) {
    NSString *replacement = LHWebViewReducedJavaScriptResult(script);
    if (replacement != nil && completionHandler != nil) {
        completionHandler(replacement, nil);
        return;
    }

    if (LHWebViewEvaluateJavaScriptOriginalImplementation != 0) {
        LHWebViewEvaluateJavaScriptOriginalImplementation(self, selector, script, completionHandler);
        return;
    }

    if (completionHandler != nil) {
        completionHandler(nil, nil);
    }
}

/** Installs WKWebView JavaScript probe reduction for observed fingerprint scripts. */
bool LHMitigation_webview_script_fingerprint_wkwebview_exact_probe_guard_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"WKWebView");
    SEL selector = sel_registerName("evaluateJavaScript:completionHandler:");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_webview_script_fingerprint_wkwebview_exact_probe_guard);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHWebViewEvaluateJavaScriptReplacement, (void **)&LHWebViewEvaluateJavaScriptOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_webview_script_fingerprint_wkwebview_exact_probe_guard);
    }

    return true;
}
