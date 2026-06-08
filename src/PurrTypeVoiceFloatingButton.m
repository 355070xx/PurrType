#import "PurrTypeVoiceFloatingButton.h"
#import "PurrTypePreferencesConstants.h"
#import <dispatch/dispatch.h>
#import <math.h>

static CGFloat const MKVoiceFloatingButtonSize = 52.0;
static CGFloat const MKVoiceFloatingButtonScreenInset = 12.0;
static NSString *const MKVoiceFloatingButtonOriginKey = @"PurrTypeVoiceFloatingButtonOrigin";
static NSString *const MKVoiceFloatingButtonOriginDidChangeNotification = @"org.purrtype.inputmethod.PurrTypeUnified.voiceFloatingButtonOriginDidChange";
static NSString *const MKVoiceFloatingButtonOriginUserInfoKey = @"origin";

@interface MKVoiceFloatingButtonView : NSView

@property(nonatomic, copy) void (^toggleHandler)(void);
@property(nonatomic, copy) void (^dragEndHandler)(NSPoint origin);
@property(nonatomic, assign) BOOL voiceInputActive;
@property(nonatomic, assign) BOOL blocked;
@property(nonatomic, assign) BOOL dragged;
@property(nonatomic, assign) NSPoint mouseDownScreenPoint;
@property(nonatomic, assign) NSPoint mouseDownFrameOrigin;
@property(nonatomic, strong) NSImage *idleImage;
@property(nonatomic, strong) NSImage *activeImage;

@end

@implementation MKVoiceFloatingButtonView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _idleImage = [self loadButtonImage];
        _activeImage = [self redVoiceButtonImageFromImage:_idleImage];
    }
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    (void)event;
    return YES;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)setVoiceInputActive:(BOOL)voiceInputActive {
    _voiceInputActive = voiceInputActive;
    [self setNeedsDisplay:YES];
}

- (void)setBlocked:(BOOL)blocked {
    _blocked = blocked;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;

    NSRect buttonBounds = [self microphoneButtonRect];
    NSImage *buttonImage = self.voiceInputActive ? self.activeImage : self.idleImage;
    if (buttonImage) {
        NSRect imageRect = [self aspectFitRectForImage:buttonImage inRect:buttonBounds];
        [buttonImage drawInRect:imageRect
                       fromRect:NSZeroRect
                      operation:NSCompositingOperationSourceOver
                       fraction:self.blocked ? 0.48 : 1.0
                 respectFlipped:YES
                          hints:@{ NSImageHintInterpolation: @(NSImageInterpolationHigh) }];
        if (self.blocked) {
            [self drawBlockedSlashInRect:NSInsetRect(imageRect, 9.0, 9.0)
                                   color:[NSColor colorWithCalibratedWhite:0.96 alpha:0.90]];
        }
        return;
    }

    [self drawFallbackButtonInRect:buttonBounds];
}

- (NSRect)microphoneButtonRect {
    return NSMakeRect(0.0, 0.0, MKVoiceFloatingButtonSize, MKVoiceFloatingButtonSize);
}

- (NSImage *)loadButtonImage {
    NSURL *imageURL = [[NSBundle mainBundle] URLForResource:@"VoiceFloatingButtonPaw" withExtension:@"png"];
    if (!imageURL) {
        return nil;
    }

    NSImage *image = [[NSImage alloc] initWithContentsOfURL:imageURL];
    NSImageRep *imageRep = image.representations.firstObject;
    if (imageRep.pixelsWide > 0 && imageRep.pixelsHigh > 0) {
        image.size = NSMakeSize(imageRep.pixelsWide, imageRep.pixelsHigh);
    }
    return image;
}

- (NSRect)aspectFitRectForImage:(NSImage *)image inRect:(NSRect)bounds {
    if (image.size.width <= 0.0 || image.size.height <= 0.0) {
        return bounds;
    }

    CGFloat scale = MIN(NSWidth(bounds) / image.size.width, NSHeight(bounds) / image.size.height);
    NSSize size = NSMakeSize(image.size.width * scale, image.size.height * scale);
    return NSMakeRect(NSMidX(bounds) - size.width / 2.0,
                      NSMidY(bounds) - size.height / 2.0,
                      size.width,
                      size.height);
}

