#import "PurrTypeCandidatePanel.h"
#include <math.h>

static const CGFloat MKCandidatePanelRowHeight = 21.0;
static const CGFloat MKCandidatePanelVerticalInset = 4.0;
static const CGFloat MKCandidatePanelHorizontalInset = 4.0;
static const CGFloat MKCandidatePanelHeaderHeight = 18.0;
static const CGFloat MKCandidatePanelMinWidth = 86.0;
static const CGFloat MKCandidatePanelMaxWidth = 154.0;
static const CGFloat MKCandidatePanelScreenMargin = 8.0;
static const CGFloat MKCandidatePanelDefaultAnchorHeight = 22.0;
static const CGFloat MKCandidatePanelCaretHorizontalGap = 4.0;
static const CGFloat MKCandidatePanelCaretVerticalGap = 4.0;

@protocol PurrTypeLineHeightAnchorClient <NSObject>
- (NSDictionary *)attributesForCharacterIndex:(NSUInteger)index lineHeightRectangle:(NSRectPointer)lineHeightRect;
@end

@interface MKCandidatePanelView : NSView
@property(nonatomic, copy) NSArray<NSString *> *candidateTexts;
@property(nonatomic, copy) NSString *pageIndicatorText;
@property(nonatomic, copy) void (^selectionHandler)(NSPoint point);
@end

@implementation MKCandidatePanelView

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = self.bounds;
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 0.5, 0.5)
                                                               xRadius:12.0
                                                               yRadius:12.0];
    [[NSColor colorWithCalibratedWhite:0.04 alpha:0.88] setFill];
    [background fill];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.22] setStroke];
    [background setLineWidth:1.0];
    [background stroke];

    NSDictionary<NSAttributedStringKey, id> *normalAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:17.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.92 alpha:1.0]
    };
    NSDictionary<NSAttributedStringKey, id> *selectedAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:17.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSDictionary<NSAttributedStringKey, id> *pageAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.82 alpha:1.0]
    };

    CGFloat contentTop = 0.0;
    if (self.pageIndicatorText.length > 0) {
        NSString *pageText = self.pageIndicatorText ?: @"";
        NSSize pageTextSize = [pageText sizeWithAttributes:pageAttributes];
        NSRect pageTextRect = NSMakeRect(NSWidth(bounds) - pageTextSize.width - 10.0,
                                         floor((MKCandidatePanelHeaderHeight - pageTextSize.height) / 2.0),
                                         pageTextSize.width,
                                         pageTextSize.height + 1.0);
        [pageText drawInRect:pageTextRect withAttributes:pageAttributes];

        NSBezierPath *headerLine = [NSBezierPath bezierPath];
        [headerLine moveToPoint:NSMakePoint(8.0, MKCandidatePanelHeaderHeight - 0.5)];
        [headerLine lineToPoint:NSMakePoint(NSWidth(bounds) - 8.0, MKCandidatePanelHeaderHeight - 0.5)];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.10] setStroke];
        [headerLine setLineWidth:1.0];
        [headerLine stroke];
        contentTop = MKCandidatePanelHeaderHeight;
    }

    for (NSUInteger index = 0; index < self.candidateTexts.count; index += 1) {
        CGFloat y = contentTop + MKCandidatePanelVerticalInset + (CGFloat)index * MKCandidatePanelRowHeight;
        NSRect rowRect = NSMakeRect(MKCandidatePanelHorizontalInset,
                                    y,
                                    NSWidth(bounds) - MKCandidatePanelHorizontalInset * 2.0,
                                    MKCandidatePanelRowHeight);
        BOOL selected = (index == 0);
        if (selected) {
            NSBezierPath *selection = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rowRect, 0.0, 1.0)
                                                                      xRadius:10.0
                                                                      yRadius:10.0];
            [[NSColor colorWithCalibratedRed:1.0 green:0.31 blue:0.34 alpha:1.0] setFill];
            [selection fill];
        }

        NSString *text = self.candidateTexts[index] ?: @"";
        NSDictionary<NSAttributedStringKey, id> *attributes = selected ? selectedAttributes : normalAttributes;
        NSSize textSize = [text sizeWithAttributes:attributes];
        NSRect textRect = NSMakeRect(NSMinX(rowRect) + 8.0,
                                     NSMinY(rowRect) + floor((NSHeight(rowRect) - textSize.height) / 2.0) - 1.0,
                                     NSWidth(rowRect) - 16.0,
                                     textSize.height + 2.0);
        [text drawInRect:textRect withAttributes:attributes];

        if (!selected && index + 1 < self.candidateTexts.count) {
            CGFloat lineY = NSMaxY(rowRect) - 0.5;
            NSBezierPath *separator = [NSBezierPath bezierPath];
            [separator moveToPoint:NSMakePoint(NSMinX(rowRect) + 8.0, lineY)];
            [separator lineToPoint:NSMakePoint(NSMaxX(rowRect) - 8.0, lineY)];
            [[NSColor colorWithCalibratedWhite:1.0 alpha:0.10] setStroke];
            [separator setLineWidth:1.0];
            [separator stroke];
        }
    }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    (void)event;
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    if (!self.selectionHandler) {
        return;
    }
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    self.selectionHandler(point);
}

