#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <InputMethodKit/InputMethodKit.h>
#import <string.h>

static IMKServer *PurrTypeServer;

static BOOL HasArgument(int argc, const char *argv[], const char *argument) {
    for (int index = 1; index < argc; index += 1) {
        if (strcmp(argv[index], argument) == 0) {
            return YES;
        }
    }
    return NO;
}

static BOOL BundleIsInInputMethodsDirectory(NSURL *bundleURL) {
    NSString *path = bundleURL.path.stringByStandardizingPath;
    NSString *systemInputMethodsPath = @"/Library/Input Methods/";
    NSString *userInputMethodsPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Input Methods"] stringByAppendingString:@"/"];
    return [path hasPrefix:systemInputMethodsPath] || [path hasPrefix:userInputMethodsPath];
}

static int RegisterInputSource(void) {
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    if (!BundleIsInInputMethodsDirectory(bundleURL)) {
        NSLog(@"PurrType refusing to register input source from invalid location path=%@", bundleURL.path ?: @"");
        return paramErr;
    }

    OSStatus status = TISRegisterInputSource((__bridge CFURLRef)bundleURL);
    if (status != noErr) {
        NSLog(@"PurrType register-input-source failed status=%d", (int)status);
        return (int)status;
    }
    return 0;
}

static NSString *StringProperty(TISInputSourceRef source, CFStringRef key) {
    CFTypeRef value = TISGetInputSourceProperty(source, key);
    if (!value) {
        return @"";
    }
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        return (__bridge NSString *)value;
    }
    if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        return CFBooleanGetValue(value) ? @"true" : @"false";
    }
    return [(__bridge id)value description];
}

static NSString *PrimaryInputSourceID(void) {
    NSString *sourceID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TISInputSourceID"];
    if (sourceID.length == 0) {
        NSLog(@"PurrType missing TISInputSourceID");
    }
    return sourceID ?: @"";
}

static TISInputSourceRef CopyInputSourceWithID(NSString *sourceID, BOOL includeAllInstalled) {
    if (sourceID.length == 0) {
        return NULL;
    }

    NSDictionary *filter = @{ (__bridge NSString *)kTISPropertyInputSourceID: sourceID };
    CFArrayRef listRef = TISCreateInputSourceList((__bridge CFDictionaryRef)filter, includeAllInstalled);
    NSArray *sources = CFBridgingRelease(listRef);
    if (sources.count == 0) {
        return NULL;
    }

    return (__bridge_retained TISInputSourceRef)sources.firstObject;
}

static TISInputSourceRef CopyInputSourceWithIDIncludingInstalled(NSString *sourceID) {
    TISInputSourceRef source = CopyInputSourceWithID(sourceID, false);
    if (source) {
        return source;
    }

    source = CopyInputSourceWithID(sourceID, true);
    if (!source) {
        NSLog(@"PurrType input source not found id=%@", sourceID ?: @"");
    }
    return source;
}

static TISInputSourceRef CopyInputSource(void) {
    return CopyInputSourceWithIDIncludingInstalled(PrimaryInputSourceID());
}

static void PrintInputSource(NSString *label, TISInputSourceRef source) {
    if (label.length > 0) {
        printf("[%s]\n", label.UTF8String);
    }
    printf("id=%s\n", StringProperty(source, kTISPropertyInputSourceID).UTF8String);
    printf("name=%s\n", StringProperty(source, kTISPropertyLocalizedName).UTF8String);
    printf("bundleID=%s\n", StringProperty(source, kTISPropertyBundleID).UTF8String);
    printf("category=%s\n", StringProperty(source, kTISPropertyInputSourceCategory).UTF8String);
    printf("type=%s\n", StringProperty(source, kTISPropertyInputSourceType).UTF8String);
    printf("asciiCapable=%s\n", StringProperty(source, kTISPropertyInputSourceIsASCIICapable).UTF8String);
    printf("languages=%s\n", StringProperty(source, kTISPropertyInputSourceLanguages).UTF8String);
    printf("enabled=%s\n", StringProperty(source, kTISPropertyInputSourceIsEnabled).UTF8String);
    printf("enableCapable=%s\n", StringProperty(source, kTISPropertyInputSourceIsEnableCapable).UTF8String);
    printf("selectCapable=%s\n", StringProperty(source, kTISPropertyInputSourceIsSelectCapable).UTF8String);
    printf("selected=%s\n", StringProperty(source, kTISPropertyInputSourceIsSelected).UTF8String);
}

static int InspectInputSource(void) {
    TISInputSourceRef source = CopyInputSource();
    if (!source) {
        return 1;
    }

    PrintInputSource(@"parent", source);
    CFRelease(source);
    return 0;
}

static int EnableSourceID(NSString *sourceID) {
    TISInputSourceRef source = CopyInputSourceWithIDIncludingInstalled(sourceID);
    if (!source) {
        return 1;
    }

    OSStatus status = TISEnableInputSource(source);
    CFRelease(source);
    if (status != noErr) {
        NSLog(@"PurrType enable-input-source failed id=%@ status=%d", sourceID ?: @"", (int)status);
        return (int)status;
    }
    return 0;
}

static int EnableConfiguredInputSources(void) {
    int registerStatus = RegisterInputSource();
    if (registerStatus != 0) {
        return registerStatus;
    }

    int status = EnableSourceID(PrimaryInputSourceID());
    if (status != 0) {
        return status;
    }

    return 0;
}

static int EnableInputSource(void) {
    int status = EnableConfiguredInputSources();
    if (status != 0) {
        return status;
    }
    return InspectInputSource();
}

static int SelectInputSource(void) {
    int enableStatus = EnableConfiguredInputSources();
    if (enableStatus != 0) {
        return enableStatus;
    }

    NSString *selectableID = PrimaryInputSourceID();
    TISInputSourceRef source = CopyInputSourceWithIDIncludingInstalled(selectableID);
    if (!source) {
        return 1;
    }

    OSStatus selectStatus = TISSelectInputSource(source);
    if (selectStatus != noErr) {
        NSLog(@"PurrType select-input-source failed id=%@ status=%d", selectableID ?: @"", (int)selectStatus);
        CFRelease(source);
        return (int)selectStatus;
    }

    CFRelease(source);
    return InspectInputSource();
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (HasArgument(argc, argv, "--register-input-source")) {
            return RegisterInputSource();
        }
        if (HasArgument(argc, argv, "--inspect-input-source")) {
            return InspectInputSource();
        }
        if (HasArgument(argc, argv, "--enable-input-source")) {
            return EnableInputSource();
        }
        if (HasArgument(argc, argv, "--select-input-source")) {
            return SelectInputSource();
        }

        NSBundle *bundle = [NSBundle mainBundle];
        NSString *bundleIdentifier = bundle.bundleIdentifier;
        NSString *connectionName = [bundle objectForInfoDictionaryKey:@"InputMethodConnectionName"];

        PurrTypeServer = [[IMKServer alloc] initWithName:connectionName bundleIdentifier:bundleIdentifier];
        [NSApplication sharedApplication];
        [NSApp run];
    }

    return 0;
}
