//
//  FloatingButton.m
//  Tweak
//
//  Bouton flottant draggable + menu de conteneurs (device/GPS/comptes).
//  MRC (-fno-objc-arc). Re-epingle permanent sur la fenetre la plus haute.
//
//  DESIGN "NEON GLASS TECH" (recherche 2026) :
//   - Modele Liquid Glass respecte : le texte vit sur une couche SOLIDE quasi
//     opaque (gris fonce #0D1016 a 93%, jamais de noir pur), jamais sur du verre seul.
//   - Verre chirurgical : le blur n'apporte que la profondeur, l'opacite garantit
//     le contraste (lecon iOS 26 Beta 3 : Apple a du "geler" son Liquid Glass illisible).
//   - Accent neon cyan -> indigo : FAB lumineux (glow cyan), icones SF Symbols
//     teintees cyan, strip gradient sous l'en-tete. Bordure hairline blanche,
//     pas d'ombres portees comme separateur (dark-first 2026).
//   - Micro-interactions : spring a l'ouverture, highlight au toucher, scale du FAB.
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

// Palette Neon Glass Tech
#define CACCENT()  [UIColor colorWithRed:0.404f green:0.906f blue:0.976f alpha:1.0f] // cyan #67E8F9
#define CINDIGO()  [UIColor colorWithRed:0.388f green:0.400f blue:0.945f alpha:1.0f] // indigo #6366F1
#define CPANEL()   [UIColor colorWithRed:0.051f green:0.063f blue:0.086f alpha:0.93f] // #0D1016 @93%
#define CW(alpha)  [UIColor colorWithWhite:1.0f alpha:(alpha)]

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
- (UIView *)iconChipWithSymbol:(NSString *)symbol;
- (CGFloat)addRowTo:(UIView *)menu atY:(CGFloat)y symbol:(NSString *)sym title:(NSString *)title action:(SEL)action isLast:(BOOL)last;
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
    if (!top || !gButton) return;
    if (gButton.superview != top) [top addSubview:gButton];
    [top bringSubviewToFront:gButton];
    if (gMenuVisible && gMenu) {
        if (gMenu.superview != top) [top addSubview:gMenu];
        [top bringSubviewToFront:gMenu];
    }
}

#pragma mark - FAB (glow neon)

- (void)buildButton {
    if (gButton) return;
    CGFloat size = 54;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect sb = [UIScreen mainScreen].bounds;
    b.frame = CGRectMake(sb.size.width - size - 22, sb.size.height - size - 118, size, size);
    b.layer.cornerRadius = size / 2.0;
    b.layer.masksToBounds = NO;

    // Glow neon cyan : la signature "tech" du bouton.
    b.layer.shadowColor = CACCENT().CGColor;
    b.layer.shadowOpacity = 0.55;
    b.layer.shadowRadius = 16;
    b.layer.shadowOffset = CGSizeMake(0, 0);
    b.layer.shadowPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size/2.0, size/2.0)
                                                        radius:size/2.0 - 1 startAngle:0 endAngle:2*M_PI].CGPath;

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = CGRectMake(0, 0, size, size);
    grad.cornerRadius = size / 2.0;
    grad.colors = @[ (__bridge id)CACCENT().CGColor, (__bridge id)CINDIGO().CGColor ];
    grad.startPoint = CGPointMake(0.15, 0.15);
    grad.endPoint   = CGPointMake(0.85, 0.85);
    [b.layer addSublayer:grad];

    UIImage *sym = [UIImage systemImageNamed:@"cpu.fill"];
    UIImageView *iv = [[UIImageView alloc] initWithImage:sym];
    iv.frame = CGRectMake((size - 24) / 2.0, (size - 24) / 2.0, 24, 24);
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.tintColor = [UIColor whiteColor];
    iv.userInteractionEnabled = NO;
    [b addSubview:iv];
    [iv release];

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
        gButton.transform = CGAffineTransformMakeScale(0.88, 0.88);
    } completion:nil];
}
- (void)btnTouchUp:(id)sender {
    [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.6 options:0 animations:^{
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

#pragma mark - Panneau (couche solide + verre de profondeur)

- (void)buildMenuIfNeeded {
    if (gMenu) return;
    gMenu = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 292, 420)];
    gMenu.backgroundColor = CPANEL();          // couche solide : lisibilite garantie
    gMenu.layer.cornerRadius = 24;
    gMenu.layer.borderWidth = 1.0;
    gMenu.layer.borderColor = CW(0.14).CGColor; // bordure hairline (pas d'ombre-separateur)
    gMenu.layer.shadowColor = [UIColor blackColor].CGColor;
    gMenu.layer.shadowOpacity = 0.55;
    gMenu.layer.shadowRadius = 26;
    gMenu.layer.shadowOffset = CGSizeMake(0, 14);
    gMenu.clipsToBounds = NO;
}

- (UIView *)iconChipWithSymbol:(NSString *)symbol {
    // Retourne une vue retenue (+1) : l'appelant la release apres addSubview.
    UIView *chip = [[UIView alloc] initWithFrame:CGRectMake(16, 11, 30, 30)];
    chip.layer.cornerRadius = 9;
    chip.backgroundColor = CW(0.07);

    UIImage *img = [[UIImage systemImageNamed:symbol]
        imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.5
                                                                                   weight:UIImageSymbolConfigurationWeightMedium]];
    UIImageView *iv = [[UIImageView alloc] initWithImage:img];
    iv.frame = chip.bounds;
    iv.contentMode = UIViewContentModeCenter;
    iv.tintColor = CACCENT();
    iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [chip addSubview:iv];
    [iv release];

    chip.tag = 777; // retrouve pour le highlight presse
    return chip;
}