@end

@interface PurrTypeCandidatePanel ()
@property(nonatomic, strong) NSPanel *panel;
@property(nonatomic, strong) MKCandidatePanelView *panelView;
@property(nonatomic, assign) BOOL hasLastAnchorRect;
@property(nonatomic, assign) NSRect lastAnchorRect;
@property(nonatomic, weak) id lastAnchorClient;
@end

@implementation PurrTypeCandidatePanel

- (instancetype)init {
    self = [super init];
    if (self) {
        _panelView = [[MKCandidatePanelView alloc] initWithFrame:NSZeroRect];
        _panelView.wantsLayer = YES;
        __weak typeof(self) weakSelf = self;
        _panelView.selectionHandler = ^(NSPoint point) {
            [weakSelf selectCandidateAtPanelPoint:point];
        };

        _panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, MKCandidatePanelMinWidth, 80)
                                             styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
        _panel.contentView = _panelView;
        _panel.opaque = NO;
        _panel.backgroundColor = [NSColor clearColor];
        _panel.hasShadow = YES;
        _panel.level = NSPopUpMenuWindowLevel;
        _panel.ignoresMouseEvents = NO;
        _panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                    NSWindowCollectionBehaviorFullScreenAuxiliary |
                                    NSWindowCollectionBehaviorTransient;
    }
    return self;
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts nearClient:(id)client {
    [self showCandidates:candidateTexts nearClient:client anchorCharacterIndex:nil];
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex {
    [self showCandidates:candidateTexts
              nearClient:client
    anchorCharacterIndex:anchorCharacterIndex
               pageIndex:0
               pageCount:0];
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex
             pageIndex:(NSUInteger)pageIndex
             pageCount:(NSUInteger)pageCount {
    [self showCandidates:candidateTexts
              nearClient:client
    anchorCharacterIndex:anchorCharacterIndex
               pageIndex:pageIndex
               pageCount:pageCount
      usePreservedAnchor:NO];
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex
             pageIndex:(NSUInteger)pageIndex
             pageCount:(NSUInteger)pageCount
    usePreservedAnchor:(BOOL)usePreservedAnchor {
    if (candidateTexts.count == 0) {
        [self hide];
        return;
    }

    self.panelView.candidateTexts = [candidateTexts copy];
    NSString *pageIndicatorText = pageCount > 1 ? [NSString stringWithFormat:@"%lu/%lu",
                                                   (unsigned long)(pageIndex + 1),
                                                   (unsigned long)pageCount] : @"";
    self.panelView.pageIndicatorText = pageIndicatorText;
    NSSize panelSize = [self preferredSizeForCandidates:candidateTexts pageIndicatorText:pageIndicatorText];
    NSRect anchorRect = NSZeroRect;
    if (![self resolveAnchorRect:&anchorRect
                       forClient:client
            anchorCharacterIndex:anchorCharacterIndex
               usePreservedAnchor:usePreservedAnchor]) {
        [self hide];
        return;
    }

    NSRect frame = [self frameForPanelSize:panelSize anchorRect:anchorRect];
    [self.panel setFrame:frame display:NO];
    [self.panelView setFrame:NSMakeRect(0, 0, panelSize.width, panelSize.height)];
    [self.panelView setNeedsDisplay:YES];
    [self.panel orderFrontRegardless];
}

- (void)hide {
    [self.panel orderOut:nil];
}

- (void)beginAnchorSessionForClient:(id)client {
    self.hasLastAnchorRect = NO;
    self.lastAnchorRect = NSZeroRect;
    self.lastAnchorClient = client;
}

- (void)clearAnchorSession {
    self.hasLastAnchorRect = NO;
    self.lastAnchorRect = NSZeroRect;
    self.lastAnchorClient = nil;
}

- (BOOL)isVisible {
    return self.panel.isVisible;
}

- (NSSize)preferredSizeForCandidates:(NSArray<NSString *> *)candidateTexts {
    return [self preferredSizeForCandidates:candidateTexts pageIndicatorText:@""];
}

- (NSSize)preferredSizeForCandidates:(NSArray<NSString *> *)candidateTexts pageIndicatorText:(NSString *)pageIndicatorText {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:17.0 weight:NSFontWeightRegular]
    };
    NSDictionary<NSAttributedStringKey, id> *pageAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold]
    };
    CGFloat maxTextWidth = 0.0;
    for (NSString *text in candidateTexts) {
        maxTextWidth = MAX(maxTextWidth, [text ?: @"" sizeWithAttributes:attributes].width);
    }
    if (pageIndicatorText.length > 0) {
        maxTextWidth = MAX(maxTextWidth, [pageIndicatorText sizeWithAttributes:pageAttributes].width + 18.0);
    }

    CGFloat width = ceil(maxTextWidth + 26.0);
    width = MIN(MAX(width, MKCandidatePanelMinWidth), MKCandidatePanelMaxWidth);
    CGFloat headerHeight = pageIndicatorText.length > 0 ? MKCandidatePanelHeaderHeight : 0.0;
    CGFloat height = headerHeight + MKCandidatePanelVerticalInset * 2.0 + MKCandidatePanelRowHeight * (CGFloat)candidateTexts.count;
    return NSMakeSize(width, ceil(height));
}

