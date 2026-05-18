#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>

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

static void PrintSource(TISInputSourceRef source) {
    NSString *identifier = StringProperty(source, kTISPropertyInputSourceID);
    NSString *name = StringProperty(source, kTISPropertyLocalizedName);
    NSString *bundleID = StringProperty(source, kTISPropertyBundleID);
    NSString *category = StringProperty(source, kTISPropertyInputSourceCategory);
    NSString *type = StringProperty(source, kTISPropertyInputSourceType);
    NSString *asciiCapable = StringProperty(source, kTISPropertyInputSourceIsASCIICapable);
    NSString *enabled = StringProperty(source, kTISPropertyInputSourceIsEnabled);
    NSString *enableCapable = StringProperty(source, kTISPropertyInputSourceIsEnableCapable);
    NSString *selectCapable = StringProperty(source, kTISPropertyInputSourceIsSelectCapable);
    NSString *selected = StringProperty(source, kTISPropertyInputSourceIsSelected);
    NSString *languages = StringProperty(source, kTISPropertyInputSourceLanguages);
    NSString *modeID = StringProperty(source, kTISPropertyInputModeID);

    printf("id=%s name=%s bundleID=%s category=%s type=%s asciiCapable=%s enabled=%s enableCapable=%s selectCapable=%s selected=%s modeID=%s languages=%s\n",
           identifier.UTF8String,
           name.UTF8String,
           bundleID.UTF8String,
           category.UTF8String,
           type.UTF8String,
           asciiCapable.UTF8String,
           enabled.UTF8String,
           enableCapable.UTF8String,
           selectCapable.UTF8String,
           selected.UTF8String,
           modeID.UTF8String,
           languages.UTF8String);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "Usage: TISProbe <input-source-id>\n");
            return 2;
        }

        NSString *sourceID = [NSString stringWithUTF8String:argv[1]];
        NSMutableArray *matches = [NSMutableArray array];

        for (NSUInteger attempt = 0; attempt < 20; attempt++) {
            [matches removeAllObjects];
            CFArrayRef listRef = TISCreateInputSourceList(NULL, true);
            NSArray *sources = CFBridgingRelease(listRef);
            if (!sources) {
                sources = @[];
            }

            for (id item in sources) {
                TISInputSourceRef source = (__bridge TISInputSourceRef)item;
                NSString *identifier = StringProperty(source, kTISPropertyInputSourceID);
                if (![identifier isEqualToString:sourceID]) {
                    continue;
                }

                [matches addObject:item];
            }

            if (matches.count > 0) {
                break;
            }

            [NSThread sleepForTimeInterval:0.25];
        }

        for (id item in matches) {
            TISInputSourceRef source = (__bridge TISInputSourceRef)item;
            PrintSource(source);
        }

        printf("count=%lu\n", (unsigned long)matches.count);
        return matches.count == 0 ? 1 : 0;
    }
}