- (NSImage *)redVoiceButtonImageFromImage:(NSImage *)image {
    NSBitmapImageRep *sourceRep = [self bitmapRepresentationForImage:image];
    if (!sourceRep) {
        return image;
    }

    NSInteger width = sourceRep.pixelsWide;
    NSInteger height = sourceRep.pixelsHigh;
    NSBitmapImageRep *outputRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                          pixelsWide:width
                                                                          pixelsHigh:height
                                                                       bitsPerSample:8
                                                                     samplesPerPixel:4
                                                                            hasAlpha:YES
                                                                            isPlanar:NO
                                                                      colorSpaceName:NSCalibratedRGBColorSpace
                                                                         bytesPerRow:0
                                                                        bitsPerPixel:0];
    for (NSInteger y = 0; y < height; y++) {
        for (NSInteger x = 0; x < width; x++) {
            NSColor *sourceColor = [[sourceRep colorAtX:x y:y] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
            if (!sourceColor) {
                sourceColor = [sourceRep colorAtX:x y:y];
            }
            CGFloat red = 0.0;
            CGFloat green = 0.0;
            CGFloat blue = 0.0;
            CGFloat alpha = 0.0;
            [sourceColor getRed:&red green:&green blue:&blue alpha:&alpha];
            if ([self shouldTintFacePixelRedWithRed:red green:green blue:blue alpha:alpha]) {
                CGFloat luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
                CGFloat shade = MIN(MAX((luminance - 0.18) / 0.58, 0.0), 1.0);
                red = 0.50 + 0.36 * shade;
                green = 0.05 + 0.13 * shade;
                blue = 0.06 + 0.09 * shade;
            }
            NSColor *outputColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
            [outputRep setColor:outputColor atX:x y:y];
        }
    }

    NSImage *outputImage = [[NSImage alloc] initWithSize:image.size];
    [outputImage addRepresentation:outputRep];
    return outputImage;
}

- (NSBitmapImageRep *)bitmapRepresentationForImage:(NSImage *)image {
    if (!image) {
        return nil;
    }

    NSInteger width = MAX((NSInteger)lrint(image.size.width), 1);
    NSInteger height = MAX((NSInteger)lrint(image.size.height), 1);
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                          pixelsWide:width
                                                                          pixelsHigh:height
                                                                       bitsPerSample:8
                                                                     samplesPerPixel:4
                                                                            hasAlpha:YES
                                                                            isPlanar:NO
                                                                      colorSpaceName:NSCalibratedRGBColorSpace
                                                                         bytesPerRow:0
                                                                        bitsPerPixel:0];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmapRep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [image drawInRect:NSMakeRect(0.0, 0.0, width, height)
             fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver
             fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    return bitmapRep;
}

- (BOOL)shouldTintFacePixelRedWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha {
    if (alpha < 0.12) {
        return NO;
    }
    BOOL blueDominant = blue > red + 0.08 && green > red + 0.02;
    BOOL faceRange = red < 0.52 && green > 0.14 && blue > 0.24;
    BOOL notNeutral = fabs(red - green) > 0.04 || fabs(green - blue) > 0.04;
    return blueDominant && faceRange && notNeutral;
}

- (void)drawFallbackButtonInRect:(NSRect)bounds {
    NSRect rimRect = NSInsetRect(bounds, 3.0, 3.0);
    NSRect faceRect = NSInsetRect(rimRect, 5.0, 5.0);
    [[NSColor colorWithCalibratedRed:0.97 green:0.94 blue:0.84 alpha:0.98] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:rimRect] fill];
    NSColor *faceColor = self.blocked ?
        [NSColor colorWithCalibratedWhite:0.54 alpha:0.95] :
        (self.voiceInputActive ?
            [NSColor colorWithCalibratedRed:0.76 green:0.10 blue:0.10 alpha:0.98] :
            [NSColor colorWithCalibratedRed:0.20 green:0.38 blue:0.52 alpha:0.98]);
    [faceColor setFill];
    [[NSBezierPath bezierPathWithOvalInRect:faceRect] fill];
}

- (void)drawBlockedSlashInRect:(NSRect)bounds color:(NSColor *)color {
    NSBezierPath *slash = [NSBezierPath bezierPath];
    slash.lineWidth = 2.4;
    slash.lineCapStyle = NSLineCapStyleRound;
    [color setStroke];
    [slash moveToPoint:NSMakePoint(NSMidX(bounds) - 12.0, NSMinY(bounds) + 34.0)];
    [slash lineToPoint:NSMakePoint(NSMidX(bounds) + 12.0, NSMinY(bounds) + 10.0)];
    [slash stroke];
}

- (void)mouseDown:(NSEvent *)event {
    (void)event;
    self.dragged = NO;
    self.mouseDownScreenPoint = [NSEvent mouseLocation];
    self.mouseDownFrameOrigin = self.window.frame.origin;
}

