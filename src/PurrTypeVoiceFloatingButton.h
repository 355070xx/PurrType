#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class PurrTypeVoiceFloatingButton;

@protocol PurrTypeVoiceFloatingButtonDelegate <NSObject>
- (void)voiceFloatingButtonDidRequestToggle:(PurrTypeVoiceFloatingButton *)button;
@end

@interface PurrTypeVoiceFloatingButton : NSObject

@property(nonatomic, weak) id<PurrTypeVoiceFloatingButtonDelegate> delegate;

+ (instancetype)sharedButton;
- (void)show;
- (void)hide;
- (BOOL)isVisible;
- (NSRect)screenFrame;
- (void)setVoiceInputActive:(BOOL)active blocked:(BOOL)blocked statusTitle:(nullable NSString *)statusTitle;

@end

NS_ASSUME_NONNULL_END
