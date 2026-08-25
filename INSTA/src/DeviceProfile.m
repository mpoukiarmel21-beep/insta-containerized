//
//  DeviceProfile.m
//  Containerizer (Instagram tweak)
//

#import "DeviceProfile.h"
#import "ContainerManager.h"
#import "TweakLogger.h"
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <objc/runtime.h>

#if __has_include(<mach-o/dyld_interpose.h>)
#import <mach-o/dyld_interpose.h>
#else
// Le SDK iPhone ne fournit pas ce header : on definit la macro nous-memes.
// La section __DATA,__interpose est honoree par dyld au chargement de la dylib.
#ifndef DYLD_INTERPOSE
#define DYLD_INTERPOSE(_replacement, _replacee) \
__attribute__((used)) static struct { const void *replacement; const void *replacee; } _interpose_##_replacee \
__attribute__((section("__DATA,__interpose"))) = { (const void *)(unsigned long)&_replacement, (const void *)(unsigned long)&_replacee };
#endif
#endif

static Container *activeContainer(void) {
    return [[ContainerManager shared] activeContainer];
}

static NSString *spoofedModelIdentifier(void) {
    Container *c = activeContainer();
    return c.modelIdentifier.length ? c.modelIdentifier : @"iPhone15,4";
}

static NSString *spoofedSystemVersion(void) {
    Container *c = activeContainer();
    return c.iosVersion.length ? c.iosVersion : @"26.6.1";
}

static NSString *spoofedModelName(void) {
    Container *c = activeContainer();
    return c.modelName.length ? c.modelName : @"iPhone 15 Pro";
}

@interface UIDevice (Containerizer)
@end

@implementation UIDevice (Containerizer)
- (NSString *)cz_model { return spoofedModelName(); }
- (NSString *)cz_systemVersion { return spoofedSystemVersion(); }
- (NSString *)cz_name { return spoofedModelName(); }
- (NSString *)cz_localizedModel { return @"iPhone"; }
@end

// Garde anti-recursion : ContainerManager.init appelle NSSearchPathForDirectoriesInDomains
// qui rappelle sysctlbyname/uname. Sans garde -> re-entree dans dispatch_once -> deadlock au lancement.
static int gSpoofDepth = 0;
static int (*cz_orig_uname)(struct utsname *) = NULL;
static int (*cz_orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t) = NULL;

static int cz_uname(struct utsname *name) {
    if (gSpoofDepth > 0) {
        if (!cz_orig_uname) cz_orig_uname = (int (*)(struct utsname *))dlsym(RTLD_NEXT, "uname");
        if (cz_orig_uname) return cz_orig_uname(name);
        return -1;
    }
    if (!name) return -1;
    gSpoofDepth++;
    bzero(name, sizeof(*name));
    strncpy(name->sysname,    "Darwin",   sizeof(name->sysname)   - 1);
    strncpy(name->nodename,   "iPhone",   sizeof(name->nodename)  - 1);
    strncpy(name->release,    [spoofedSystemVersion() UTF8String], sizeof(name->release) - 1);
    strncpy(name->version,    "Darwin Kernel Version 26.6.1: Rooted", sizeof(name->version) - 1);
    strncpy(name->machine,    [spoofedModelIdentifier() UTF8String], sizeof(name->machine) - 1);
    gSpoofDepth--;
    return 0;
}

DYLD_INTERPOSE(cz_uname, uname);

// Spoof aussi sysctl hw.machine / hw.model (Instagram les lit souvent directement).
static int cz_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (gSpoofDepth == 0) {
        gSpoofDepth++;
        const char *s = NULL;
        if (name && oldp) {
            if (strcmp(name, "hw.machine") == 0) s = [spoofedModelIdentifier() UTF8String] ?: "iPhone15,4";
            else if (strcmp(name, "hw.model") == 0) s = [spoofedModelName() UTF8String] ?: "iPhone";
        }
        if (s) {
            size_t need = strlen(s) + 1;
            size_t cap = oldlenp ? *oldlenp : 0;
            if (cap > 0) memcpy(oldp, s, need < cap ? need : cap);
            if (oldlenp) *oldlenp = need;
            gSpoofDepth--;
            return 0;
        }
        gSpoofDepth--; // pas de spoof pour ce nom -> original
    }
    if (!cz_orig_sysctlbyname) {
        cz_orig_sysctlbyname = (int (*)(const char *, void *, size_t *, void *, size_t))
            dlsym(RTLD_NEXT, "sysctlbyname");
    }
    if (cz_orig_sysctlbyname) return cz_orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    return -1;
}

DYLD_INTERPOSE(cz_sysctlbyname, sysctlbyname);

@implementation DeviceProfile
+ (void)applyHooks {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = [UIDevice class];
        SEL orig[] = {@selector(model), @selector(systemVersion), @selector(name), @selector(localizedModel)};
        SEL repl[] = {@selector(cz_model), @selector(cz_systemVersion), @selector(cz_name), @selector(cz_localizedModel)};
        for (int i = 0; i < 4; i++) {
            Method m = class_getInstanceMethod(cls, orig[i]);
            if (m) method_exchangeImplementations(m, class_getInstanceMethod(cls, repl[i]));
        }
        [[TweakLogger shared] log:@"DeviceProfile: hooks UIDevice + uname appliqués."];
    });
}
@end
