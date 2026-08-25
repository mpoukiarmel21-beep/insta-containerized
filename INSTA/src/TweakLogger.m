//
//  TweakLogger.m
//  Containerizer (Instagram tweak)
//

#import "TweakLogger.h"

@implementation TweakLogger {
    NSFileHandle *_handle;
    dispatch_queue_t _queue;
}

+ (instancetype)shared {
    static TweakLogger *s = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ s = [[TweakLogger alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.containerizer.logger", DISPATCH_QUEUE_SERIAL);
        NSString *path = [self logPath];
        @try {
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [[NSData data] writeToFile:path atomically:YES];
            }
            _handle = [NSFileHandle fileHandleForWritingAtPath:path];
            [_handle seekToEndOfFile];
        } @catch (NSException *e) { _handle = nil; }
    }
    return self;
}

- (NSString *)logPath {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [dir stringByAppendingPathComponent:@"tweak.log"];
}

- (void)writeLine:(NSString *)line {
    if (!_handle) return;
    dispatch_async(_queue, ^{
        @try {
            NSDateFormatter *f = [[NSDateFormatter alloc] init];
            f.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            NSString *stamp = [f stringFromDate:[NSDate date]];
            NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", stamp, line];
            [_handle writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
            [_handle synchronizeFile];
        } @catch (NSException *e) {}
    });
}

- (void)log:(NSString *)format, ... {
    va_list args; va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self writeLine:[@"[INFO] " stringByAppendingString:msg]];
}

- (void)logError:(NSString *)format, ... {
    va_list args; va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    [self writeLine:[@"[ERROR] " stringByAppendingString:msg]];
}

- (NSString *)recentLog {
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:[self logPath]
                                                  encoding:NSUTF8StringEncoding error:&err];
    if (!content) return @"";
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    NSArray *tail = [lines subarrayWithRange:NSMakeRange(MAX(0,(int)lines.count-50),(int)MIN(lines.count,50))];
    return [tail componentsJoinedByString:@"\n"];
}

@end
