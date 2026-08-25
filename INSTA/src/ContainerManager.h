//
//  ContainerManager.h
//  Containerizer (Instagram tweak)
//  Chaque conteneur = dossier isolé dans Documents/Containers/<uuid>
//  + profil device + localisation + comptes (sessions) persistés en JSON.
//

#import <Foundation/Foundation.h>

@interface Container : NSObject
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *modelIdentifier;
@property (nonatomic, strong) NSString *modelName;
@property (nonatomic, strong) NSString *iosVersion;
@property (nonatomic, strong) NSString *serial;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, assign) BOOL locationEnabled;
- (NSDictionary *)toDict;
- (instancetype)initWithDict:(NSDictionary *)d;
@end

@interface ContainerManager : NSObject
+ (instancetype)shared;
- (NSString *)baseDirectory;
- (NSArray<Container *> *)allContainers;
- (Container *)activeContainer;
- (Container *)createContainerWithName:(NSString *)name;
- (void)deleteContainer:(Container *)c;
- (void)setActiveContainer:(Container *)c;
- (void)updateContainer:(Container *)c;
- (void)saveAccountSession:(NSDictionary *)session forContainer:(Container *)c;
- (NSArray<NSDictionary *> *)accountSessionsForContainer:(Container *)c;
- (void)resetAll;
@end
