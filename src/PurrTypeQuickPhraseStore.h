#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MKQuickPhraseStoreErrorDomain;

@interface PurrTypeQuickPhraseEntry : NSObject

- (instancetype)initWithTrigger:(NSString *)trigger
                    replacement:(NSString *)replacement
                          label:(NSString *)label
                        enabled:(BOOL)enabled
                      createdAt:(NSDate *)createdAt
                      updatedAt:(NSDate *)updatedAt NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, copy, readonly) NSString *trigger;
@property(nonatomic, copy, readonly) NSString *normalizedTrigger;
@property(nonatomic, copy, readonly) NSString *replacement;
@property(nonatomic, copy, readonly) NSString *label;
@property(nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;
@property(nonatomic, strong, readonly) NSDate *createdAt;
@property(nonatomic, strong, readonly) NSDate *updatedAt;

- (NSDictionary<NSString *, id> *)dictionaryRepresentation;

@end

@interface PurrTypeQuickPhraseImportSummary : NSObject

- (instancetype)initWithImportedCount:(NSUInteger)importedCount
                         updatedCount:(NSUInteger)updatedCount
                         skippedCount:(NSUInteger)skippedCount
                         invalidCount:(NSUInteger)invalidCount NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, assign, readonly) NSUInteger importedCount;
@property(nonatomic, assign, readonly) NSUInteger updatedCount;
@property(nonatomic, assign, readonly) NSUInteger skippedCount;
@property(nonatomic, assign, readonly) NSUInteger invalidCount;

@end

@interface PurrTypeQuickPhraseStore : NSObject

+ (instancetype)defaultStore;
+ (NSString *)defaultDirectoryPath;
+ (NSString *)normalizedTriggerForTrigger:(nullable NSString *)trigger;
+ (BOOL)isTriggerContinuationString:(nullable NSString *)string;
+ (BOOL)isValidTrigger:(nullable NSString *)trigger;
+ (BOOL)isValidReplacement:(nullable NSString *)replacement;

- (instancetype)initWithDirectoryPath:(NSString *)directoryPath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, copy, readonly) NSString *directoryPath;

- (BOOL)loadWithError:(NSError **)error;
- (BOOL)saveWithError:(NSError **)error;

- (NSArray<PurrTypeQuickPhraseEntry *> *)entries;
- (nullable PurrTypeQuickPhraseEntry *)entryForTrigger:(NSString *)trigger;
- (NSArray<PurrTypeQuickPhraseEntry *> *)entriesForTrigger:(NSString *)trigger;
- (nullable PurrTypeQuickPhraseEntry *)enabledEntryForTrigger:(NSString *)trigger;
- (NSArray<PurrTypeQuickPhraseEntry *> *)enabledEntriesForTrigger:(NSString *)trigger;
- (nullable PurrTypeQuickPhraseEntry *)upsertTrigger:(NSString *)trigger
                                        replacement:(NSString *)replacement
                                              label:(NSString *)label
                                            enabled:(BOOL)enabled
                                              error:(NSError **)error;
- (BOOL)removeTrigger:(NSString *)trigger error:(NSError **)error;
- (NSUInteger)removeEntriesForTrigger:(NSString *)trigger
                           replacement:(nullable NSString *)replacement
                                 error:(NSError **)error;
- (nullable NSData *)exportJSONDataWithError:(NSError **)error;
- (nullable PurrTypeQuickPhraseImportSummary *)importEntriesFromJSONData:(NSData *)data error:(NSError **)error;
- (NSString *)exportText;
- (nullable PurrTypeQuickPhraseImportSummary *)importEntriesFromText:(NSString *)text error:(NSError **)error;
- (BOOL)reloadIfChangedWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
