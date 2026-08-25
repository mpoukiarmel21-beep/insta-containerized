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

// Cache des valeurs spoofees : calcule UNE FOIS sur le thread principal (ObjC + lecture
// fichier), puis reutilise des C strings / NSString caches. Aucun ObjC hors thread
// principal -> elimine le crash pendant la creation de contenu (camera/ML appellent
// uname sur des threads d'arriere-plan).
static NSString *gSpoofModelName = nil;
static NSString *gSpoofModelId   = nil;
static NSString *gSpoofIOS       = nil;
static char      gUMachine[256];
static char      gURelease[256];
static char      gUVersion[256];
static BOOL      gSpoofCached = NO;
static int       gSpoofDepth = 0;
static int       (*cz_orig_uname)(struct utsname *) = NULL;

static void ensureSpoofCache(void) {
    if (gSpoofCached) return;
    if (![NSThread isMainThread]) return; // jamais d'ObjC hors thread principal
    gSpoofDepth++; // protege contre la re-entree pendant ContainerManager.init
    Container *c = [[ContainerManager shared] activeContainer];
    gSpoofDepth--;
    gSpoofModelName = [c.modelName.length       ? c.modelName       : @"iPhone 15 Pro" retain];
    gSpoofModelId   = [c.modelIdentifier.length ? c.modelIdentifier : @"iPhone15,4"     retain];
    gSpoofIOS       = [c.iosVersion.length      ? c.iosVersion      : @"26.6.1"         retain];
    const char *m = gSpoofModelId.UTF8String   ?: "iPhone15,4";
    const char *r = gSpoofIOS.UTF8String       ?: "26.6.1";
    strncpy(gUMachine, m, sizeof(gUMachine) - 1);
    strncpy(gURelease, r, sizeof(gURelease) - 1);
    strncpy(gUVersion, "Darwin Kernel Version 26.6.1: Rooted", sizeof(gUVersion) - 1);
    gSpoofCached = YES;
}

static NSString *spoofedModelIdentifier(void) {
    ensureSpoofCache();
    return gSpoofModelId ?: @"iPhone15,4";
}
static NSString *spoofedSystemVersion(void) {
    ensureSpoofCache();
    return gSpoofIOS ?: @"26.6.1";
}
static NSString *spoofedModelName(void) {
    ensureSpoofCache();
    return gSpoofModelName ?: @"iPhone 15 Pro";
}

@interface UIDevice (Containerizer)
@end

@implementation UIDevice (Containerizer)
- (NSString *)cz_model { return spoofedModelName(); }
- (NSString *)cz_systemVersion { return spoofedSystemVersion(); }
- (NSString *)cz_name { return spoofedModelName(); }
- (NSString *)cz_localizedModel { return @"iPhone"; }
@end

static int cz_uname(struct utsname *name) {
    if (gSpoofDepth > 0) { // re-entrant (pendant init ContainerManager) -> original
        if (!cz_orig_uname) cz_orig_uname = (int (*)(struct utsname *))dlsym(RTLD_NEXT, "uname");
        return cz_orig_uname ? cz_orig_uname(name) : -1;
    }
    if (!name) return -1;
    if ([NSThread isMainThread]) {
        gSpoofDepth++;
        ensureSpoofCache();
        gSpoofDepth--;
        bzero(name, sizeof(*name));
        strncpy(name->sysname,  "Darwin",  sizeof(name->sysname)  - 1);
        strncpy(name->nodename, "iPhone",  sizeof(name->nodename) - 1);
        strncpy(name->release,  gURelease, sizeof(name->release)  - 1);
        strncpy(name->version,  gUVersion, sizeof(name->version)  - 1);
        strncpy(name->machine,  gUMachine, sizeof(name->machine)  - 1);
        return 0;
    }
    // thread d'arriere-plan : pas d'ObjC, on renvoie le vrai uname
    if (!cz_orig_uname) cz_orig_uname = (int (*)(struct utsname *))dlsym(RTLD_NEXT, "uname");
    return cz_orig_uname ? cz_orig_uname(name) : -1;
}

DYLD_INTERPOSE(cz_uname, uname);

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