- (NSString *)candidateTextAtPanelPoint:(NSPoint)point {
    if (point.x < 0.0 || point.x > NSWidth(self.panelView.bounds)) {
        return nil;
    }
    CGFloat contentTop = self.panelView.pageIndicatorText.length > 0 ? MKCandidatePanelHeaderHeight : 0.0;
    if (point.y < contentTop + MKCandidatePanelVerticalInset) {
        return nil;
    }

    CGFloat candidateAreaHeight = MKCandidatePanelRowHeight * (CGFloat)self.panelView.candidateTexts.count;
    CGFloat y = point.y - contentTop - MKCandidatePanelVerticalInset;
    if (y < 0.0 || y >= candidateAreaHeight) {
        return nil;
    }

    NSUInteger index = (NSUInteger)floor(y / MKCandidatePanelRowHeight);
    if (index >= self.panelView.candidateTexts.count) {
        return nil;
    }
    return self.panelView.candidateTexts[index];
}

- (void)selectCandidateAtPanelPoint:(NSPoint)point {
    NSString *candidateText = [self candidateTextAtPanelPoint:point];
    if (candidateText.length == 0) {
        return;
    }
    [self.delegate candidatePanel:self didSelectCandidateText:candidateText];
}

- (BOOL)resolveAnchorRect:(NSRect *)resolvedAnchorRect
                forClient:(id)client
     anchorCharacterIndex:(NSNumber *)anchorCharacterIndex
       usePreservedAnchor:(BOOL)usePreservedAnchor {
    if (!client) {
        if (usePreservedAnchor && self.hasLastAnchorRect) {
            if (resolvedAnchorRect) {
                *resolvedAnchorRect = self.lastAnchorRect;
            }
            return YES;
        }
        return NO;
    }

    if (self.hasLastAnchorRect && self.lastAnchorClient && self.lastAnchorClient != client) {
        self.hasLastAnchorRect = NO;
        self.lastAnchorRect = NSZeroRect;
    }

    if (anchorCharacterIndex) {
        NSRect lineHeightRect = [self anchorRectFromLineHeightAttributesForClient:client
                                                             anchorCharacterIndex:anchorCharacterIndex];
        if ([self isUsableAnchorRect:lineHeightRect]) {
            NSRect normalizedRect = [self normalizedAnchorRect:lineHeightRect];
            self.hasLastAnchorRect = YES;
            self.lastAnchorRect = normalizedRect;
            self.lastAnchorClient = client;
            if (resolvedAnchorRect) {
                *resolvedAnchorRect = normalizedRect;
            }
            return YES;
        }
    }

    NSArray<NSValue *> *ranges = [self anchorRangesForClient:client];

    if ([client respondsToSelector:@selector(firstRectForCharacterRange:actualRange:)]) {
        for (NSValue *rangeValue in ranges) {
            NSRange range = rangeValue.rangeValue;
            if (range.location == NSNotFound) {
                continue;
            }

            NSRect rect = [(id<NSTextInputClient>)client firstRectForCharacterRange:range actualRange:NULL];
            if ([self isUsableAnchorRect:rect]) {
                NSRect normalizedRect = [self normalizedAnchorRect:rect];
                self.hasLastAnchorRect = YES;
                self.lastAnchorRect = normalizedRect;
                self.lastAnchorClient = client;
                if (resolvedAnchorRect) {
                    *resolvedAnchorRect = normalizedRect;
                }
                return YES;
            }
        }
    }

    if (self.hasLastAnchorRect) {
        if (resolvedAnchorRect) {
            *resolvedAnchorRect = self.lastAnchorRect;
        }
        return YES;
    }

    return NO;
}