- (CGFloat)addRowTo:(UIView *)menu atY:(CGFloat)y symbol:(NSString *)sym title:(NSString *)title action:(SEL)action isLast:(BOOL)last {
    CGFloat rowH = 52;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, menu.bounds.size.width, rowH)];

    UIView *chip = [self iconChipWithSymbol:sym];
    [row addSubview:chip];
    [chip release];

    UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(58, 0, menu.bounds.size.width - 58 - 14, rowH)];
    lab.text = title;
    lab.textColor = CW(0.96);                       // couche solide : blanc plein
    lab.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightMedium];
    lab.textAlignment = NSTextAlignmentLeft;
    [row addSubview:lab]; [lab release];

    if (!last) {
        UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(58, rowH - 0.5, menu.bounds.size.width - 58 - 16, 0.5)];
        sep.backgroundColor = CW(0.07);
        sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [row addSubview:sep]; [sep release];
    }

    UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
    hit.frame = row.bounds;
    hit.backgroundColor = [UIColor clearColor];
    [hit addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [hit addTarget:self action:@selector(rowHighlightOn:) forControlEvents:UIControlEventTouchDown];
    [hit addTarget:self action:@selector(rowHighlightOff:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    hit.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [row addSubview:hit];

    [menu addSubview:row]; [row release];
    return y + rowH;
}

- (void)rowHighlightOn:(UIButton *)b { b.backgroundColor = CW(0.09); }
- (void)rowHighlightOff:(UIButton *)b { b.backgroundColor = [UIColor clearColor]; }

#pragma mark - Ouverture / fermeture

- (void)btnTapped:(id)sender {
    [self btnTouchUp:sender];
    if (gMenuVisible) { [self hideMenu]; return; }
    [self buildMenuIfNeeded];
    [self showMenu];
}

- (void)showMenu {
    if (!gCurrentContainer) gCurrentContainer = [[[ContainerManager shared] activeContainer] retain];
    else {
        [gCurrentContainer release];
        gCurrentContainer = [[[ContainerManager shared] activeContainer] retain];
    }
    [[gMenu subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

    CGFloat W = gMenu.bounds.size.width;

    // --- Verre de profondeur (sous la couche solide : uniquement decoratif) ---
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.frame = gMenu.bounds;
    blur.alpha = 0.35;
    blur.userInteractionEnabled = NO;
    [gMenu addSubview:blur];
    [blur release];

    // --- En-tete ---
    UILabel *eyebrow = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, W - 40, 12)];
    eyebrow.attributedText = [[NSAttributedString alloc]
        initWithString:@"CONTENEUR ACTIF"
            attributes:@{ NSFontAttributeName      : [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold],
                          NSKernAttributeName      : @1.8,
                          NSForegroundColorAttributeName : CW(0.45) }];
    [gMenu addSubview:eyebrow];
    [eyebrow release];

    UILabel *nameLab = [[UILabel alloc] initWithFrame:CGRectMake(20, 29, W - 52, 24)];
    nameLab.text = gCurrentContainer.name ?: @"default";
    nameLab.textColor = [UIColor whiteColor];       // 100% opacite : texte critique
    nameLab.font = [UIFont systemFontOfSize:17.5 weight:UIFontWeightBold];
    [gMenu addSubview:nameLab];
    [nameLab release];

    // Point d'etat GPS : cyan si position truquee active.
    Container *cc = gCurrentContainer;
    BOOL gpsOn = cc.locationEnabled;
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(W - 34, 33, 8, 8)];
    dot.layer.cornerRadius = 4;
    dot.backgroundColor = gpsOn ? CACCENT() : CW(0.22);
    dot.layer.shadowColor = CACCENT().CGColor;
    dot.layer.shadowOpacity = gpsOn ? 0.9 : 0.0;
    dot.layer.shadowRadius = 4;
    dot.layer.shadowOffset = CGSizeZero;
    [gMenu addSubview:dot];
    [dot release];

    // --- Strip gradient : signature tech entre en-tete et actions ---
    // (en sous-vue pour etre purge par le sweep removeFromSuperview a chaque ouverture)
    UIView *stripHolder = [[UIView alloc] initWithFrame:CGRectMake(20, 62, W - 40, 2)];
    stripHolder.backgroundColor = [UIColor clearColor];
    stripHolder.layer.cornerRadius = 1;
    CAGradientLayer *strip = [CAGradientLayer layer];
    strip.frame = stripHolder.bounds;
    strip.cornerRadius = 1;
    strip.colors = @[ (__bridge id)CACCENT().CGColor, (__bridge id)CINDIGO().CGColor ];
    strip.startPoint = CGPointMake(0, 0.5);
    strip.endPoint   = CGPointMake(1, 0.5);
    [stripHolder.layer addSublayer:strip];
    [gMenu addSubview:stripHolder];
    [stripHolder release];

    // --- Rangees ---
    CGFloat y = 74;
    y = [self addRowTo:gMenu atY:y symbol:@"shippingbox.fill"             title:@"Changer de conteneur" action:@selector(contMenu)         isLast:NO];
    y = [self addRowTo:gMenu atY:y symbol:@"person.2.fill"                title:@"Comptes du conteneur" action:@selector(accountsMenu)      isLast:NO];
    y = [self addRowTo:gMenu atY:y symbol:@"location.fill"                title:@"GPS truqué"           action:@selector(fakeGPSAction)     isLast:NO];
    y = [self addRowTo:gMenu atY:y symbol:@"arrow.triangle.2.circlepath"  title:@"Reset profil device"  action:@selector(resetAction)       isLast:NO];
    y = [self addRowTo:gMenu atY:y symbol:@"doc.text.magnifyingglass"     title:@"Journal / Logs"       action:@selector(logsAction)        isLast:NO];
    y = [self addRowTo:gMenu atY:y symbol:@"xmark"                        title:@"Fermer"               action:@selector(hideMenu)          isLast:YES];

    // --- Pied discret ---
    UILabel *foot = [[UILabel alloc] initWithFrame:CGRectMake(0, y + 4, W, 14)];
    foot.attributedText = [[NSAttributedString alloc]
        initWithString:@"CONTAINERIZER"
            attributes:@{ NSFontAttributeName : [UIFont monospacedSystemFontOfSize:8.5 weight:UIFontWeightMedium],
                          NSKernAttributeName : @3.0,
                          NSForegroundColorAttributeName : CW(0.30) }];
    foot.textAlignment = NSTextAlignmentCenter;
    [gMenu addSubview:foot];
    [foot release];

    UIWindow *w = [self topWindow];
    CGRect sr = w.bounds;
    CGFloat H = y + 22;
    gMenu.frame = CGRectMake(sr.size.width - W - 14, 64, W, H);

    gMenuVisible = YES;
    gMenu.alpha = 0;
    gMenu.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.94, 0.94),
                                              CGAffineTransformMakeTranslation(8, -5));
    if (gMenu.superview != w) [w addSubview:gMenu];
    [w bringSubviewToFront:gMenu];
    [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.80 initialSpringVelocity:0.65
                        options:UIViewAnimationOptionCurveEaseOut animations:^{
        gMenu.alpha = 1;
        gMenu.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hideMenu {
    if (!gMenuVisible) return;
    gMenuVisible = NO;
    [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        gMenu.alpha = 0;
        gMenu.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.95, 0.95),
                                                  CGAffineTransformMakeTranslation(6, -4));
    } completion:^(BOOL done){
        [gMenu removeFromSuperview];
        gMenu.transform = CGAffineTransformIdentity;
    }];
}

#pragma mark - Actions conteneurs

- (void)switchContainerAction:(UIAlertAction *)a {
    NSString *name = a.title;
    for (Container *c in [[ContainerManager shared] allContainers]) {
        if ([c.name isEqualToString:name]) { [[ContainerManager shared] setActiveContainer:c]; break; }
    }
    [gCurrentContainer release];
    gCurrentContainer = [[[ContainerManager shared] activeContainer] retain];
    [self showMenu]; // rafraichit l'en-tete sans refermer brutalement
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
    UIViewController *vc = topController();
    TWEAK_LOG("Ouverture picker GPS (topVC=%@)", NSStringFromClass([vc class]));
    [LocationSpoofer presentPickerFrom:vc];
}

- (void)resetAction {
    [self hideMenu];
    Container *c = [[ContainerManager shared] activeContainer];
    c.locationEnabled = NO;
    [[ContainerManager shared] updateContainer:c];
    [LocationSpoofer invalidateCachedLocation];
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
