#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudio.h>
#include <signal.h>
#include <stdatomic.h>

static volatile sig_atomic_t interrupted = 0;

static void interrupt(int number) {
    (void)number;
    interrupted = 1;
}

static int permission(BOOL request) {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (request && status == AVAuthorizationStatusNotDetermined) {
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            (void)granted;
            dispatch_semaphore_signal(done);
        }];
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
        status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    }
    if (!request) {
        const char *names[] = {"not-determined", "restricted", "denied", "authorized"};
        printf("Microphone: %s\n", names[status]);
    }
    if (status == AVAuthorizationStatusAuthorized) return 0;
    if (request) {
        fprintf(stderr, "microphone: grant Microphone access to your terminal in "
                "System Settings > Privacy & Security, then restart the terminal.\n");
    }
    return 1;
}

static NSString *deviceString(AudioDeviceID device, AudioObjectPropertySelector selector) {
    AudioObjectPropertyAddress address = {selector, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
    CFStringRef value = NULL;
    UInt32 size = sizeof(value);
    if (AudioObjectGetPropertyData(device, &address, 0, NULL, &size, &value) != noErr) return nil;
    return CFBridgingRelease(value);
}

static NSArray<NSDictionary *> *microphones(void) {
    AudioObjectPropertyAddress address = {kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal,
                                         kAudioObjectPropertyElementMain};
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, NULL, &size) != noErr) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:size];
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, data.mutableBytes) != noErr) return nil;
    NSMutableArray *devices = [NSMutableArray array];
    AudioDeviceID *ids = data.mutableBytes;
    for (NSUInteger index = 0; index < size / sizeof(AudioDeviceID); index++) {
        AudioObjectPropertyAddress streams = {kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput,
                                              kAudioObjectPropertyElementMain};
        UInt32 streamSize = 0;
        if (AudioObjectGetPropertyDataSize(ids[index], &streams, 0, NULL, &streamSize) != noErr || !streamSize) continue;
        NSString *uid = deviceString(ids[index], kAudioDevicePropertyDeviceUID);
        NSString *name = deviceString(ids[index], kAudioObjectPropertyName);
        if (uid && name) [devices addObject:@{@"uid": uid, @"name": name}];
    }
    return devices;
}

typedef struct {
    AudioFileID file;
    SInt64 packet;
    _Atomic(OSStatus) error;
    _Atomic(bool) stopping;
} Recording;

static void capture(void *context, AudioQueueRef queue, AudioQueueBufferRef buffer,
                    const AudioTimeStamp *time, UInt32 packets, const AudioStreamPacketDescription *descriptions) {
    (void)time;
    (void)descriptions;
    Recording *recording = context;
    if (!packets) packets = buffer->mAudioDataByteSize / 2;
    OSStatus result = AudioFileWritePackets(recording->file, false, buffer->mAudioDataByteSize,
                                          NULL, recording->packet, &packets, buffer->mAudioData);
    recording->packet += packets;
    if (result == noErr && !atomic_load(&recording->stopping)) result = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
    if (result != noErr) atomic_store(&recording->error, result);
}

static int record(NSString *path, NSString *uid) {
    AudioStreamBasicDescription format = {
        .mSampleRate = 16000,
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
        .mBytesPerPacket = 2, .mFramesPerPacket = 1, .mBytesPerFrame = 2,
        .mChannelsPerFrame = 1, .mBitsPerChannel = 16,
    };
    Recording recording = {0};
    atomic_init(&recording.error, noErr);
    atomic_init(&recording.stopping, false);
    AudioQueueRef queue = NULL;
    OSStatus result = AudioQueueNewInput(&format, capture, &recording, NULL, NULL, 0, &queue);
    if (result == noErr && uid) {
        CFStringRef device = (__bridge CFStringRef)uid;
        result = AudioQueueSetProperty(queue, kAudioQueueProperty_CurrentDevice, &device, sizeof(device));
    }
    if (result == noErr) {
        NSURL *url = [NSURL fileURLWithPath:path];
        result = AudioFileCreateWithURL((__bridge CFURLRef)url, kAudioFileWAVEType, &format,
                                        kAudioFileFlags_EraseFile, &recording.file);
    }
    for (int index = 0; result == noErr && index < 3; index++) {
        AudioQueueBufferRef buffer;
        result = AudioQueueAllocateBuffer(queue, 1600, &buffer);
        if (result == noErr) result = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
    }
    if (result == noErr) result = AudioQueueStart(queue, NULL);
    if (result == noErr) {
        puts("READY");
        fflush(stdout);
        NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + 120;
        while (!interrupted && atomic_load(&recording.error) == noErr && NSProcessInfo.processInfo.systemUptime < deadline) {
            [NSThread sleepForTimeInterval:0.02];
        }
        atomic_store(&recording.stopping, true);
        result = AudioQueueStop(queue, true);
    }
    atomic_store(&recording.stopping, true);
    if (queue) AudioQueueDispose(queue, true);
    if (recording.file) {
        OSStatus closed = AudioFileClose(recording.file); // Finalize the WAV header.
        if (result == noErr) result = closed;
    }
    if (result == noErr) result = atomic_load(&recording.error);
    if (result != noErr) {
        fprintf(stderr, "microphone: recording failed (Core Audio error %d); check the selected input is connected.\n", (int)result);
        return 1;
    }
    return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 2 && strcmp(argv[1], "--check") == 0) return permission(NO);
        if (argc == 2 && strcmp(argv[1], "--authorize") == 0) return permission(YES);
        if (argc == 2 && strcmp(argv[1], "--list") == 0) {
            NSArray *devices = microphones();
            if (!devices) {
                fprintf(stderr, "microphone: cannot discover audio inputs\n");
                return 1;
            }
            puts("UID\tNAME");
            for (NSDictionary *device in devices) {
                printf("%s\t%s\n", [device[@"uid"] UTF8String], [device[@"name"] UTF8String]);
            }
            return 0;
        }
        NSString *selection = nil;
        const char *output = NULL;
        if (argc == 2 && argv[1][0] != '-') output = argv[1];
        if (argc == 4 && strcmp(argv[1], "--device") == 0) {
            selection = [NSString stringWithUTF8String:argv[2]];
            output = argv[3];
        }
        if (!output) {
            fprintf(stderr, "Usage: microphone [--device UID_OR_NAME] OUTPUT.wav | --list | --check | --authorize\n"
                    "Records until SIGINT/SIGTERM (maximum 120 seconds).\n"
                    "Emits READY on stdout once recording has started.\n");
            return argc == 2 && strcmp(argv[1], "--help") == 0 ? 0 : 2;
        }
        NSString *uid = nil;
        if (selection) {
            NSArray *devices = microphones();
            // Prefer an exact stable UID over a display name; reject ambiguous names.
            for (NSDictionary *device in devices) {
                if ([device[@"uid"] isEqualToString:selection]) uid = device[@"uid"];
            }
            if (!uid) {
                NSArray *matches = [devices filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", selection]];
                if (matches.count == 1) uid = matches[0][@"uid"];
            }
            if (!uid) {
                fprintf(stderr, "microphone: input '%s' not found or name is ambiguous; use --list and select a UID.\n", selection.UTF8String);
                return 1;
            }
        }
        if (permission(YES) != 0) return 1;

        signal(SIGINT, interrupt);
        signal(SIGTERM, interrupt);
        return record([NSString stringWithUTF8String:output], uid);
    }
}
