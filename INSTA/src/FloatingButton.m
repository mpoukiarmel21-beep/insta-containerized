//
//  FloatingButton.m
//  Tweak
//
//  Bouton flottant draggable + menu de conteneurs (device/GPS/comptes).
//  MRC (-fno-objc-arc) : on retient gButton/gMenu et on les re-parent sur la
//  keyWindow courante quand Instagram change de fenetre (evite disparition + crash au tap).
//

#import "FloatingButton.h"
#import "ContainerManager.h"
#import "DeviceProfile.h"
#import "LocationSpoofer.h"
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

#define TWEAK_LOG(fmt, ...) [[TweakLogger shared] log:[NSString stringWithUTF8String:fmt], ##__VA_ARGS__]

static UIButton *gButton = nil;
static UIView   *gMenu   = nil;
static BOOL      gLoaded = NO;
static Container *gCurrentContainer = nil;

static UIViewController *topController(void) {
    UIWindow *kw = [UIApplication sharedApplication].keyWindow;
    UIViewController *r = kw.rootViewController;
    while (r && r.presentedViewController) r = r.presentedViewController;
    return r;
}

@interface FloatingButton ()
- (void)buildButton;
- (void)reparent;
- (void)btnTapped:(id)sender;
- (void)panHandler:(UIPanGestureRecognizer *)g;
- (void)showMenu;
- (void)hideMenu;
- (void)menuBackgroundTapped;
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
- (UIFont *)fa;
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

#pragma mark - Visibilite / reparent

- (void)reparent {
    UIWindow *w = [UIApplication sharedApplication].keyWindow;
    if (!w) w = [UIApplication sharedApplication].windows.firstObject;
    if (w && gButton && gButton.superview != w) [w addSubview:gButton];
    if (w && gMenu   && gMenu.superview   != w) [w addSubview:gMenu];
}

- (void)show {
    if (gLoaded) { [self reparent]; return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self buildButton];
        gLoaded = YES;
        [self reparent];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reparent)
                                                     name:UIWindowDidBecomeKeyNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(restoreOverlay)
                                                     name:@"CZContainerizerRestoreOverlay"
                                                   object:nil];
    });
}

// Re-evite qu'un modal (picker GPS) ne masque le menu : on le re-parente.
- (void)restoreOverlay { [self reparent]; }

- (UIFont *)fa { return [UIFont systemFontOfSize:15]; }

#pragma mark - Construction du bouton

- (void)buildButton {
    if (gButton) return;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setTitle:@"⚙︎" forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.backgroundColor = [UIColor colorWithRed:0.20 green:0.43 blue:0.85 alpha:0.92];
    b.frame = CGRectMake(60, 120, 50, 50);
    b.layer.cornerRadius = 25;
    b.layer.shadowColor = [UIColor blackColor].CGColor;
    b.layer.shadowOpacity = 0.4; b.layer.shadowRadius = 4; b.layer.shadowOffset = CGSizeMake(0,2);
    b.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [b addTarget:self action:@selector(btnTapped:) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panHandler:)];
    [b addGestureRecognizer:pan];
    [pan release];
    gButton = [b retain];
}

- (void)panHandler:(UIPanGestureRecognizer *)g {
    if (!gButton) return;
    if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [g translationInView:gButton.superview];
        CGPoint c = gButton.center;
        c.x += t.x; c.y += t.y;
        gButton.center = c;
        [g setTranslation:CGPointZero inView:gButton.superview];
    }
}

#pragma mark - Menu

- (void)btnTapped:(id)sender {
    if (gMenu && gMenu.superview != nil) { [self hideMenu]; return; }
    [self showMenu];
}

- (void)showMenu {
    if (!gCurrentContainer) gCurrentContainer = [[[ContainerManager shared] activeContainer] retain];
    if (!gMenu) {
        gMenu = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 360)];
        gMenu.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.96];
        gMenu.layer.cornerRadius = 12;
        gMenu.layer.shadowColor = [UIColor blackColor].CGColor;
        gMenu.layer.shadowOpacity = 0.5; gMenu.layer.shadowRadius = 10;
        gMenu.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    }
    [[gMenu subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

    CGFloat __block y = 10;
    void (^addBtn)(NSString *, SEL) = ^(NSString *t, SEL s){
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setTitle:t forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        b.titleEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        b.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
        b.frame = CGRectMake(10, y, 300, 38);
        b.layer.cornerRadius = 8;
        [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside];
        [gMenu addSubview:b];
        y += 44;
    };

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, y, 296, 22)];
    title.text = [NSString stringWithFormat:@"Conteneur : %@", gCurrentContainer.name];
    title.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    title.font = [UIFont boldSystemFontOfSize:13];
    [gMenu addSubview:title];
    [title release];
    y += 28;

    addBtn(@"📦 Changer de conteneur", @selector(contMenu));
    addBtn(@"👥 Comptes du conteneur", @selector(accountsMenu));
    addBtn(@"📍 GPS truqué (picker)", @selector(fakeGPSAction));
    addBtn(@"♻︎ Reset profil device", @selector(resetAction));
    addBtn(@"📜 Journal / Logs", @selector(logsAction));
    addBtn(@"✕ Fermer", @selector(hideMenu));

    UIWindow *w = [UIApplication sharedApplication].keyWindow;
    if (!w) w = [UIApplication sharedApplication].windows.firstObject;
    CGRect sr = w.bounds;
    gMenu.frame = CGRectMake(sr.size.width - 330, 70, 320, y + 10);
    if (!gMenu.superview) [w addSubview:gMenu];
}

- (void)hideMenu { [gMenu removeFromSuperview]; }

- (void)menuBackgroundTapped { [self hideMenu]; }

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
    NSArray *cs = [[ContainerManager shared] allContainers];
    for (Container *c in cs) {
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
    if (accs.count == 0) {
        ac.message = @"(aucun compte sauvegardé dans ce conteneur)";
    }
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
        if (v.length) [[ContainerManager shared] saveAccountSession:@{@"username": v} forContainer:[[ContainerManager shared] activeContainer]];
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
    // (ré)injecter le compte : ici on se contente de le logger ; l'injection réelle
    // dépend de l'API Instagram non documentée et n'est pas implementee.
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


#define TWEAK_LOG(fmt, ...) [TweakLogger log:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]
