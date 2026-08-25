//
//  LocationSpoofer.m
//  Containerizer (Instagram tweak)
//

#import "LocationSpoofer.h"
#import "ContainerManager.h"
#import "TweakLogger.h"
#import <objc/runtime.h>
#import <MapKit/MapKit.h>

@implementation LocationSpoofer

static CLLocation *gCachedLoc = nil;

+ (CLLocation *)currentSpoofedLocation {
    Container *c = [[ContainerManager shared] activeContainer];
    if (!c || !c.locationEnabled) return nil;
    if (!gCachedLoc) {
        gCachedLoc = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(c.latitude, c.longitude)
                                                   altitude:0
                                         horizontalAccuracy:5
                                           verticalAccuracy:5
                                                     course:-1
                                                      speed:-1
                                                  timestamp:[NSDate date]];
    }
    return gCachedLoc;
}

// Invalide le cache apres activation/desactivation/deplacement dans le picker.
+ (void)invalidateCachedLocation {
    [gCachedLoc release];
    gCachedLoc = nil;
}

+ (void)applyHooks {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SEL orig = @selector(location);
        SEL repl = @selector(cz_location);
        Method m = class_getInstanceMethod([CLLocationManager class], orig);
        if (m) method_exchangeImplementations(m, class_getInstanceMethod([CLLocationManager class], repl));
        SEL so = @selector(setDelegate:);
        SEL sr = @selector(cz_setDelegate:);
        Method md = class_getInstanceMethod([CLLocationManager class], so);
        if (md) method_exchangeImplementations(md, class_getInstanceMethod([CLLocationManager class], sr));
        [[TweakLogger shared] log:@"LocationSpoofer: hooks CLLocationManager appliqués."];
    });
}

+ (void)presentPickerFrom:(UIViewController *)vc {
    LocationPickerViewController *p = [[LocationPickerViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:p];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [vc presentViewController:nav animated:YES completion:nil];
}

@end

@interface CLLocationManager (Containerizer)
- (CLLocation *)cz_location;
- (void)cz_setDelegate:(id<CLLocationManagerDelegate>)delegate;
@end

@implementation CLLocationManager (Containerizer)

- (CLLocation *)cz_location {
    CLLocation *sp = [LocationSpoofer currentSpoofedLocation];
    if (sp) return sp;
    return [self cz_location];
}

- (void)cz_setDelegate:(id<CLLocationManagerDelegate>)delegate {
    [self cz_setDelegate:delegate];
    if (!delegate) return;
    // Les DEUX callbacks : le moderne ET le deprecie. Si l'app n'implemente que
    // l'ancien (cas frequent), sans ce swizzle la position truquee n'arrive jamais.
    [LocationSpoofer swizzleDelegateCallback:[delegate class] sel:@selector(locationManager:didUpdateLocations:)];
    [LocationSpoofer swizzleDelegateCallback:[delegate class] sel:@selector(locationManager:didUpdateToLocation:fromLocation:)];
}

@end

@implementation LocationSpoofer (Delegate)

+ (void)swizzleDelegateCallback:(Class)dcls sel:(SEL)sel {
    BOOL isModern = (sel == @selector(locationManager:didUpdateLocations:));
    BOOL isLegacy = (sel == @selector(locationManager:didUpdateToLocation:fromLocation:));
    if (!isModern && !isLegacy) return;
    if (!class_respondsToSelector(dcls, sel)) return;
    if (objc_getAssociatedObject(dcls, sel)) return;
    Method m = class_getInstanceMethod(dcls, sel);
    if (!m) return;

    IMP old = method_getImplementation(m);
    IMP repl;
    if (isModern) {
        repl = imp_implementationWithBlock(^(id del, CLLocationManager *mgr, NSArray *locs) {
            CLLocation *sp = [LocationSpoofer currentSpoofedLocation];
            NSArray *use = locs;
            if (sp && locs.count > 0) use = @[sp];
            void (*o)(id, SEL, id, NSArray *) = (void (*)(id, SEL, id, NSArray *))old;
            o(del, sel, mgr, use);
        });
    } else {
        repl = imp_implementationWithBlock(^(id del, CLLocationManager *mgr, CLLocation *newL, CLLocation *oldL) {
            CLLocation *sp = [LocationSpoofer currentSpoofedLocation];
            void (*o)(id, SEL, id, id, id) = (void (*)(id, SEL, id, id, id))old;
            o(del, sel, mgr, sp ?: newL, oldL);
        });
    }
    method_setImplementation(m, repl);
    objc_setAssociatedObject(dcls, sel, @(1), OBJC_ASSOCIATION_RETAIN);
    [[TweakLogger shared] log:@"LocationSpoofer: delegate %@ branche (%@).",
        NSStringFromClass(dcls), isModern ? @"didUpdateLocations" : @"didUpdateToLocation"];
}

@end

@interface LocationPickerViewController () <MKMapViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) MKMapView *map;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, assign) CLLocationCoordinate2D picked;
@end

