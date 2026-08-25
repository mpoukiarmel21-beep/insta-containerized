//
//  DeviceProfile.h
//  Containerizer (Instagram tweak)
//  Spoof userland du profil device PAR CONTENEUR actif.
//  - UIDevice (model, systemVersion, name, localizedModel) via swizzle
//  - uname() via DYLD_INTERPOSE (machine = identifiant du conteneur)
//  Note (voir docs/LIMITES.md) : spoof userland, pas attestation matérielle.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DeviceProfile : NSObject
+ (void)applyHooks;
@end
