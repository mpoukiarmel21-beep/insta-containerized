//
//  LocationSpoofer.h
//  Containerizer (Instagram tweak)
//  Faux GPS PAR CONTENEUR via swizzle de CLLocationManager.
//  UI carte : recherche (MKLocalSearch), zoom, bouton Activer/Désactiver.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@interface LocationSpoofer : NSObject
+ (void)applyHooks;
+ (void)presentPickerFrom:(UIViewController *)vc;
+ (CLLocation *)currentSpoofedLocation;
+ (void)invalidateCachedLocation;
@end

@interface LocationPickerViewController : UIViewController
@end
