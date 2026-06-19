#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <spawn.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef THEOS_PACKAGE_INSTALL_PREFIX
#define THEOS_PACKAGE_INSTALL_PREFIX ""
#endif

#define LH_ROOTLESS_PATH(path) THEOS_PACKAGE_INSTALL_PREFIX path

typedef int (*LHNotifyPostFunction)(const char *name);
typedef void (*LHHookFunction)(void *target, void *replacement, void **original);

static LHNotifyPostFunction LHOriginalNotifyPost;
static atomic_bool LHPendingRefresh = false;

static bool LHStringContains(const char *haystack, const char *needle) {
    return haystack != 0 && needle != 0 && strstr(haystack, needle) != 0;
}

static bool LHIsInstalldProcess(void) {
    const char *name = getprogname();
    return name != 0 && strcmp(name, "installd") == 0;
}

static bool LHShouldRefreshForNotification(const char *name) {
    if (name == 0 || name[0] == '\0') {
        return false;
    }

    if (LHStringContains(name, "application_installed") ||
        LHStringContains(name, "application_uninstalled") ||
        LHStringContains(name, "application_updated") ||
        LHStringContains(name, "applicationRegistered") ||
        LHStringContains(name, "applicationUnregistered")) {
        return true;
    }

    bool installationFamily = LHStringContains(name, "MobileInstallation") ||
                              LHStringContains(name, "mobile.installation") ||
                              LHStringContains(name, "mobile.application") ||
                              LHStringContains(name, "installation_proxy");
    bool lifecycleEvent = LHStringContains(name, "install") ||
                          LHStringContains(name, "uninstall") ||
                          LHStringContains(name, "register") ||
                          LHStringContains(name, "unregister") ||
                          LHStringContains(name, "update");
    if (installationFamily && lifecycleEvent) {
        return true;
    }

    return LHStringContains(name, "LaunchServices") &&
           (LHStringContains(name, "application") || LHStringContains(name, "Application"));
}

static void LHSpawnRefresh(void) {
    const char *helperPath = LH_ROOTLESS_PATH("/usr/bin/lhctl");
    if (helperPath == 0 || access(helperPath, X_OK) != 0) {
        return;
    }

    pid_t pid = 0;
    char *const argv[] = { (char *)helperPath, (char *)"refresh-auto", 0 };
    char *const envp[] = { (char *)"PATH=/var/jb/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin", 0 };
    int result = posix_spawn(&pid, helperPath, 0, 0, argv, envp);
    if (result != 0) {
        return;
    }

    while (waitpid(pid, 0, 0) == -1 && errno == EINTR) {
    }
}

static void *LHRefreshWorker(void *unused) {
    (void)unused;
    sleep(2);
    LHSpawnRefresh();
    atomic_store(&LHPendingRefresh, false);
    return 0;
}

static void LHScheduleRefresh(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&LHPendingRefresh, &expected, true)) {
        return;
    }

    pthread_t thread;
    if (pthread_create(&thread, 0, LHRefreshWorker, 0) == 0) {
        pthread_detach(thread);
    } else {
        atomic_store(&LHPendingRefresh, false);
    }
}

static int LHNotifyPostReplacement(const char *name) {
    int result = 0;
    if (LHOriginalNotifyPost != 0) {
        result = LHOriginalNotifyPost(name);
    }

    if (LHShouldRefreshForNotification(name)) {
        LHScheduleRefresh();
    }
    return result;
}

__attribute__((constructor))
static void LHInstallRefreshTriggerStart(void) {
    if (!LHIsInstalldProcess()) {
        return;
    }

    LHHookFunction hookFunction = (LHHookFunction)dlsym(RTLD_DEFAULT, "MSHookFunction");
    void *notifyPost = dlsym(RTLD_DEFAULT, "notify_post");
    if (hookFunction == 0 || notifyPost == 0) {
        return;
    }

    hookFunction(notifyPost, (void *)LHNotifyPostReplacement, (void **)&LHOriginalNotifyPost);
}
