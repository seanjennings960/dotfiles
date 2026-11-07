#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#include <signal.h>

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

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || strcmp(argv[1], "--help") == 0) {
            fprintf(stderr, "Usage: microphone OUTPUT.wav | --check | --authorize\n"
                    "Records until SIGINT/SIGTERM (maximum 120 seconds).\n"
                    "Emits READY on stdout once recording has started.\n");
            return argc == 2 ? 0 : 2;
        }
        if (strcmp(argv[1], "--check") == 0) return permission(NO);
        if (strcmp(argv[1], "--authorize") == 0) return permission(YES);
        if (permission(YES) != 0) return 1;

        signal(SIGINT, interrupt);
        signal(SIGTERM, interrupt);
        NSError *error = nil;
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSDictionary *settings = @{
            AVFormatIDKey: @(kAudioFormatLinearPCM),
            AVSampleRateKey: @16000,
            AVNumberOfChannelsKey: @1,
            AVLinearPCMBitDepthKey: @16,
            AVLinearPCMIsFloatKey: @NO,
            AVLinearPCMIsBigEndianKey: @NO,
        };
        AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
        if (!recorder || ![recorder recordForDuration:120]) {
            fprintf(stderr, "microphone: cannot start the default input: %s\n",
                    error ? error.localizedDescription.UTF8String : "no available microphone");
            return 1;
        }
        puts("READY");
        fflush(stdout);
        while (!interrupted && recorder.isRecording) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
        [recorder stop]; // Finalize the WAV header before the caller transcribes it.
        return 0;
    }
}
