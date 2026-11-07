#import <Foundation/Foundation.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hidsystem/IOHIDLib.h>

// Observe physical HID values, not Caps Lock's latched flagsChanged state.
// Do not seize keyboards, suppress events, or modify the user's key mappings.
static NSMutableSet<NSValue *> *held;

static void emit(BOOL down) {
    puts(down ? "DOWN" : "UP");
    fflush(stdout);
}

static void input(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    (void)context;
    (void)sender;
    if (result != kIOReturnSuccess) return;
    @autoreleasepool {
        IOHIDDeviceRef device = IOHIDElementGetDevice(IOHIDValueGetElement(value));
        NSValue *key = [NSValue valueWithPointer:device];
        BOOL wasDown = held.count != 0;
        if (IOHIDValueGetIntegerValue(value)) [held addObject:key];
        else [held removeObject:key];
        if (wasDown != (held.count != 0)) emit(held.count != 0);
    }
}

static void removed(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    (void)context;
    (void)result;
    (void)sender;
    @autoreleasepool {
        BOOL wasDown = held.count != 0;
        [held removeObject:[NSValue valueWithPointer:device]];
        if (wasDown && held.count == 0) emit(NO);
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL check = argc == 2 && strcmp(argv[1], "--check") == 0;
        IOHIDAccessType access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent);
        if (check) {
            printf("Input Monitoring: %s\n", access == kIOHIDAccessTypeGranted ? "authorized" : "not-authorized");
            return access == kIOHIDAccessTypeGranted ? 0 : 1;
        }
        char *end = NULL;
        unsigned long usage = argc == 2 ? strtoul(argv[1], &end, 0) : 0;
        if (!usage || usage > 0xe7 || !end || *end) {
            fprintf(stderr, "Usage: ptt-hotkey HID_KEYBOARD_USAGE | --check\n");
            return 2;
        }
        if (access != kIOHIDAccessTypeGranted && !IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)) {
            fprintf(stderr, "push-to-talk: grant Input Monitoring access to your terminal in "
                    "System Settings > Privacy & Security, then restart the terminal.\n");
            return 1;
        }
        held = [NSMutableSet set];
        IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
        NSDictionary *keyboard = @{
            @kIOHIDDeviceUsagePageKey: @1,
            @kIOHIDDeviceUsageKey: @6,
        };
        NSDictionary *key = @{
            @kIOHIDElementUsagePageKey: @7,
            @kIOHIDElementUsageKey: @(usage),
        };
        IOHIDManagerSetDeviceMatching(manager, (__bridge CFDictionaryRef)keyboard);
        IOHIDManagerSetInputValueMatching(manager, (__bridge CFDictionaryRef)key);
        IOHIDManagerRegisterInputValueCallback(manager, input, NULL);
        IOHIDManagerRegisterDeviceRemovalCallback(manager, removed, NULL);
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        IOReturn result = IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);
        if (result != kIOReturnSuccess) {
            fprintf(stderr, "push-to-talk: cannot monitor keyboards (0x%x). Check Input Monitoring permissions.\n", result);
            CFRelease(manager);
            return 1;
        }
        CFSetRef devices = IOHIDManagerCopyDevices(manager);
        BOOL available = devices && CFSetGetCount(devices) != 0;
        if (devices) CFRelease(devices);
        if (!available) {
            fprintf(stderr, "push-to-talk: no accessible keyboard; check Input Monitoring permissions.\n");
            IOHIDManagerClose(manager, kIOHIDOptionsTypeNone);
            CFRelease(manager);
            return 1;
        }
        puts("READY");
        fflush(stdout);
        CFRunLoopRun();
        IOHIDManagerClose(manager, kIOHIDOptionsTypeNone);
        CFRelease(manager);
        return 0;
    }
}