- (NSRect)anchorRectFromLineHeightAttributesForClient:(id)client anchorCharacterIndex:(NSNumber *)anchorCharacterIndex {
    if (!anchorCharacterIndex || ![client respondsToSelector:@selector(attributesForCharacterIndex:lineHeightRectangle:)]) {
        return NSZeroRect;
    }

    NSRect lineHeightRect = NSZeroRect;
    [(id<PurrTypeLineHeightAnchorClient>)client attributesForCharacterIndex:anchorCharacterIndex.unsignedIntegerValue
                                                          lineHeightRectangle:&lineHeightRect];
    return lineHeightRect;
}

- (NSArray<NSValue *> *)anchorRangesForClient:(id)client {
    NSMutableArray<NSValue *> *ranges = [NSMutableArray arrayWithCapacity:3];

    if ([client respondsToSelector:@selector(markedRange)]) {
        NSRange markedRange = [(id<NSTextInputClient>)client markedRange];
        if (markedRange.location != NSNotFound) {
            NSRange markedEndRange = NSMakeRange(NSMaxRange(markedRange), 0);
            [ranges addObject:[NSValue valueWithRange:markedEndRange]];
            [ranges addObject:[NSValue valueWithRange:markedRange]];
            return ranges;
        }
    }

    if ([client respondsToSelector:@selector(selectedRange)]) {
        NSRange selectedRange = [(id<NSTextInputClient>)client selectedRange];
        if (selectedRange.location != NSNotFound) {
            [ranges addObject:[NSValue valueWithRange:selectedRange]];
        }
    }

    return ranges;
}

- (BOOL)isUsableAnchorRect:(NSRect)rect {
    if (NSEqualRects(rect, NSZeroRect)) {
        return NO;
    }
    if (!isfinite(NSMinX(rect)) || !isfinite(NSMinY(rect)) ||
        !isfinite(NSWidth(rect)) || !isfinite(NSHeight(rect))) {
        return NO;
    }
    if (NSWidth(rect) < 0.0 || NSHeight(rect) < 0.0) {
        return NO;
    }
    NSRect normalizedRect = [self normalizedAnchorRect:rect];
    return [self screenForRect:normalizedRect] != nil;
}

- (NSRect)normalizedAnchorRect:(NSRect)rect {
    CGFloat width = NSWidth(rect) <= 0.0 ? 1.0 : NSWidth(rect);
    CGFloat height = NSHeight(rect) <= 0.0 ? MKCandidatePanelDefaultAnchorHeight : NSHeight(rect);
    return NSMakeRect(NSMinX(rect), NSMinY(rect), width, height);
}

- (NSRect)frameForPanelSize:(NSSize)panelSize anchorRect:(NSRect)anchorRect {
    NSScreen *screen = [self screenForRect:anchorRect] ?: [NSScreen mainScreen];
    NSRect visibleFrame = screen.visibleFrame;

    CGFloat preferredX = NSMaxX(anchorRect) + MKCandidatePanelCaretHorizontalGap;
    CGFloat alignedX = NSMinX(anchorRect);
    CGFloat leftX = NSMinX(anchorRect) - panelSize.width - MKCandidatePanelCaretHorizontalGap;
    CGFloat maxX = NSMaxX(visibleFrame) - panelSize.width - MKCandidatePanelScreenMargin;
    CGFloat minX = NSMinX(visibleFrame) + MKCandidatePanelScreenMargin;
    CGFloat x = preferredX;
    if (x > maxX && alignedX <= maxX) {
        x = alignedX;
    }
    if (x > maxX && leftX >= minX) {
        x = leftX;
    }
    x = MIN(MAX(x, minX), maxX);

    CGFloat belowY = NSMinY(anchorRect) - panelSize.height - MKCandidatePanelCaretVerticalGap;
    CGFloat aboveY = NSMaxY(anchorRect) + MKCandidatePanelCaretVerticalGap;
    CGFloat maxY = NSMaxY(visibleFrame) - panelSize.height - MKCandidatePanelScreenMargin;
    CGFloat minY = NSMinY(visibleFrame) + MKCandidatePanelScreenMargin;
    CGFloat y = belowY;
    if (y < minY && aboveY <= maxY) {
        y = aboveY;
    }
    y = MIN(MAX(y, minY), maxY);

    return NSMakeRect(x, y, panelSize.width, panelSize.height);
}

- (NSScreen *)screenForRect:(NSRect)rect {
    NSPoint point = NSMakePoint(NSMidX(rect), NSMidY(rect));
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(point, screen.frame)) {
            return screen;
        }
    }
    return nil;
}

@end
