//
//  TweakLogger.h
//  Containerizer (Instagram tweak)
//  Journal local pour diagnostic à distance.
//

#import <Foundation/Foundation.h>

@interface TweakLogger : NSObject
+ (instancetype)shared;
- (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)logError:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (NSString *)logPath;
- (NSString *)recentLog;
- (void)writeCrash:(NSString *)info;
@end
