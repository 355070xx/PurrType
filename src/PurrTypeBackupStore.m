#import "PurrTypeBackupStore.h"
#import "PurrTypeQuickPhraseStore.h"

NSString *const MKPurrTypeBackupStoreErrorDomain = @"org.purrtype.BackupStore";

static NSString *const MKPurrTypeBackupFormat = @"purrtype-basic-backup";
static NSString *const MKPurrTypeBackupDirectoryName = @"Backups";
static NSInteger const MKPurrTypeBackupVersion = 1;
static NSUInteger const MKPurrTypeBackupMaxPayloadBytes = 512 * 1024;

typedef NS_ENUM(NSInteger, MKPurrTypeBackupStoreErrorCode) {
    MKPurrTypeBackupStoreErrorInvalidDirectory = 1,
    MKPurrTypeBackupStoreErrorInvalidJSON = 2,
    MKPurrTypeBackupStoreErrorUnsupportedFormat = 3,
    MKPurrTypeBackupStoreErrorUnsupportedVersion = 4,
    MKPurrTypeBackupStoreErrorPayloadTooLarge = 5
};

static NSError *MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorCode code, NSString *message) {
    return [NSError errorWithDomain:MKPurrTypeBackupStoreErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message ?: @"PurrType backup error" }];
}

static NSDateFormatter *MKPurrTypeBackupDateFormatter(void) {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    });
    return formatter;
}

static NSString *MKPurrTypeBackupStringFromDate(NSDate *date) {
    return [MKPurrTypeBackupDateFormatter() stringFromDate:date ?: [NSDate date]];
}

@implementation PurrTypeBackupSummary

- (instancetype)initWithImportedCount:(NSUInteger)importedCount
                         replacedCount:(NSUInteger)replacedCount
                          skippedCount:(NSUInteger)skippedCount
                          invalidCount:(NSUInteger)invalidCount
                   preRestoreBackupURL:(NSURL *)preRestoreBackupURL {
    self = [super init];
    if (self) {
        _importedCount = importedCount;
        _replacedCount = replacedCount;
        _skippedCount = skippedCount;
        _invalidCount = invalidCount;
        _preRestoreBackupURL = preRestoreBackupURL;
    }
    return self;
}

@end

@interface PurrTypeBackupStore ()

@property(nonatomic, copy, readwrite) NSString *directoryPath;

@end

@implementation PurrTypeBackupStore

+ (instancetype)defaultStore {
    static PurrTypeBackupStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[PurrTypeBackupStore alloc] initWithDirectoryPath:[self defaultDirectoryPath]];
    });
    return store;
}

+ (NSString *)defaultDirectoryPath {
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    if (basePath.length == 0) {
        basePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    }
    return [[basePath stringByAppendingPathComponent:@"PurrType"] copy];
}

- (instancetype)initWithDirectoryPath:(NSString *)directoryPath {
    self = [super init];
    if (self) {
        _directoryPath = [directoryPath copy] ?: @"";
    }
    return self;
}

- (NSData *)exportBackupDataWithError:(NSError **)error {
    if (self.directoryPath.length == 0) {
        if (error) {
            *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorInvalidDirectory, @"PurrType data directory is unavailable.");
        }
        return nil;
    }

    NSMutableDictionary<NSString *, id> *payload = [NSMutableDictionary dictionary];
    id quickPhrases = [self JSONObjectForFileName:@"quick-phrases.json" error:error];
    if (quickPhrases) {
        payload[@"quickPhrases"] = quickPhrases;
    } else if (error && *error) {
        return nil;
    }

    NSDictionary<NSString *, id> *root = @{
        @"format": MKPurrTypeBackupFormat,
        @"version": @(MKPurrTypeBackupVersion),
        @"createdAt": MKPurrTypeBackupStringFromDate([NSDate date]),
        @"payload": payload
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:root
                                                   options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys)
                                                     error:error];
    if (!data && error && !*error) {
        *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorInvalidJSON, @"Unable to export PurrType backup.");
    }
    return data;
}

- (NSURL *)writeBackupToDirectoryURL:(NSURL *)directoryURL error:(NSError **)error {
    if (!directoryURL.isFileURL) {
        if (error) {
            *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorInvalidDirectory, @"Backup destination must be a local folder.");
        }
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtURL:directoryURL
               withIntermediateDirectories:YES
                                attributes:@{ NSFilePosixPermissions: @0700 }
                                     error:error]) {
        return nil;
    }
    [fileManager setAttributes:@{ NSFilePosixPermissions: @0700 } ofItemAtPath:directoryURL.path error:nil];

    NSData *data = [self exportBackupDataWithError:error];
    if (!data) {
        return nil;
    }
    NSString *timestamp = [MKPurrTypeBackupStringFromDate([NSDate date]) stringByReplacingOccurrencesOfString:@":" withString:@""];
    NSString *fileName = [NSString stringWithFormat:@"purrtype-backup-%@-%@.json", timestamp, [NSUUID UUID].UUIDString];
    NSURL *fileURL = [directoryURL URLByAppendingPathComponent:fileName];
    if (![data writeToURL:fileURL options:NSDataWritingAtomic error:error]) {
        return nil;
    }
    [fileManager setAttributes:@{ NSFilePosixPermissions: @0600 } ofItemAtPath:fileURL.path error:nil];
    return fileURL;
}

