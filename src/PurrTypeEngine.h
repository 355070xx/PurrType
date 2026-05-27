#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *const MKInputMode NS_TYPED_ENUM;

extern MKInputMode MKInputModeMixed;
extern MKInputMode MKInputModeCangjie;
extern MKInputMode MKInputModeSucheng;
extern MKInputMode MKInputModeSmartSucheng;
extern MKInputMode MKInputModePinyin;
extern MKInputMode MKInputModeEnglish;

@interface MKCandidate : NSObject

@property(nonatomic, copy, readonly) NSString *text;
@property(nonatomic, copy, readonly) NSString *code;
@property(nonatomic, copy, readonly) NSString *source;
@property(nonatomic, assign, readonly) NSInteger weight;
@property(nonatomic, assign, readonly) NSUInteger sequence;

- (instancetype)initWithText:(NSString *)text
                        code:(NSString *)code
                      source:(NSString *)source
                      weight:(NSInteger)weight;
- (instancetype)initWithText:(NSString *)text
                        code:(NSString *)code
                      source:(NSString *)source
                      weight:(NSInteger)weight
                    sequence:(NSUInteger)sequence NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface PurrTypeEngine : NSObject

+ (instancetype)sharedEngine;
+ (NSString *)defaultLearningPath;
+ (void)resetPersistedLearningStateAtDefaultPath;

- (instancetype)initWithCangjieDirectory:(NSString *)cangjieDirectory
                              pinyinPath:(NSString *)pinyinPath;
- (instancetype)initWithCangjieDirectory:(NSString *)cangjieDirectory
                              pinyinPath:(NSString *)pinyinPath
                            learningPath:(nullable NSString *)learningPath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSArray<MKCandidate *> *)candidatesForInput:(NSString *)input limit:(NSUInteger)limit;
- (NSArray<MKCandidate *> *)candidatesForInput:(NSString *)input
                                         limit:(NSUInteger)limit
                                          mode:(MKInputMode)mode;
- (BOOL)hasCandidatesOrPrefixesForInput:(NSString *)input;
- (BOOL)hasCandidatesOrPrefixesForInput:(NSString *)input mode:(MKInputMode)mode;
- (NSArray<MKCandidate *> *)associatedCandidatesForText:(NSString *)text limit:(NSUInteger)limit;
- (NSArray<MKCandidate *> *)associatedCandidatesForText:(NSString *)text
                                                  limit:(NSUInteger)limit
                                                   mode:(MKInputMode)mode;
- (void)recordSelectionForCandidate:(MKCandidate *)candidate
                        previousText:(nullable NSString *)previousText
                                mode:(MKInputMode)mode;
- (void)recordCommittedCandidateText:(NSString *)text
                                 code:(NSString *)code
                                 mode:(MKInputMode)mode;
- (void)recordCommittedText:(NSString *)text mode:(MKInputMode)mode;
- (void)recordCommittedText:(NSString *)text code:(NSString *)code mode:(MKInputMode)mode;
- (void)recordCommittedTexts:(NSArray<NSString *> *)texts
                       codes:(NSArray<NSString *> *)codes
                        mode:(MKInputMode)mode;
- (void)resetLearningState;
- (void)resetLearningContext;
- (BOOL)prefersRawEnglishForInput:(NSString *)input mode:(MKInputMode)mode;
- (BOOL)looksLikeRawEnglishInput:(NSString *)input mode:(MKInputMode)mode;
- (BOOL)isLikelyRawToken:(NSString *)input;
- (BOOL)isLikelyRawToken:(NSString *)input mode:(MKInputMode)mode;
- (NSString *)preferredSuchengCodeForText:(NSString *)text;
- (NSString *)preferredCangjieCodeForText:(NSString *)text;

@property(nonatomic, assign, readonly) NSUInteger cangjieEntryCount;
@property(nonatomic, assign, readonly) NSUInteger quickEntryCount;
@property(nonatomic, assign, readonly) NSUInteger pinyinEntryCount;
@property(nonatomic, assign) BOOL learningEnabled;

@end

NS_ASSUME_NONNULL_END