@implementation LocationPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Faux GPS (conteneur)";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    Container *c = [[ContainerManager shared] activeContainer];
    self.picked = CLLocationCoordinate2DMake(c.latitude, c.longitude);

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    _searchBar.placeholder = @"Rechercher une ville (ex: Paris)";
    _searchBar.delegate = self;
    [self.view addSubview:_searchBar];

    _map = [[MKMapView alloc] initWithFrame:CGRectMake(0, 44, self.view.bounds.size.width, self.view.bounds.size.height - 44 - 120)];
    _map.delegate = self;
    [self.view addSubview:_map];

    [self centerOn:self.picked animated:NO];

    UIButton *activer = [UIButton buttonWithType:UIButtonTypeSystem];
    [activer setTitle:@"Activer la position" forState:UIControlStateNormal];
    activer.backgroundColor = [UIColor systemGreenColor];
    [activer setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    activer.frame = CGRectMake(16, self.view.bounds.size.height - 110, self.view.bounds.size.width - 32, 44);
    [activer addTarget:self action:@selector(activate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:activer];

    UIButton *desactiver = [UIButton buttonWithType:UIButtonTypeSystem];
    [desactiver setTitle:@"Désactiver" forState:UIControlStateNormal];
    desactiver.frame = CGRectMake(16, self.view.bounds.size.height - 60, self.view.bounds.size.width - 32, 44);
    [desactiver addTarget:self action:@selector(deactivate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:desactiver];
}

- (void)centerOn:(CLLocationCoordinate2D)coord animated:(BOOL)animated {
    MKCoordinateRegion r = MKCoordinateRegionMakeWithDistance(coord, 2000, 2000);
    [_map setRegion:r animated:animated];
    [_map removeAnnotations:_map.annotations];
    MKPointAnnotation *a = [[MKPointAnnotation alloc] init];
    a.coordinate = coord;
    a.title = @"Position spoofée";
    [_map addAnnotation:a];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    MKLocalSearchRequest *req = [[MKLocalSearchRequest alloc] init];
    req.naturalLanguageQuery = searchBar.text;
    req.region = _map.region;
    MKLocalSearch *s = [[MKLocalSearch alloc] initWithRequest:req];
    [s startWithCompletionHandler:^(MKLocalSearchResponse *resp, NSError *err) {
        if (resp.mapItems.count) {
            MKMapItem *item = resp.mapItems.firstObject;
            self.picked = item.placemark.coordinate;
            [self centerOn:self.picked animated:YES];
            [[TweakLogger shared] log:@"Recherche GPS: %@ -> %f,%f", searchBar.text, self.picked.latitude, self.picked.longitude];
        } else {
            [[TweakLogger shared] logError:@"Recherche GPS sans résultat: %@", searchBar.text];
        }
    }];
}

- (void)activate {
    Container *c = [[ContainerManager shared] activeContainer];
    c.latitude = self.picked.latitude;
    c.longitude = self.picked.longitude;
    c.locationEnabled = YES;
    [[ContainerManager shared] updateContainer:c];
    [LocationSpoofer invalidateCachedLocation];
    [[TweakLogger shared] log:@"Faux GPS activé pour %@ : %f,%f", c.name, c.latitude, c.longitude];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CZContainerizerRestoreOverlay" object:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)deactivate {
    Container *c = [[ContainerManager shared] activeContainer];
    c.locationEnabled = NO;
    [[ContainerManager shared] updateContainer:c];
    [LocationSpoofer invalidateCachedLocation];
    [[TweakLogger shared] log:@"Faux GPS désactivé pour %@", c.name];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CZContainerizerRestoreOverlay" object:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
