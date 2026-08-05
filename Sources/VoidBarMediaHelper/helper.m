// Now Playing feed, loaded into /usr/bin/perl.
//
// Since macOS 15.4 the mediaremoted daemon answers only clients it trusts, so
// an ordinary app gets an empty dictionary no matter what it asks. Claiming the
// `com.apple.mediaremote.external-access` entitlement does not help either: it
// is restricted, and a process that claims it without Apple's authorization is
// killed at launch.
//
// /usr/bin/perl, however, is a platform binary (Platform identifier=16) that
// the daemon does trust, and it is signed without library validation — so it
// can load this dylib. Running the MediaRemote calls from inside that process
// yields the full record: title, artist, album, duration, position, artwork.
//
// The helper prints one JSON object per line on stdout and takes commands on
// stdin. It exits as soon as stdin closes, so it can never outlive VoidBar.

#import <Foundation/Foundation.h>
#import <dlfcn.h>

typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetBoolFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRRegisterFn)(dispatch_queue_t);
typedef Boolean (*MRSendCommandFn)(int, CFDictionaryRef);
typedef void (*MRSetElapsedFn)(double);
typedef void (*MRGetPIDFn)(dispatch_queue_t, void (^)(int));

static MRGetInfoFn sGetInfo;
static MRGetBoolFn sGetIsPlaying;
static MRSendCommandFn sSendCommand;
static MRSetElapsedFn sSetElapsed;
static MRGetPIDFn sGetPID;
static int sOwnerPID;
static dispatch_queue_t sQueue;
static NSString *sArtworkID;

static NSString *const kMediaRemotePath =
    @"/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote";

static void emit(NSDictionary *payload) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    if (!json) return;
    fwrite(json.bytes, 1, json.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

/// Reads the current record and prints it. Artwork is only included when the
/// track changed — it is the bulk of the payload and never changes mid-track.
static void publish(void) {
    if (!sGetInfo || !sGetIsPlaying) return;
    // Cached rather than nested a call deeper: it only labels the source.
    if (sGetPID) sGetPID(sQueue, ^(int pid) { sOwnerPID = pid; });
    sGetIsPlaying(sQueue, ^(Boolean playing) {
        sGetInfo(sQueue, ^(CFDictionaryRef raw) {
            NSDictionary *info = (__bridge NSDictionary *)raw;
            NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"] ?: @"";

            NSMutableDictionary *out = [NSMutableDictionary dictionary];
            out[@"playing"] = @(playing ? YES : NO);
            out[@"title"] = title;
            out[@"artist"] = info[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: @"";
            out[@"album"] = info[@"kMRMediaRemoteNowPlayingInfoAlbum"] ?: @"";
            out[@"duration"] = info[@"kMRMediaRemoteNowPlayingInfoDuration"] ?: @0;
            out[@"elapsed"] = info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"] ?: @0;
            out[@"rate"] = info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] ?: @0;
            out[@"pid"] = @(sOwnerPID);

            NSString *artworkID = info[@"kMRMediaRemoteNowPlayingInfoArtworkIdentifier"] ?: title;
            NSData *artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
            if (artwork.length > 0 && ![artworkID isEqualToString:sArtworkID]) {
                out[@"artwork"] = [artwork base64EncodedStringWithOptions:0];
                sArtworkID = artworkID;
            }
            if (title.length == 0) sArtworkID = nil;

            emit(out);
        });
    });
}

static void handleCommand(NSString *line) {
    if ([line isEqualToString:@"get"]) {
        publish();
    } else if ([line hasPrefix:@"cmd "]) {
        if (sSendCommand) sSendCommand([line substringFromIndex:4].intValue, NULL);
        publish();
    } else if ([line hasPrefix:@"seek "]) {
        if (sSetElapsed) sSetElapsed([line substringFromIndex:5].doubleValue);
        publish();
    }
}

static void startFeed(void) {
    [NSThread detachNewThreadWithBlock:^{
        sQueue = dispatch_queue_create("dev.xand0.voidbar.mediaremote", DISPATCH_QUEUE_SERIAL);

        void *handle = dlopen(kMediaRemotePath.UTF8String, RTLD_NOW);
        if (!handle) {
            emit(@{@"error": @"mediaremote-unavailable"});
            return;
        }
        sGetInfo = (MRGetInfoFn)dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
        sGetIsPlaying = (MRGetBoolFn)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
        sSendCommand = (MRSendCommandFn)dlsym(handle, "MRMediaRemoteSendCommand");
        sSetElapsed = (MRSetElapsedFn)dlsym(handle, "MRMediaRemoteSetElapsedTime");
        sGetPID = (MRGetPIDFn)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID");

        MRRegisterFn registerNotifications =
            (MRRegisterFn)dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications");
        if (registerNotifications) registerNotifications(sQueue);

        NSArray *names = @[
            @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        ];
        for (NSString *name in names) {
            [NSNotificationCenter.defaultCenter addObserverForName:name
                                                           object:nil
                                                            queue:nil
                                                       usingBlock:^(NSNotification *note) {
                publish();
            }];
        }

        publish();
        [NSRunLoop.currentRunLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [NSRunLoop.currentRunLoop run];
    }];
}

static void startCommandReader(void) {
    [NSThread detachNewThreadWithBlock:^{
        char buffer[512];
        while (fgets(buffer, sizeof buffer, stdin)) {
            @autoreleasepool {
                NSString *line = [@(buffer) stringByTrimmingCharactersInSet:
                                  NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (line.length) handleCommand(line);
            }
        }
        // VoidBar closed the pipe or went away.
        exit(0);
    }];
}

__attribute__((constructor))
static void voidbar_helper_init(void) {
    startFeed();
    startCommandReader();
}
