#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MKPurrTypeBackupStoreErrorDomain;

@interface PurrTypeBackupSummary : NSObject

- (instancetype)initWithImportedCount:(NSUInteger)importedCount
                         replacedCount:(NSUInteger)replacedCount
                          skippedCount:(NSUInteger)skippedCount
                          invalidCount:(NSUInteger)invalidCount
                   preRestoreBackupURL:(nullable NSURL *)preRestoreBackupURL NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, assign, readonly) NSUInteger importedCount;
@property(nonatomic, assign, readonly) NSUInteger replacedCount;
@property(nonatomic, assign, readonly) NSUInteger skippedCount;
@property(nonatomic, assign, readonly) NSUInteger invalidCount;
@property(nonatomic, strong, nullable, readonly) NSURL *preRestoreBackupURL;

@end

@interface PurrTypeBackupStore : NSObject

+ (instancetype)defaultStore;
+ (NSString *)defaultDirectoryPath;

- (instancetype)initWithDirectoryPath:(NSString *)directoryPath NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, copy, readonly) NSString *directoryPath;

- (nullable NSData *)exportBackupDataWithError:(NSError **)error;
- (nullable NSURL *)writeBackupToDirectoryURL:(NSURL *)directoryURL error:(NSError **)error;
- (nullable PurrTypeBackupSummary *)restoreBackupData:(NSData *)data error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
