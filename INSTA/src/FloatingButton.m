//
//  FloatingButton.m
//  Tweak
//
//  Bouton flottant draggable + menu de conteneurs (device/GPS/comptes).
//  MRC (-fno-objc-arc). Le bouton est re-epinglé en permanence sur la fenetre
//  la plus haute (timer + notifications) pour qu'Instagram ne puisse pas le
//  faire disparaitre. Design : FAB degrade + carte glassy floutee (spring).
//

#import "FloatingButton.h"
#import "ContainerManager.h"
#import "DeviceProfile.h"
#import "LocationSpoofer.h"
#import "TweakLogger.h"
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>

#define TWEAK_LOG(fmt, ...) [[TweakLogger shared] log:[NSString stringWithUTF8String:fmt], ##__VA_ARGS__]

static UIButton *gButton = nil;
static UIView   *gMenu   = nil;
static BOOL      gLoaded = NO;
static BOOL      gMenuVisible = NO;
static Container *gCurrentContainer = nil;

static UIViewController *topController(void) {
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    UIViewController *r = kw.rootViewController;
    while (r && r.presentedViewController) r = r.presentedViewController;
    return r;
}

@interface FloatingButton ()
- (void)buildButton;
- (void)buildMenuIfNeeded;
- (void)pin;
- (UIWindow *)topWindow;
- (void)btnTapped:(id)sender;
- (void)btnTouchDown:(id)sender;
- (void)btnTouchUp:(id)sender;
- (void)panHandler:(UIPanGestureRecognizer *)g;
- (void)showMenu;
- (void)hideMenu;
- (void)addRowInMenu:(UIView *)menu y:(CGFloat *)y icon:(NSString *)icon title:(NSString *)title action:(SEL)action;
- (void)rowHighlightOn:(UIButton *)b;
- (void)rowHighlightOff:(UIButton *)b;
- (void)switchContainerAction:(UIAlertAction *)a;
- (void)contMenu;
- (void)accountsMenu;
- (void)savedAccountsMenu;
- (void)addAccount;
- (void)delAccount;
- (void)accountPicked:(UIAlertAction *)a;
- (void)fakeGPSAction;
- (void)resetAction;
- (void)logsAction;
@end

@implementation FloatingButton

+ (instancetype)shared {
    static FloatingButton *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ inst = [[FloatingButton alloc] init]; });
    return inst;
}

- (void)dealloc {
    [gButton release];
    [gMenu release];
    [gCurrentContainer release];
    [super dealloc];
}

#pragma mark - Visibilite / re-epingle

- (void)show {
    if (gLoaded) { [self pin]; return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self buildButton];
        [self buildMenuIfNeeded];
        gLoaded = YES;
        [self pin];
        [NSTimer scheduledTimerWithTimeInterval:0.6
                                         target:self
                                       selector:@selector(pin)
                                       userInfo:nil
                                        repeats:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pin)
                                                     name:UIWindowDidBecomeKeyNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pin)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(hideMenu)
                                                     name:@"CZContainerizerRestoreOverlay"
                                                   object:nil];
    });
}

- (UIWindow *)topWindow {
    UIWindow *top = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!top || w.windowLevel > top.windowLevel) top = w;
    }
    if (!top) top = [UIApplication sharedApplication].keyWindow;
    if (!top) top = [UIApplication sharedApplication].windows.firstObject;
    return top;
}

- (void)pin {
    UIWindow *top = [self topWindow];
    if (!top) return;
    if (gButton.superview != top) [top addSubview:gButton];
    [top bringSubviewToFront:gButton];
    if (gMenuVisible) {
        if (gMenu.superview != top) [top addSubview:gMenu];
        [top bringSubviewToFront:gMenu];
    }
}

#pragma mark - Construction du bouton (FAB)

