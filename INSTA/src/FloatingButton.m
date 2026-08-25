//
//  FloatingButton.m
//  Containerizer (Instagram tweak)
//
//  ECRAN: la dylib est compilee en -fno-objc-arc (MRC). On utilise donc une
//  UIWindow d'overlay QUI NOUS APPARTIENT (retard + jamais detruite + jamais
//  remplacee par Instagram) pour y accrocher le bouton et le menu. Cela
//  evite (1) la disparition du bouton quand Instagram change sa keyWindow et
//  (2) le crash par pointeur pendouillant (memory management MRC).
//

#import "FloatingButton.h"
#import "ContainerManager.h"
#import "LocationSpoofer.h"
#import "TweakLogger.h"

static UIButton *gButton = nil;       // retenu via [b retain]
static UIVisualEffectView *gMenu = nil;
static UIWindow *gOverlay = nil;       // notre fenetre, jamais liberee

@interface FloatingButton ()
@end

@implementation FloatingButton

+ (instancetype)shared {
    static FloatingButton *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[FloatingButton alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Restaure l'overlay quand la picker GPS se ferme (elle se presente
        // et se ferme toute seule depuis LocationSpoofer).
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(restoreOverlay)
                                                     name:@"CZContainerizerRestoreOverlay"
                                                   object:nil];
    }
    return self;
}

+ (UIViewController *)topViewController {
    UIWindow *win = UIApplication.sharedApplication.keyWindow;
    if (!win) return nil;
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

// Notre fenetre d'overlay, creee une seule fois et conservee.
+ (UIWindow *)overlayWindow {
    if (!gOverlay) {
        gOverlay = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        gOverlay.rootViewController = [[UIViewController alloc] init];
        gOverlay.windowLevel = UIWindowLevelAlert + 1; // au-dessus d'Instagram
        gOverlay.hidden = NO;                            // jamais key (Instagram garde le clavier)
        gOverlay.userInteractionEnabled = YES;
        [[TweakLogger shared] log:@"Overlay window creee."];
    }
    return gOverlay;
}

- (void)attachButton {
    if (gButton) { [gButton removeFromSuperview]; }
    else {
        UIButton *b = [[UIButton alloc] initWithFrame:CGRectZero];
        [b setTitle:@"⚙︎" forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:0.9];
        b.layer.cornerRadius = 28;
        b.layer.shadowColor = [UIColor blackColor].CGColor;
        b.layer.shadowOpacity = 0.4;
        b.layer.shadowRadius = 6;
        [b addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        [b addGestureRecognizer:pan];
        gButton = [b retain]; // propriete permanente (MRC)
    }
    UIWindow *win = [FloatingButton overlayWindow];
    CGSize sz = win.bounds.size;
    gButton.frame = CGRectMake(sz.width - 64, sz.height - 120, 56, 56);
    [win addSubview:gButton];
    [[TweakLogger shared] log:@"Bouton flottant affiche (overlay)."];
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self attachButton];
    });
}

- (void)drag:(UIPanGestureRecognizer *)p {
    UIButton *b = (UIButton *)p.view;
    if (p.state == UIGestureRecognizerStateEnded) return;
    CGPoint t = [p translationInView:b.superview];
    CGPoint c = b.center;
    c.x += t.x; c.y += t.y;
    // bornes ecran
    CGSize s = b.superview.bounds.size;
    c.x = MAX(28, MIN(s.width - 28, c.x));
    c.y = MAX(28, MIN(s.height - 28, c.y));
    b.center = c;
    [p setTranslation:CGPointZero inView:b.superview];
}

- (void)toggleMenu {
    if (gMenu) { [self closeMenu]; return; }
    [self showMenu];
}

- (void)closeMenu {
    if (!gMenu) return;
    [gMenu removeFromSuperview];
    [gMenu release];
    gMenu = nil;
}

