//
//  DeviceProfile.m
//  Containerizer (Instagram tweak)
//

#import "DeviceProfile.h"
#import "ContainerManager.h"
#import "TweakLogger.h"
#import <sys/utsname.h>
#import <objc/runtime.h>
#import <mach-o/dyld_interpose.h>

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

static int cz_uname(struct utsname *name) {
    if (!name) return -1;
    bzero(name, sizeof(*name));
    strncpy(name->sysname,    "Darwin",   sizeof(name->sysname)   - 1);
    strncpy(name->nodename,   "iPhone",   sizeof(name->nodename)  - 1);
    strncpy(name->release,    [spoofedSystemVersion() UTF8String], sizeof(name->release) - 1);
    strncpy(name->version,    "Darwin Kernel Version 26.6.1: Rooted", sizeof(name->version) - 1);
    strncpy(name->machine,    [spoofedModelIdentifier() UTF8String], sizeof(name->machine) - 1);
    return 0;
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