- (void)mouseDragged:(NSEvent *)event {
    (void)event;
    NSPoint currentPoint = [NSEvent mouseLocation];
    CGFloat deltaX = currentPoint.x - self.mouseDownScreenPoint.x;
    CGFloat deltaY = currentPoint.y - self.mouseDownScreenPoint.y;
    if (fabs(deltaX) > 2.0 || fabs(deltaY) > 2.0) {
        self.dragged = YES;
    }
    NSPoint nextOrigin = NSMakePoint(self.mouseDownFrameOrigin.x + deltaX,
                                    self.mouseDownFrameOrigin.y + deltaY);
    [self.window setFrameOrigin:nextOrigin];
}

- (void)mouseUp:(NSEvent *)event {
    if (self.dragged) {
        if (self.dragEndHandler) {
            self.dragEndHandler(self.window.frame.origin);
        }
        return;
    }

    if (!self.blocked && self.toggleHandler) {
        self.toggleHandler();
    }
}

@end

@interface PurrTypeVoiceFloatingButton ()

@property(nonatomic, strong) NSPanel *panel;
@property(nonatomic, strong) MKVoiceFloatingButtonView *buttonView;
@property(nonatomic, strong) NSUserDefaults *defaults;
@property(nonatomic, assign) BOOL voiceInputActive;
@property(nonatomic, assign) BOOL blocked;
@property(nonatomic, copy) NSString *statusTitle;
@property(nonatomic, assign) BOOL hasAppliedInitialFrame;
@property(nonatomic, copy) NSString *lastAppliedSavedOriginString;

@end

@implementation PurrTypeVoiceFloatingButton

+ (instancetype)sharedButton {
    static PurrTypeVoiceFloatingButton *button = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        button = [[PurrTypeVoiceFloatingButton alloc] init];
    });
    return button;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:MKUserDefaultsSuiteName];
        _statusTitle = @"Voice Input: Ready";

        _buttonView = [[MKVoiceFloatingButtonView alloc] initWithFrame:NSMakeRect(0.0, 0.0, MKVoiceFloatingButtonSize, MKVoiceFloatingButtonSize)];
        _buttonView.wantsLayer = YES;
        __weak PurrTypeVoiceFloatingButton *weakSelf = self;
        _buttonView.toggleHandler = ^{
            PurrTypeVoiceFloatingButton *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf.delegate voiceFloatingButtonDidRequestToggle:strongSelf];
        };
        _buttonView.dragEndHandler = ^(NSPoint origin) {
            PurrTypeVoiceFloatingButton *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf savePanelOrigin:[strongSelf clampedOriginForOrigin:origin]];
        };

        _panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0.0, 0.0, MKVoiceFloatingButtonSize, MKVoiceFloatingButtonSize)
                                           styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                                             backing:NSBackingStoreBuffered
                                               defer:NO];
        _panel.contentView = _buttonView;
        _panel.opaque = NO;
        _panel.backgroundColor = [NSColor clearColor];
        _panel.hasShadow = NO;
        _panel.level = NSPopUpMenuWindowLevel;
        _panel.ignoresMouseEvents = NO;
        _panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                    NSWindowCollectionBehaviorFullScreenAuxiliary |
                                    NSWindowCollectionBehaviorTransient;

        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(handleSavedOriginDidChange:)
                                                                name:MKVoiceFloatingButtonOriginDidChangeNotification
                                                              object:nil
                                                  suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
        [self updateToolTip];
    }
    return self;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)show {
    NSString *savedOriginString = [self savedOriginString];
    BOOL savedOriginChanged = savedOriginString.length > 0 &&
                              ![savedOriginString isEqualToString:self.lastAppliedSavedOriginString ?: @""];
    if (!self.hasAppliedInitialFrame || savedOriginChanged) {
        NSPoint origin = savedOriginString.length > 0 ? NSPointFromString(savedOriginString) : [self defaultOrigin];
        [self applyPanelFrameForButtonOrigin:[self clampedOriginForOrigin:origin]
                                     display:NO
                           savedOriginString:savedOriginString];
    }
    [self.panel orderFrontRegardless];
}

- (void)handleSavedOriginDidChange:(NSNotification *)notification {
    void (^applyOrigin)(void) = ^{
        NSString *originString = nil;
        id notificationOrigin = notification.userInfo[MKVoiceFloatingButtonOriginUserInfoKey];
        if ([notificationOrigin isKindOfClass:[NSString class]]) {
            originString = notificationOrigin;
        }
        if (![self originStringIsValid:originString]) {
            originString = [self savedOriginString];
        }
        if (originString.length == 0 ||
            [originString isEqualToString:self.lastAppliedSavedOriginString ?: @""]) {
            return;
        }
        [self applyPanelFrameForSavedOriginString:originString display:self.panel.isVisible];
    };
    if ([NSThread isMainThread]) {
        applyOrigin();
    } else {
        dispatch_async(dispatch_get_main_queue(), applyOrigin);
    }
}

