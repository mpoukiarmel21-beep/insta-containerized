//
//  ContainerManager.m
//  Containerizer (Instagram tweak)
//

#import "ContainerManager.h"
#import "TweakLogger.h"

static NSArray<NSArray *> *gModelTable(void) {
    return @[
        @[@"iPhone14,7", @"iPhone 14"],
        @[@"iPhone14,8", @"iPhone 14 Plus"],
        @[@"iPhone15,2", @"iPhone 14 Pro"],
        @[@"iPhone15,3", @"iPhone 14 Pro Max"],
        @[@"iPhone15,4", @"iPhone 15 Pro"],
        @[@"iPhone15,5", @"iPhone 15 Pro Max"],
        @[@"iPhone16,1", @"iPhone 15"],
        @[@"iPhone16,2", @"iPhone 15 Plus"],
        @[@"iPhone17,1", @"iPhone 16 Pro"],
        @[@"iPhone17,2", @"iPhone 16 Pro Max"],
        @[@"iPhone17,3", @"iPhone 16"],
        @[@"iPhone17,4", @"iPhone 16 Plus"],
    ];
}

static NSString *gRandomSerial(void) {
    NSString *chars = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *s = [NSMutableString string];
    for (int i=0;i<12;i++){
        [s appendFormat:@"%C", [chars characterAtIndex:arc4random_uniform((uint32_t)chars.length)]];
    }
    return s;
}

@implementation Container

- (NSDictionary *)toDict {
    return @{
        @"uuid": self.uuid ?: @"",
        @"name": self.name ?: @"",
        @"modelIdentifier": self.modelIdentifier ?: @"",
        @"modelName": self.modelName ?: @"",
        @"iosVersion": self.iosVersion ?: @"",
        @"serial": self.serial ?: @"",
        @"latitude": @(self.latitude),
        @"longitude": @(self.longitude),
        @"locationEnabled": @(self.locationEnabled),
    };
}

- (instancetype)initWithDict:(NSDictionary *)d {
    self = [super init];
    if (self) {
        _uuid = d[@"uuid"];
        _name = d[@"name"];
        _modelIdentifier = d[@"modelIdentifier"];
        _modelName = d[@"modelName"];
        _iosVersion = d[@"iosVersion"];
        _serial = d[@"serial"];
        _latitude = [d[@"latitude"] doubleValue];
        _longitude = [d[@"longitude"] doubleValue];
        _locationEnabled = [d[@"locationEnabled"] boolValue];
    }
    return self;
}

@end

@implementation ContainerManager {
    NSString *_baseDir;
    Container *_active;
}

+ (instancetype)shared {
    static ContainerManager *s = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ s = [[ContainerManager alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _baseDir = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
                    stringByAppendingPathComponent:@"Containers"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_baseDir
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        [self loadActive];
        if (self.allContainers.count == 0) {
            Container *def = [self createContainerWithName:@"Conteneur par défaut"];
            [self setActiveContainer:def];
        }
    }
    return self;
}

- (NSString *)baseDirectory { return _baseDir; }

- (NSString *)dirFor:(Container *)c {
    return [_baseDir stringByAppendingPathComponent:c.uuid];
}

- (NSArray<Container *> *)allContainers {
    NSMutableArray *out = [NSMutableArray array];
    NSArray *subs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_baseDir error:nil];
    for (NSString *uuid in subs) {
        NSString *meta = [[_baseDir stringByAppendingPathComponent:uuid] stringByAppendingPathComponent:@"meta.json"];
        NSData *d = [NSData dataWithContentsOfFile:meta];
        if (!d) continue;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if (dict) [out addObject:[[Container alloc] initWithDict:dict]];
    }
    return out;
}

- (Container *)createContainerWithName:(NSString *)name {
    Container *c = [[Container alloc] init];
    c.uuid = [[NSUUID UUID] UUIDString];
    c.name = name ?: @"Sans nom";
    NSArray *models = gModelTable();
    NSArray *pick = models[arc4random_uniform((uint32_t)models.count)];
    c.modelIdentifier = pick[0];
    c.modelName = pick[1];
    c.iosVersion = @"26.6.1";
    c.serial = gRandomSerial();
    c.locationEnabled = NO;
    c.latitude = 48.8566;
    c.longitude = 2.3522;
    [self ensureDir:c];
    [self updateContainer:c];
    [[TweakLogger shared] log:@"Conteneur créé: %@ (%@) -> %@", c.name, c.uuid, c.modelIdentifier];
    return c;
}

