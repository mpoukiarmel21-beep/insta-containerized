//
//  Tweak.m
//  Containerizer (Instagram tweak)
//  Point d'entrée. Installe les hooks UNIQUEMENT après le lancement de l'app
//  (jamais dans +load) pour éviter les crashs au démarrage.
//

#import <UIKit/UIKit.h>
#import "ContainerManager.h"
#import "DeviceProfile.h"
#import "LocationSpoofer.h"
#import "FloatingButton.h"
#import "TweakLogger.h"

__attribute__((constructor)) static void tweak_init(void) {
    [[TweakLogger shared] log:@"Containerizer: chargement de la dylib."];
    [TweakLogger installCrashReporter];

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
        [DeviceProfile applyHooks];
        [LocationSpoofer applyHooks];
        [[FloatingButton shared] show];
        [[TweakLogger shared] log:@"Containerizer: hooks + UI prêts (après launch)."];
    }];

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidBecomeActiveNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
        [[FloatingButton shared] show];
    }];
}
