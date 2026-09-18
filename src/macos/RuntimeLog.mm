#import "RuntimeLog.h"
#include <cerrno>
#include <cstdio>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

NSString *const CassotisRuntimeLoggingEnabledKey=@"RuntimeLoggingEnabled";
static const NSUInteger maximumLogSize=2*1024*1024;

@implementation CassotisRuntimeLog {
    NSURL *_directory;
    NSUserDefaults *_defaults;
    dispatch_queue_t _queue;
    BOOL _enabled;
    int _file;
    NSUInteger _size;
}
+ (instancetype)shared {
    static CassotisRuntimeLog *log;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        NSURL *directory=[NSURL fileURLWithPath:[NSHomeDirectory()
            stringByAppendingPathComponent:@"Library/Logs/CassotisIME"] isDirectory:YES];
        log=[[self alloc] initWithDirectory:directory defaults:NSUserDefaults.standardUserDefaults];
    });
    return log;
}
- (instancetype)initWithDirectory:(NSURL *)directory defaults:(NSUserDefaults *)defaults {
    self=[super init];
    if(self) {
        _directory=[directory copy]; _defaults=defaults; _file=-1;
        _queue=dispatch_queue_create("org.cassotis.runtime-log",DISPATCH_QUEUE_SERIAL);
        // An absent preference is off, including upgrades from the always-on logger.
        _enabled=[defaults boolForKey:CassotisRuntimeLoggingEnabledKey];
    }
    return self;
}
- (void)dealloc { if(_file>=0) close(_file); }
- (BOOL)enabled {
    __block BOOL result;
    dispatch_sync(_queue,^{result=self->_enabled;});
    return result;
}
- (void)setEnabled:(BOOL)enabled {
    dispatch_sync(_queue,^{
        self->_enabled=enabled;
        [self->_defaults setBool:enabled forKey:CassotisRuntimeLoggingEnabledKey];
        if(!enabled && self->_file>=0) { close(self->_file); self->_file=-1; }
    });
}
// File operations are confined to _queue. Failure only drops diagnostics.
- (BOOL)openFile {
    if(_file>=0) return YES;
    if(![NSFileManager.defaultManager createDirectoryAtURL:_directory withIntermediateDirectories:YES
        attributes:@{NSFilePosixPermissions:@0700} error:nil]) return NO;
    NSURL *url=[_directory URLByAppendingPathComponent:@"engine.log"];
    _file=open(url.fileSystemRepresentation,O_WRONLY|O_CREAT|O_APPEND|O_CLOEXEC|O_NOFOLLOW|O_NONBLOCK,0600);
    if(_file<0) return NO;
    struct stat info;
    if(fstat(_file,&info)!=0 || !S_ISREG(info.st_mode) || fchmod(_file,0600)!=0) {
        close(_file); _file=-1; return NO;
    }
    _size=(NSUInteger)info.st_size;
    return YES;
}
- (BOOL)rotate {
    close(_file); _file=-1;
    NSURL *current=[_directory URLByAppendingPathComponent:@"engine.log"];
    NSURL *previous=[_directory URLByAppendingPathComponent:@"engine.previous.log"];
    if(unlink(previous.fileSystemRepresentation)!=0 && errno!=ENOENT) return NO;
    if(rename(current.fileSystemRepresentation,previous.fileSystemRepresentation)!=0) return NO;
    return [self openFile];
}
- (void)appendData:(NSData *)data {
    if(!data.length) return;
    dispatch_sync(_queue,^{
        if(!self->_enabled || ![self openFile]) return;
        const uint8_t *bytes=(const uint8_t *)data.bytes;
        NSUInteger remaining=data.length;
        while(remaining) {
            if(self->_size>=maximumLogSize && ![self rotate]) return;
            NSUInteger count=MIN(remaining,maximumLogSize-self->_size);
            ssize_t written=write(self->_file,bytes,count);
            if(written<0 && errno==EINTR) continue;
            if(written<=0) { close(self->_file); self->_file=-1; return; }
            self->_size+=(NSUInteger)written; bytes+=written; remaining-=(NSUInteger)written;
        }
    });
}
- (NSPipe *)captureOutputOfTask:(NSTask *)task {
    // Keep draining while disabled so the helper cannot block on a full pipe.
    // The parent owns the file, allowing toggles without restarting composition.
    NSPipe *pipe=[NSPipe pipe];
    task.standardOutput=pipe; task.standardError=pipe;
    pipe.fileHandleForReading.readabilityHandler=^(NSFileHandle *handle) {
        NSData *data=nil;
        @try { data=handle.availableData; } @catch(NSException *error) { (void)error; }
        if(data.length) [self appendData:data];
        else { handle.readabilityHandler=nil; [handle closeAndReturnError:nil]; }
    };
    return pipe;
}
@end