- (PurrTypeBackupSummary *)restoreBackupData:(NSData *)data error:(NSError **)error {
    if (![data isKindOfClass:[NSData class]] || data.length == 0) {
        if (error) {
            *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorInvalidJSON, @"PurrType backup is empty.");
        }
        return nil;
    }
    if (data.length > MKPurrTypeBackupMaxPayloadBytes) {
        if (error) {
            *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorPayloadTooLarge, @"PurrType backup is too large.");
        }
        return nil;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error && !*error) {
            *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorInvalidJSON, @"PurrType backup must be a JSON object.");
        }
        return nil;
    }

    NSDictionary *root = (NSDictionary *)object;
    if (![root[@"format"] isEqualToString:MKPurrTypeBackupFormat]) {
        if (error) {
            *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorUnsupportedFormat, @"PurrType backup format is unsupported.");
        }
        return nil;
    }
    NSNumber *version = [root[@"version"] isKindOfClass:[NSNumber class]] ? (NSNumber *)root[@"version"] : nil;
    if (version.integerValue != MKPurrTypeBackupVersion) {
        if (error) {
            *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorUnsupportedVersion, @"PurrType backup version is unsupported.");
        }
        return nil;
    }
    NSDictionary *payload = [root[@"payload"] isKindOfClass:[NSDictionary class]] ? (NSDictionary *)root[@"payload"] : nil;
    if (!payload) {
        if (error) {
            *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorInvalidJSON, @"PurrType backup payload is missing.");
        }
        return nil;
    }

    NSURL *preRestoreBackupURL = [self createPreRestoreBackupWithError:error];
    if (!preRestoreBackupURL) {
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtPath:self.directoryPath
                withIntermediateDirectories:YES
                                 attributes:@{ NSFilePosixPermissions: @0700 }
                                      error:error]) {
        return nil;
    }
    [fileManager setAttributes:@{ NSFilePosixPermissions: @0700 } ofItemAtPath:self.directoryPath error:nil];

    NSUInteger importedCount = 0;
    NSUInteger replacedCount = 0;
    NSUInteger skippedCount = 0;
    NSUInteger invalidCount = 0;
    id quickPhrases = payload[@"quickPhrases"];
    if (!quickPhrases) {
        skippedCount += 1;
    } else if (![NSJSONSerialization isValidJSONObject:quickPhrases] ||
               (![quickPhrases isKindOfClass:[NSDictionary class]] && ![quickPhrases isKindOfClass:[NSArray class]])) {
        invalidCount += 1;
    } else {
        BOOL quickPhrasesHaveValidShape = YES;
        if ([quickPhrases isKindOfClass:[NSDictionary class]]) {
            id entries = ((NSDictionary *)quickPhrases)[@"entries"];
            quickPhrasesHaveValidShape = [entries isKindOfClass:[NSArray class]];
        }
        if (!quickPhrasesHaveValidShape) {
            invalidCount += 1;
        } else {
            NSData *rawQuickPhraseData = [NSJSONSerialization dataWithJSONObject:quickPhrases
                                                                         options:NSJSONWritingSortedKeys
                                                                           error:nil];
            if (!rawQuickPhraseData) {
                invalidCount += 1;
            } else {
                NSString *temporaryDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"PurrTypeBackupRestore-%@", [NSUUID UUID].UUIDString]];
                PurrTypeQuickPhraseStore *quickPhraseStore = [[PurrTypeQuickPhraseStore alloc] initWithDirectoryPath:temporaryDirectory];
                NSError *importError = nil;
                PurrTypeQuickPhraseImportSummary *quickPhraseSummary =
                    [quickPhraseStore importEntriesFromJSONData:rawQuickPhraseData error:&importError];
                invalidCount += quickPhraseSummary.invalidCount;
                if (!quickPhraseSummary) {
                    invalidCount += 1;
                } else {
                    NSData *validatedData = [quickPhraseStore exportJSONDataWithError:error];
                    if (!validatedData) {
                        return nil;
                    }
                    NSString *path = [self.directoryPath stringByAppendingPathComponent:@"quick-phrases.json"];
                    BOOL existed = [fileManager fileExistsAtPath:path];
                    if (![validatedData writeToFile:path options:NSDataWritingAtomic error:error]) {
                        return nil;
                    }
                    [fileManager setAttributes:@{ NSFilePosixPermissions: @0600 } ofItemAtPath:path error:nil];
                    importedCount += 1;
                    if (existed) {
                        replacedCount += 1;
                    }
                }
                [[NSFileManager defaultManager] removeItemAtPath:temporaryDirectory error:nil];
            }
        }
    }

    return [[PurrTypeBackupSummary alloc] initWithImportedCount:importedCount
                                                  replacedCount:replacedCount
                                                   skippedCount:skippedCount
                                                   invalidCount:invalidCount
                                            preRestoreBackupURL:preRestoreBackupURL];
}

- (NSURL *)createPreRestoreBackupWithError:(NSError **)error {
    NSString *backupDirectoryPath = [self.directoryPath stringByAppendingPathComponent:MKPurrTypeBackupDirectoryName];
    NSURL *backupDirectoryURL = [NSURL fileURLWithPath:backupDirectoryPath isDirectory:YES];
    return [self writeBackupToDirectoryURL:backupDirectoryURL error:error];
}

- (id)JSONObjectForFileName:(NSString *)fileName error:(NSError **)error {
    NSString *path = [self.directoryPath stringByAppendingPathComponent:fileName ?: @""];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) {
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (!object) {
        return nil;
    }
    if (![object isKindOfClass:[NSDictionary class]] && ![object isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = MKPurrTypeBackupStoreError(MKPurrTypeBackupStoreErrorInvalidJSON, @"PurrType data file must be a JSON object or array.");
        }
        return nil;
    }
    return object;
}

@end