- (void)buildButton {
    if (gButton) return;
    CGFloat size = 56;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect sb = [UIScreen mainScreen].bounds;
    b.frame = CGRectMake(sb.size.width - size - 24, sb.size.height - size - 120, size, size);
    b.layer.cornerRadius = size / 2.0;
    b.layer.masksToBounds = NO;
    b.layer.shadowColor = [UIColor blackColor].CGColor;
    b.layer.shadowOpacity = 0.38;
    b.layer.shadowRadius = 10;
    b.layer.shadowOffset = CGSizeMake(0, 5);

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = CGRectMake(0, 0, size, size);
    grad.cornerRadius = size / 2.0;
    grad.colors = @[ (__bridge id)[UIColor colorWithRed:0.42 green:0.21 blue:0.88 alpha:1].CGColor,
                     (__bridge id)[UIColor colorWithRed:0.93 green:0.17 blue:0.55 alpha:1].CGColor ];
    grad.startPoint = CGPointMake(0.15, 0.15);
    grad.endPoint   = CGPointMake(0.85, 0.85);
    [b.layer addSublayer:grad];

    UILabel *glyph = [[UILabel alloc] initWithFrame:b.bounds];
    glyph.text = @"⚙︎";
    glyph.textAlignment = NSTextAlignmentCenter;
    glyph.textColor = [UIColor whiteColor];
    glyph.font = [UIFont systemFontOfSize:27];
    [b addSubview:glyph];
    [glyph release];

    [b addTarget:self action:@selector(btnTouchDown:) forControlEvents:UIControlEventTouchDown];
    [b addTarget:self action:@selector(btnTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [b addTarget:self action:@selector(btnTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panHandler:)];
    [b addGestureRecognizer:pan];
    [pan release];

    gButton = [b retain];
}

- (void)btnTouchDown:(id)sender {
    [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        gButton.transform = CGAffineTransformMakeScale(0.90, 0.90);
    } completion:nil];
}
- (void)btnTouchUp:(id)sender {
    [UIView animateWithDuration:0.18 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.6 options:0 animations:^{
        gButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)panHandler:(UIPanGestureRecognizer *)g {
    if (!gButton) return;
    if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [g translationInView:gButton.superview];
        CGPoint c = gButton.center;
        c.x += t.x; c.y += t.y;
        gButton.center = c;
        [g setTranslation:CGPointZero inView:gButton.superview];
    } else if (g.state == UIGestureRecognizerStateEnded) {
        [self pin];
    }
}

#pragma mark - Menu (carte glassy)

- (void)buildMenuIfNeeded {
    if (gMenu) return;
    gMenu = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 290, 360)];
    gMenu.clipsToBounds = YES;
    gMenu.layer.cornerRadius = 20;
    gMenu.layer.masksToBounds = YES;
    gMenu.layer.shadowColor = [UIColor blackColor].CGColor;
    gMenu.layer.shadowOpacity = 0.45;
    gMenu.layer.shadowRadius = 18;
    gMenu.layer.shadowOffset = CGSizeMake(0, 10);

    UIVisualEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *ve = [[UIVisualEffectView alloc] initWithEffect:blur];
    ve.frame = gMenu.bounds;
    ve.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [gMenu addSubview:ve];
    [ve release];

    if (!gCurrentContainer) gCurrentContainer = [[[ContainerManager shared] activeContainer] retain];
}

- (void)addRowInMenu:(UIView *)menu y:(CGFloat *)y icon:(NSString *)icon title:(NSString *)title action:(SEL)action {
    CGFloat rowH = 48;
    UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
    row.frame = CGRectMake(8, *y, menu.bounds.size.width - 16, rowH);
    row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    row.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    row.layer.cornerRadius = 12;
    row.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [row setTitle:[NSString stringWithFormat:@"%@  %@", icon, title] forState:UIControlStateNormal];
    [row setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [row addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addTarget:self action:@selector(rowHighlightOn:) forControlEvents:UIControlEventTouchDown];
    [row addTarget:self action:@selector(rowHighlightOff:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [menu addSubview:row];

    *y += rowH + 6;
}

- (void)rowHighlightOn:(UIButton *)b { b.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14]; }
- (void)rowHighlightOff:(UIButton *)b { b.backgroundColor = [UIColor clearColor]; }

- (void)btnTapped:(id)sender {
    [self btnTouchUp:sender];
    if (gMenuVisible) { [self hideMenu]; return; }
    [self buildMenuIfNeeded];
    [self showMenu];
}

- (void)showMenu {
    if (!gCurrentContainer) gCurrentContainer = [[[ContainerManager shared] activeContainer] retain];
    [[gMenu subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [gMenu addSubview:[[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]] autorelease]];

    CGFloat y = 14;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, y, gMenu.bounds.size.width - 32, 22)];
    title.text = [NSString stringWithFormat:@"Conteneur : %@", gCurrentContainer.name];
    title.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    title.font = [UIFont boldSystemFontOfSize:14];
    [gMenu addSubview:title];
    [title release];
    y += 30;

    [self addRowInMenu:gMenu y:&y icon:@"📦" title:@"Changer de conteneur"  action:@selector(contMenu)];
    [self addRowInMenu:gMenu y:&y icon:@"👥" title:@"Comptes du conteneur"  action:@selector(accountsMenu)];
    [self addRowInMenu:gMenu y:&y icon:@"📍" title:@"GPS truqué (carte)"    action:@selector(fakeGPSAction)];
    [self addRowInMenu:gMenu y:&y icon:@"♻︎" title:@"Reset profil device"    action:@selector(resetAction)];
    [self addRowInMenu:gMenu y:&y icon:@"📜" title:@"Journal / Logs"        action:@selector(logsAction)];
    [self addRowInMenu:gMenu y:&y icon:@"✕" title:@"Fermer"                 action:@selector(hideMenu)];

    UIWindow *w = [self topWindow];
    CGRect sr = w.bounds;
    gMenu.frame = CGRectMake(sr.size.width - 290 - 16, 70, 290, y + 8);

    gMenuVisible = YES;
    gMenu.alpha = 0;
    gMenu.transform = CGAffineTransformMakeScale(0.92, 0.92);
    if (gMenu.superview != w) [w addSubview:gMenu];
    [w bringSubviewToFront:gMenu];
    [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.7
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        gMenu.alpha = 1;
        gMenu.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hideMenu {
    if (!gMenuVisible) return;
    gMenuVisible = NO;
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        gMenu.alpha = 0;
        gMenu.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL done){ [gMenu removeFromSuperview]; gMenu.transform = CGAffineTransformIdentity; }];
}

#pragma mark - Actions conteneurs

- (void)switchContainerAction:(UIAlertAction *)a {
    NSString *name = a.title;
    for (Container *c in [[ContainerManager shared] allContainers]) {
        if ([c.name isEqualToString:name]) { [[ContainerManager shared] setActiveContainer:c]; break; }
    }
    [gCurrentContainer release];
    gCurrentContainer = [[[ContainerManager shared] activeContainer] retain];
    [self hideMenu];
}

- (void)contMenu {
    [self hideMenu];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Conteneurs"
                                                               message:@"Choisis le conteneur actif"
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    for (Container *c in [[ContainerManager shared] allContainers]) {
        [ac addAction:[UIAlertAction actionWithTitle:c.name style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *a){ [self switchContainerAction:a]; }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [topController() presentViewController:ac animated:YES completion:nil];
}

- (void)accountsMenu {
    [self hideMenu];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Comptes"
                                                               message:nil
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:@"👥 Comptes sauvegardés" style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a){ [self savedAccountsMenu]; }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"➕ Ajouter le compte courant" style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a){ [self addAccount]; }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"➖ Supprimer un compte" style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a){ [self delAccount]; }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [topController() presentViewController:ac animated:YES completion:nil];
}

