//
//  FloatingButton.m
//  Containerizer (Instagram tweak)
//

#import "FloatingButton.h"
#import "ContainerManager.h"
#import "LocationSpoofer.h"
#import "TweakLogger.h"

static UIButton *gButton = nil;
static UIVisualEffectView *gMenu = nil;

@interface FloatingButton ()
@end

@implementation FloatingButton

+ (instancetype)shared {
    static FloatingButton *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[FloatingButton alloc] init]; });
    return s;
}

+ (UIViewController *)topViewController {
    UIWindow *win = UIApplication.sharedApplication.keyWindow;
    UIViewController *vc = win.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = UIApplication.sharedApplication.keyWindow;
        if (!win) return;

        // Si le bouton existe déjà, on le ré-accroche à la fenêtre courante
        // (Instagram peut remplacer sa keyWindow -> sinon le bouton disparaît).
        if (gButton) {
            if (gButton.superview != win) {
                [gButton removeFromSuperview];
                [win addSubview:gButton];
            }
            return;
        }

        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        [b setTitle:@"⚙︎" forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:0.9];
        b.layer.cornerRadius = 28;
        b.frame = CGRectMake(win.bounds.size.width - 64, win.bounds.size.height - 120, 56, 56);
        b.layer.shadowColor = [UIColor blackColor].CGColor;
        b.layer.shadowOpacity = 0.4;
        b.layer.shadowRadius = 6;
        [b addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        [b addGestureRecognizer:pan];

        [win addSubview:b];
        gButton = b;
        [[TweakLogger shared] log:@"Bouton flottant affiché."];
    });
}

- (void)drag:(UIPanGestureRecognizer *)p {
    UIButton *b = (UIButton *)p.view;
    CGPoint t = [p translationInView:b.superview];
    b.center = CGPointMake(b.center.x + t.x, b.center.y + t.y);
    [p setTranslation:CGPointZero inView:b.superview];
}

- (void)toggleMenu {
    if (gMenu) { [gMenu removeFromSuperview]; gMenu = nil; return; }
    [self showMenu];
}

- (void)showMenu {
    UIWindow *win = UIApplication.sharedApplication.keyWindow;
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

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, w, 28)];
    title.text = @"Conteneurs";
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    [v.contentView addSubview:title];

    [win addSubview:v];
    gMenu = v;
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
        [cm setActiveContainer:conts[ip.row]];
        [tv reloadData];
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
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
        [[FloatingButton topViewController] presentViewController:a animated:YES completion:nil];
    } else if (extra == 1) {
        [LocationSpoofer presentPickerFrom:[FloatingButton topViewController]];
    } else if (extra == 2) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Journal"
                                                                  message:[[TweakLogger shared] recentLog] preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [[FloatingButton topViewController] presentViewController:a animated:YES completion:nil];
    } else if (extra == 3) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Tout réinitialiser ?"
                                                                  message:@"Efface TOUS les conteneurs et données." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Effacer" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *_) {
            [cm resetAll];
            [tv reloadData];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Annuler" style:UIAlertActionStyleCancel handler:nil]];
        [[FloatingButton topViewController] presentViewController:a animated:YES completion:nil];
    }
}

@end
