//
//  DeviceProfile.m
//  Containerizer (Instagram tweak)
//
//  Spoof device : UIDevice (swizzle) + uname (DYLD_INTERPOSE).
//  STRATEGIE ANTI-CRASH : le cache des valeurs spoofees est rempli UNE SEULE FOIS,
//  au lancement, sur le thread principal, AVANT que les hooks ne servent quoi que
//  ce soit (cf. applyHooks). Ensuite cz_uname ne fait AUCUN appel ObjC : il copie
//  des buffers C. Les appels tres tot au demarrage (avant remplissage) ou pendant
//  le remplissage recoivent le VRAI uname -> aucun deadlock possible, aucun crash
//  sur les threads camera/ML d'arriere-plan pendant la creation de contenu.
//

#import "DeviceProfile.h"
#import "ContainerManager.h"
#import "TweakLogger.h"
#import <sys/utsname.h>
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

#pragma mark - Cache des valeurs spoofees (rempli une fois, au lancement)

static NSString *gSpoofModelName = nil;
static NSString *gSpoofModelId   = nil;
static NSString *gSpoofIOS       = nil;
static char      gUMachine[256];
static char      gURelease[256];
static char      gUVersion[256];
static volatile BOOL gSpoofCached = NO;
static int       gSpoofDepth = 0; // protege le remplissage contre la re-entree
static int       (*cz_orig_uname)(struct utsname *) = NULL;

static void ensureOriginalUname(void) {
    if (!cz_orig_uname) cz_orig_uname = (int (*)(struct utsname *))dlsym(RTLD_NEXT, "uname");
}

static int originalUname(struct utsname *name) {
    ensureOriginalUname();
    return cz_orig_uname ? cz_orig_uname(name) : -1;
}

// Appele UNIQUEMENT depuis applyHooks (thread principal, apres launch).
static void fillSpoofCache(void) {
    if (gSpoofCached) return;
    gSpoofDepth++;
    Container *c = [[ContainerManager shared] activeContainer]; // force l'init une bonne fois
    gSpoofModelName = [(c.modelName.length       ? c.modelName       : @"iPhone 15 Pro") retain];
    gSpoofModelId   = [(c.modelIdentifier.length ? c.modelIdentifier : @"iPhone15,4")     retain];
    gSpoofIOS       = [(c.iosVersion.length      ? c.iosVersion      : @"26.6.1")         retain];
    const char *m = gSpoofModelId.UTF8String ?: "iPhone15,4";
    const char *r = gSpoofIOS.UTF8String     ?: "26.6.1";
    memset(gUMachine, 0, sizeof(gUMachine));
    memset(gURelease, 0, sizeof(gURelease));
    memset(gUVersion, 0, sizeof(gUVersion));
    strncpy(gUMachine, m, sizeof(gUMachine) - 1);
    strncpy(gURelease, r, sizeof(gURelease) - 1);
    strncpy(gUVersion, "Darwin Kernel Version 26.6.1: Rooted", sizeof(gUVersion) - 1);
    gSpoofDepth--;
    gSpoofCached = YES; // DERNIER : un uname appele avant ce point recoit le vrai
}

// Lecture seule, sans effet de bord : sur n'importe quel thread apres le lancement,
// ces accesseurs ne font que retourner des NSString deja retenus (immuables).
static NSString *spoofedModelIdentifier(void) { return gSpoofModelId   ?: @"iPhone15,4"; }
static NSString *spoofedSystemVersion(void)   { return gSpoofIOS       ?: @"26.6.1"; }
static NSString *spoofedModelName(void)       { return gSpoofModelName ?: @"iPhone 15 Pro"; }

#pragma mark - Swizzle UIDevice

@interface UIDevice (Containerizer)
@end

@implementation UIDevice (Containerizer)
- (NSString *)cz_model { return spoofedModelName(); }
- (NSString *)cz_systemVersion { return spoofedSystemVersion(); }
- (NSString *)cz_name { return spoofedModelName(); }
- (NSString *)cz_localizedModel { return @"iPhone"; }
@end

#pragma mark - Interpose uname (100% C, zero ObjC)

static int cz_uname(struct utsname *name) {
    if (gSpoofCached && gSpoofDepth == 0 && name) {
        bzero(name, sizeof(*name));
        strncpy(name->sysname,  "Darwin",  sizeof(name->sysname)  - 1);
        strncpy(name->nodename, "iPhone",  sizeof(name->nodename) - 1);
        strncpy(name->release,  gURelease, sizeof(name->release)  - 1);
        strncpy(name->version,  gUVersion, sizeof(name->version)  - 1);
        strncpy(name->machine,  gUMachine, sizeof(name->machine)  - 1);
        return 0;
    }
    // tres tot au demarrage (cache pas pret) ou pendant le remplissage : vrai uname
    return originalUname(name);
}

DYLD_INTERPOSE(cz_uname, uname);

#pragma mark - Installation

@implementation DeviceProfile
+ (void)applyHooks {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // 1) Initialiser ContainerManager et remplir le cache MAINTENANT :
        //    thread principal, apres launch, avant que quiconque n'appelle uname/UIDevice.
        fillSpoofCache();

        // 2) Swizzles UIDevice.
        Class cls = [UIDevice class];
        SEL orig[] = {@selector(model), @selector(systemVersion), @selector(name), @selector(localizedModel)};
        SEL repl[] = {@selector(cz_model), @selector(cz_systemVersion), @selector(cz_name), @selector(cz_localizedModel)};
        for (int i = 0; i < 4; i++) {
            Method m = class_getInstanceMethod(cls, orig[i]);
            if (m) method_exchangeImplementations(m, class_getInstanceMethod(cls, repl[i]));
        }
        [[TweakLogger shared] log:@"DeviceProfile: cache rempli (%@ / %@), hooks UIDevice + uname actifs.",
            gSpoofModelId, gSpoofIOS];
    });
}
@end