- (void)ensureDir:(Container *)c {
    NSString *dir = [self dirFor:c];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:[dir stringByAppendingPathComponent:@"Accounts"]
                              withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)updateContainer:(Container *)c {
    NSString *meta = [[self dirFor:c] stringByAppendingPathComponent:@"meta.json"];
    NSData *d = [NSJSONSerialization dataWithJSONObject:[c toDict] options:NSJSONWritingPrettyPrinted error:nil];
    [d writeToFile:meta atomically:YES];
}

- (void)deleteContainer:(Container *)c {
    [[NSFileManager defaultManager] removeItemAtPath:[self dirFor:c] error:nil];
    [[TweakLogger shared] log:@"Conteneur supprimé: %@", c.name];
    if ([_active.uuid isEqualToString:c.uuid]) { _active = nil; [self saveActive]; }
}

- (void)randomizeProfileForActiveContainer {
    Container *c = [self activeContainer];
    if (!c) return;
    NSArray *models = gModelTable();
    NSArray *pick = models[arc4random_uniform((uint32_t)models.count)];
    c.modelIdentifier = pick[0];
    c.modelName = pick[1];
    c.iosVersion = @"26.6.1";
    c.serial = gRandomSerial();
    [self updateContainer:c];
    [[TweakLogger shared] log:@"Profil device réinitialisé pour %@", c.name];
}

- (void)setActiveContainer:(Container *)c {
    _active = c;
    [self saveActive];
    [[TweakLogger shared] log:@"Conteneur actif: %@ (%@)", c.name, c.modelIdentifier];
}

- (Container *)activeContainer { return _active; }

- (void)saveActive {
    NSString *p = [_baseDir stringByAppendingPathComponent:@"active.plist"];
    [@{@"uuid": _active ? _active.uuid : @""} writeToFile:p atomically:YES];
}

- (void)loadActive {
    NSString *p = [_baseDir stringByAppendingPathComponent:@"active.plist"];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
    NSString *uuid = d[@"uuid"];
    if (uuid.length) {
        for (Container *c in self.allContainers) {
            if ([c.uuid isEqualToString:uuid]) { _active = c; break; }
        }
    }
}

- (void)saveAccountSession:(NSDictionary *)session forContainer:(Container *)c {
    NSString *dir = [[self dirFor:c] stringByAppendingPathComponent:@"Accounts"];
    NSArray *existing = [self accountSessionsForContainer:c];
    NSMutableArray *arr = [NSMutableArray arrayWithArray:existing];
    [arr addObject:session ?: @{}];
    NSData *d = [NSJSONSerialization dataWithJSONObject:arr options:NSJSONWritingPrettyPrinted error:nil];
    [d writeToFile:[dir stringByAppendingPathComponent:@"sessions.json"] atomically:YES];
    [[TweakLogger shared] log:@"Session compte sauvegardée pour %@", c.name];
}

- (NSArray<NSDictionary *> *)accountSessionsForContainer:(Container *)c {
    NSString *p = [[[self dirFor:c] stringByAppendingPathComponent:@"Accounts"]
                   stringByAppendingPathComponent:@"sessions.json"];
    NSData *d = [NSData dataWithContentsOfFile:p];
    if (!d) return @[];
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    return [obj isKindOfClass:[NSArray class]] ? obj : @[];
}

- (void)removeAccountSession:(NSDictionary *)session forContainer:(Container *)c {
    NSMutableArray *arr = [NSMutableArray arrayWithArray:[self accountSessionsForContainer:c]];
    [arr removeObject:session];
    NSString *p = [[[self dirFor:c] stringByAppendingPathComponent:@"Accounts"]
                   stringByAppendingPathComponent:@"sessions.json"];
    NSData *d = [NSJSONSerialization dataWithJSONObject:arr options:NSJSONWritingPrettyPrinted error:nil];
    [d writeToFile:p atomically:YES];
    [[TweakLogger shared] log:@"Session compte supprimée pour %@", c.name];
}

- (void)resetAll {
    [[NSFileManager defaultManager] removeItemAtPath:_baseDir error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:_baseDir
                              withIntermediateDirectories:YES attributes:nil error:nil];
    _active = nil;
    [self saveActive];
    [[TweakLogger shared] log:@"RESET GLOBAL: tous les conteneurs effacés."];
    Container *def = [self createContainerWithName:@"Conteneur par défaut"];
    [self setActiveContainer:def];
}

@end
