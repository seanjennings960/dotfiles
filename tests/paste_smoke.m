// Host-only GUI regression test: compile with -framework AppKit and pass ptt-paste.
#import <AppKit/AppKit.h>

static void stop(NSApplication *app) {
    [app stop:nil];
    // Wake -run so it observes the stop even when no more input events arrive.
    [app postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
        location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil
        subtype:0 data1:0 data2:0] atStart:NO];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *helper = [NSString stringWithUTF8String:argv[1]];
        NSString *expected = @"Push-to-talk paste test: café 🦊";
        NSRunningApplication *previous = NSWorkspace.sharedWorkspace.frontmostApplication;
        NSPasteboard *clipboard = NSPasteboard.generalPasteboard;
        NSMutableArray *saved = [NSMutableArray array];
        for (NSPasteboardItem *item in clipboard.pasteboardItems) {
            NSPasteboardItem *copy = [[NSPasteboardItem alloc] init];
            for (NSPasteboardType type in item.types) {
                NSData *data = [item dataForType:type];
                if (data) [copy setData:data forType:type];
            }
            [saved addObject:copy];
        }
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSMenu *menu = [[NSMenu alloc] init];
        NSMenuItem *edit = [[NSMenuItem alloc] init];
        edit.submenu = [[NSMenu alloc] initWithTitle:@"Edit"];
        [edit.submenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
        [menu addItem:edit];
        app.mainMenu = menu;
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(200, 200, 560, 120)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        window.title = @"Push-to-talk paste regression test";
        NSTextView *input = [[NSTextView alloc] initWithFrame:window.contentView.bounds];
        input.richText = NO;
        [window.contentView addSubview:input];
        [window makeKeyAndOrderFront:nil];
        [window makeFirstResponder:input];
        [app activateIgnoringOtherApps:YES];
        __block int result = 1;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!app.active || !window.keyWindow) {
                fprintf(stderr, "FAIL: test window could not take focus\n");
                stop(app);
                return;
            }
            NSTask *task = [[NSTask alloc] init];
            task.executableURL = [NSURL fileURLWithPath:helper];
            NSPipe *pipe = NSPipe.pipe;
            task.standardInput = pipe;
            NSError *error = nil;
            if (![task launchAndReturnError:&error]) {
                fprintf(stderr, "FAIL: %s\n", error.localizedDescription.UTF8String);
                stop(app);
                return;
            }
            [pipe.fileHandleForWriting writeData:[expected dataUsingEncoding:NSUTF8StringEncoding]];
            [pipe.fileHandleForWriting closeFile];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                result = task.running || task.terminationStatus != 0 || ![input.string isEqualToString:expected];
                if (task.running) [task terminate];
                fprintf(stderr, "%s: native paste into focused NSTextView\n", result ? "FAIL" : "PASS");
                stop(app);
            });
        });
        [app run];
        [window orderOut:nil];
        [clipboard clearContents];
        if (saved.count) [clipboard writeObjects:saved];
        [previous activateWithOptions:0];
        return result;
    }
}