- (void)showMenu {
    UIWindow *win = [FloatingButton overlayWindow];
    CGFloat w = 280, h = 380;
    CGRect f = CGRectMake((win.bounds.size.width - w)/2, (win.bounds.size.height - h)/2, w, h);
    UIVisualEffectView *v = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    v.frame = f;
    v.layer.cornerRadius = 16;
    v.clipsToBounds = YES;

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 40, w, h - 40) style:UITableViewStylePlain];
    table.backgroundColor = [UIColor clearColor];
    table.dataSource = (id)self;
    table.delegate = (id)self;
    [v.contentView addSubview:table];
    [table release];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, w, 28)];
    title.text = @"Conteneurs";
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    [v.contentView addSubview:title];
    [title release];

    [win addSubview:v];
    gMenu = v; // v est retenu par la fenetre + ce pointeur (alloc)
}

// Affiche une modal sur la fenetre d'Instagram (clavier OK) en cachant l'overlay.
- (void)presentModalOnApp:(UIViewController *)vc {
    gOverlay.hidden = YES;
    UIViewController *top = [FloatingButton topViewController];
    if (!top) { gOverlay.hidden = NO; return; }
    [top presentViewController:vc animated:YES completion:nil];
}
- (void)restoreOverlay {
    gOverlay.hidden = NO;
    [self attachButton]; // re-positionne le bouton (overlay intact)
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    ContainerManager *cm = [ContainerManager shared];
    return cm.allContainers.count + 4;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"c"];
    ContainerManager *cm = [ContainerManager shared];
    NSArray *conts = cm.allContainers;
    if (ip.row < conts.count) {
        Container *c = conts[ip.row];
        cell.textLabel.text = c.name;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • GPS %@", c.modelIdentifier, c.locationEnabled ? @"ON" : @"OFF"];
        cell.accessoryType = ([cm.activeContainer.uuid isEqualToString:c.uuid]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        NSInteger extra = ip.row - conts.count;
        cell.detailTextLabel.text = @"";
        cell.textLabel.textColor = [UIColor whiteColor];
        if (extra == 0) { cell.textLabel.text = @"➕ Créer un conteneur"; }
        else if (extra == 1) { cell.textLabel.text = @"📍 Faux GPS"; }
        else if (extra == 2) { cell.textLabel.text = @"📜 Journal / Logs"; }
        else if (extra == 3) { cell.textLabel.text = @"♻︎ Tout réinitialiser"; cell.textLabel.textColor = [UIColor redColor]; }
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    ContainerManager *cm = [ContainerManager shared];
    NSArray *conts = cm.allContainers;

    if (ip.row < conts.count) {
        Container *ac = conts[ip.row];
        [cm setActiveContainer:ac];
        [tv reloadData];
        [[TweakLogger shared] log:@"Conteneur actif bascule: %@", ac.name];
        return;
    }
    NSInteger extra = ip.row - conts.count;
    if (extra == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Nom du conteneur"
                                                                   message:nil preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:nil];
        [a addAction:[UIAlertAction actionWithTitle:@"Créer" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
            NSString *n = a.textFields.firstObject.text;
            Container *c = [cm createContainerWithName:n];
            [cm setActiveContainer:c];
            [tv reloadData];
            [self restoreOverlay];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:^(UIAlertAction *_) {
            [self restoreOverlay];
        }]];
        [self presentModalOnApp:a];
    } else if (extra == 1) {
        [LocationSpoofer presentPickerFrom:[FloatingButton topViewController]];
        // La picker se presente elle-meme ; on cache l'overlay pendant.
        gOverlay.hidden = YES;
    } else if (extra == 2) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Journal"
                                                                   message:[[TweakLogger shared] recentLog] preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
            [self restoreOverlay];
        }]];
        [self presentModalOnApp:a];
    } else if (extra == 3) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Tout réinitialiser ?"
                                                                   message:@"Efface TOUS les conteneurs et données." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Effacer" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
            [cm resetAll];
            [tv reloadData];
            [self restoreOverlay];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:^(UIAlertAction *_) {
            [self restoreOverlay];
        }]];
        [self presentModalOnApp:a];
    }
}

@end