- (void)savedAccountsMenu {
    NSArray *accs = [[ContainerManager shared] accountSessionsForContainer:[[ContainerManager shared] activeContainer]];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Comptes sauvegardés"
                                                               message:@"Sélectionne un compte à (ré)injecter"
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *s in accs) {
        NSString *u = s[@"username"] ?: @"(sans nom)";
        [ac addAction:[UIAlertAction actionWithTitle:u style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *a){ [self accountPicked:a]; }]];
    }
    if (accs.count == 0) ac.message = @"(aucun compte sauvegardé dans ce conteneur)";
    [ac addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [topController() presentViewController:ac animated:YES completion:nil];
}

- (void)addAccount {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Ajouter un compte"
                                                               message:@"Identifiant du compte courant à sauvegarder"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"ex: mon.pseudo"; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Sauver" style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *a){
        NSString *v = ac.textFields.firstObject.text;
        if (v.length) [[ContainerManager shared] saveAccountSession:@{@"username": v}
                                                       forContainer:[[ContainerManager shared] activeContainer]];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [topController() presentViewController:ac animated:YES completion:nil];
}

- (void)delAccount {
    NSArray *accs = [[ContainerManager shared] accountSessionsForContainer:[[ContainerManager shared] activeContainer]];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Supprimer un compte"
                                                               message:nil
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *s in accs) {
        NSString *u = s[@"username"] ?: @"(sans nom)";
        [ac addAction:[UIAlertAction actionWithTitle:u style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *a){
            [[ContainerManager shared] removeAccountSession:s forContainer:[[ContainerManager shared] activeContainer]];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
    [topController() presentViewController:ac animated:YES completion:nil];
}

- (void)accountPicked:(UIAlertAction *)a {
    TWEAK_LOG("Compte choisi pour le conteneur %s : %s",
              [gCurrentContainer.name UTF8String], [a.title UTF8String]);
    [self hideMenu];
}

#pragma mark - GPS / Reset / Logs

- (void)fakeGPSAction {
    [self hideMenu];
    [LocationSpoofer presentPickerFrom:topController()];
}

- (void)resetAction {
    [self hideMenu];
    Container *c = [[ContainerManager shared] activeContainer];
    c.locationEnabled = NO;
    [[ContainerManager shared] updateContainer:c];
    [[ContainerManager shared] randomizeProfileForActiveContainer];
    TWEAK_LOG("Reset profil device + GPS pour conteneur %s", [c.name UTF8String]);
}

- (void)logsAction {
    [self hideMenu];
    NSString *log = [TweakLogger recentLog];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Journal"
                                                               message:log ?: @"(vide)"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [topController() presentViewController:ac animated:YES completion:nil];
}

@end