- (void)hide {
    [self.panel orderOut:nil];
}

- (BOOL)isVisible {
    return self.panel.isVisible;
}

- (NSRect)screenFrame {
    return self.panel.frame;
}

- (void)setVoiceInputActive:(BOOL)active blocked:(BOOL)blocked statusTitle:(NSString *)statusTitle {
    self.voiceInputActive = active;
    self.blocked = blocked;
    self.statusTitle = statusTitle.length > 0 ? statusTitle : @"Voice Input: Ready";
    self.buttonView.voiceInputActive = active;
    self.buttonView.blocked = blocked;
    [self updateToolTip];
}

- (void)updateToolTip {
    NSString *action = self.blocked ? @"Unavailable" : (self.voiceInputActive ? @"Click to stop" : @"Click to start");
    self.buttonView.toolTip = [NSString stringWithFormat:@"Voice Input - %@\n%@", action, self.statusTitle ?: @""];
}

- (NSString *)savedOriginString {
    [self.defaults synchronize];
    NSString *savedValue = [self.defaults stringForKey:MKVoiceFloatingButtonOriginKey];
    if ([self originStringIsValid:savedValue]) {
        return savedValue;
    }
    return nil;
}

- (BOOL)originStringIsValid:(NSString *)originString {
    if (originString.length == 0) {
        return NO;
    }
    NSPoint origin = NSPointFromString(originString);
    return isfinite(origin.x) && isfinite(origin.y);
}

- (NSPoint)defaultOrigin {
    NSScreen *screen = [NSScreen mainScreen];
    NSRect visibleFrame = screen.visibleFrame;
    return NSMakePoint(NSMaxX(visibleFrame) - MKVoiceFloatingButtonSize - 28.0,
                       NSMinY(visibleFrame) + 140.0);
}

- (void)savePanelOrigin:(NSPoint)origin {
    NSPoint clampedOrigin = [self clampedOriginForOrigin:origin];
    NSString *originString = NSStringFromPoint(clampedOrigin);
    [self applyPanelFrameForButtonOrigin:clampedOrigin display:YES savedOriginString:originString];
    [self.defaults setObject:originString forKey:MKVoiceFloatingButtonOriginKey];
    [self.defaults synchronize];
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:MKVoiceFloatingButtonOriginDidChangeNotification
                                                                  object:nil
                                                                userInfo:@{ MKVoiceFloatingButtonOriginUserInfoKey: originString }
                                                      deliverImmediately:YES];
}

- (void)applyPanelFrameForSavedOriginString:(NSString *)originString display:(BOOL)display {
    if (![self originStringIsValid:originString]) {
        return;
    }
    [self applyPanelFrameForButtonOrigin:[self clampedOriginForOrigin:NSPointFromString(originString)]
                                 display:display
                       savedOriginString:originString];
}

- (void)applyPanelFrameForButtonOrigin:(NSPoint)buttonOrigin display:(BOOL)display savedOriginString:(NSString *)savedOriginString {
    NSRect frame = NSMakeRect(buttonOrigin.x,
                              buttonOrigin.y,
                              MKVoiceFloatingButtonSize,
                              MKVoiceFloatingButtonSize);
    [self.panel setFrame:frame display:display];
    self.hasAppliedInitialFrame = YES;
    self.lastAppliedSavedOriginString = savedOriginString;
    self.buttonView.frame = NSMakeRect(0.0, 0.0, NSWidth(frame), NSHeight(frame));
    [self.buttonView setNeedsDisplay:YES];
}

- (NSPoint)clampedOriginForOrigin:(NSPoint)origin {
    NSScreen *screen = [self screenForOrigin:origin] ?: [NSScreen mainScreen];
    NSRect visibleFrame = screen.visibleFrame;
    CGFloat minX = NSMinX(visibleFrame) + MKVoiceFloatingButtonScreenInset;
    CGFloat maxX = NSMaxX(visibleFrame) - MKVoiceFloatingButtonSize - MKVoiceFloatingButtonScreenInset;
    CGFloat minY = NSMinY(visibleFrame) + MKVoiceFloatingButtonScreenInset;
    CGFloat maxY = NSMaxY(visibleFrame) - MKVoiceFloatingButtonSize - MKVoiceFloatingButtonScreenInset;
    return NSMakePoint(MIN(MAX(origin.x, minX), maxX), MIN(MAX(origin.y, minY), maxY));
}

- (NSScreen *)screenForOrigin:(NSPoint)origin {
    NSPoint center = NSMakePoint(origin.x + MKVoiceFloatingButtonSize / 2.0,
                                origin.y + MKVoiceFloatingButtonSize / 2.0);
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(center, screen.frame)) {
            return screen;
        }
    }
    return nil;
}

@end
