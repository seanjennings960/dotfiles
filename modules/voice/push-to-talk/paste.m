#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

static int permission(BOOL request) {
    BOOL trusted;
    if (request) {
        NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
        trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    } else {
        trusted = AXIsProcessTrusted();
        printf("Accessibility: %s\n", trusted ? "authorized" : "not-authorized");
    }
    if (!trusted && request) {
        fprintf(stderr, "push-to-talk: --paste requires Accessibility access. Enable your terminal "
                "in System Settings > Privacy & Security > Accessibility, then restart it.\n");
    }
    return trusted ? 0 : 1;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 2 && strcmp(argv[1], "--check") == 0) return permission(NO);
        if (argc == 2 && strcmp(argv[1], "--authorize") == 0) return permission(YES);
        if (argc != 1) {
            fprintf(stderr, "Usage: ptt-paste [--check | --authorize] (reads UTF-8 text from stdin)\n");
            return 2;
        }
        // Recheck without prompting before every paste; do not change the clipboard if denied.
        if (!AXIsProcessTrusted()) {
            fprintf(stderr, "push-to-talk: Accessibility access is required to paste.\n");
            return 1;
        }
        NSData *data = [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!text) {
            fprintf(stderr, "push-to-talk: paste input is not valid UTF-8\n");
            return 1;
        }
        if (text.length == 0) return 0;
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStatePrivate);
        CGEventRef down = source ? CGEventCreateKeyboardEvent(source, 9, true) : NULL;
        CGEventRef up = source ? CGEventCreateKeyboardEvent(source, 9, false) : NULL;
        if (!down || !up) {
            if (down) CFRelease(down);
            if (up) CFRelease(up);
            if (source) CFRelease(source);
            fprintf(stderr, "push-to-talk: cannot create paste shortcut\n");
            return 1;
        }
        NSPasteboard *clipboard = NSPasteboard.generalPasteboard;
        [clipboard clearContents];
        BOOL written = [clipboard setString:text forType:NSPasteboardTypeString];
        if (written) {
            // Set flags explicitly so a held modifier/Caps Lock cannot alter the shortcut.
            CGEventSetFlags(down, kCGEventFlagMaskCommand);
            CGEventSetFlags(up, kCGEventFlagMaskCommand);
            CGEventPost(kCGHIDEventTap, down);
            [NSThread sleepForTimeInterval:0.02];
            CGEventPost(kCGHIDEventTap, up);
            // Posting is asynchronous. Keep the sender alive while macOS dispatches
            // the events; exiting immediately can cause them to be dropped.
            [NSThread sleepForTimeInterval:0.2];
        } else {
            fprintf(stderr, "push-to-talk: cannot write transcript to the clipboard\n");
        }
        CFRelease(down);
        CFRelease(up);
        CFRelease(source);
        return written ? 0 : 1;
    }
}
