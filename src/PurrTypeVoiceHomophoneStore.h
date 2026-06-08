#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PurrTypeVoiceHomophoneResourceName;
extern NSString *const PurrTypeVoiceHomophoneResourceExtension;

@interface PurrTypeVoiceHomophoneStore : NSObject

+ (instancetype)storeWithBundle:(NSBundle *)bundle;
- (instancetype)initWithResourceURL:(nullable NSURL *)resourceURL NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSArray<NSString *> *)homophonesForCharacter:(NSString *)character limit:(NSUInteger)limit;
- (void)recordSelectionForCharacter:(NSString *)character candidate:(NSString *)candidate;

@property(nonatomic, assign) BOOL learningEnabled;

@end

NS_ASSUME_NONNULL_END
